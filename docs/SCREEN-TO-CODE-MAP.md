# خريطة الشاشات إلى الكود وقاعدة البيانات

## 1. نقطة الدخول والبنية الحالية

- نقطة تشغيل Flutter: `lib/main.dart` — `main()`.
- التطبيق: `NaeemWmsApp`.
- واجهة النظام الرئيسية: `WarehouseHome` / `_WarehouseHomeState`.
- الوصول إلى البيانات: `WmsDatabase.instance` من `lib/data/wms_database.dart`.
- تحويل الوحدات: `lib/domain/unit_conversion.dart`.

**ملاحظة بنيوية:** غالبية الشاشات والحوارات موجودة حالياً داخل ملف `lib/main.dart`، وليست موزعة بعد على ملفات مستقلة لكل شاشة.

## 2. خريطة التنقل والشاشات

| الشاشة / الواجهة | نقطة الدخول في الكود | دوال الواجهة | دوال البيانات الأساسية | الجداول الأساسية |
|---|---|---|---|---|
| الصفحة الرئيسية ومعرض الأصناف | `WarehouseHome.build()` | `refresh()`, `productStatusColor()` | `listProducts()` | products, product_units, stock_movements, stock_batches |
| إضافة صنف | زر الإضافة في المعرض | `addProduct()` | `saveProduct()` | products, product_units |
| تعديل / أرشفة صنف | الضغط المطول أو قائمة الصنف | `editProduct()` | `updateProduct()`, `archiveProduct()` | products, product_units |
| كاشير الصرف | زر الصرف أو اختيار صنف من المعرض | `openTransaction(false)`, `_openIssueCashier()` | `listParties()`, `listProducts()`, `listUnits()`, `createDocument()`, `submitDocument()` | customers, products, product_units, documents, document_lines |
| كاشير التوريد | زر التوريد | `openTransaction(true)`, `_openReceiptTransaction()` | `listParties()`, `listProducts()`, `listPurchaseUnits()`, `createDocument()`, `submitDocument()` | suppliers, products, product_units, documents, document_lines |
| قائمة الاعتمادات | عنصر القائمة approvals | `showApprovals()` | `pendingDocuments()`, `approveDocument()`, `rejectDocument()` | documents, document_lines, approval_history, stock_movements |
| تأكيد التسليم | عنصر القائمة deliveries | `showDeliveries()` | `awaitingDeliveryDocuments()`, `confirmDelivery()` | documents |
| سجل الفواتير | عنصر القائمة docs | `showDocuments()`, `showDocumentDetails()` | `listDocuments()`, `documentDetails()` | documents, document_lines, stock_movements |
| سجل الصرف | عنصر القائمة issues | `showDocuments(kind: 'issue')` | `listDocuments()`, `documentDetails()` | documents, document_lines |
| المرتجعات | عنصر القائمة returns | `showReturns()` | `returnableDocumentLines()`, `createReturnDocument()`, `submitDocument()`, `approveDocument()` | documents, document_lines, stock_movements, stock_batches, stock_movement_allocations |
| الموردون والعملاء | عنصر القائمة parties | `manageParties()`, `editParty()` | `listParties()`, `saveParty()`, `updateParty()`, `archiveParty()` | suppliers, customers |
| كشف حساب العميل | عنصر القائمة statement | `showCustomerAccounts()` | `customerStatement()`, `addCustomerPayment()` | customers, documents, document_lines, customer_payments |
| كشف حساب المورد | عنصر القائمة supplierStatement | `showSupplierAccounts()` | `supplierStatement()`, `addSupplierPayment()` | suppliers, documents, document_lines, supplier_payments |
| PDF وطباعة ومشاركة | من تفاصيل الفاتورة أو كشف الحساب | `buildDocumentPdf()`, `buildStatementPdf()`, `shareDocumentPdf()`, `printDocumentPdf()`, `shareStatementPdf()`, `printStatementPdf()` | `documentDetails()`, `customerStatement()`, `supplierStatement()` | documents, document_lines, customer_payments, supplier_payments |

## 3. تسلسل البيانات من الشاشة إلى قاعدة البيانات

### 3.1 التوريد

1. المستخدم يفتح التوريد.
2. `_openReceiptTransaction()` يحمّل الموردين والأصناف ووحدة الشراء.
3. المستخدم يدخل الكمية والسعر ويضيف السطور إلى السلة.
4. `createDocument(kind: 'receipt')` ينشئ رأس المستند وسطور التفاصيل.
5. `submitDocument()` ينقل الحالة إلى انتظار الاعتماد ويسجل الحدث.
6. `approveDocument()` يتحقق من المستند ويرحل حركة IN داخل Transaction.
7. رصيد الصنف يعاد حسابه من دفتر `stock_movements`.

### 3.2 الصرف

1. `_openIssueCashier()` يحمّل العملاء والأصناف ذات الرصيد المتاح.
2. يختار المستخدم الصنف والوحدة والكمية.
3. `createDocument(kind: 'issue')` ينشئ المستند وسطور الصرف.
4. `submitDocument()` يرسل المستند للاعتماد.
5. `approveDocument()` يجمع كميات الصنف ويتحقق من الرصيد ثم يرحل حركة OUT.
6. التسليم الفعلي خطوة منفصلة عبر `confirmDelivery()`.

### 3.3 مرتجع العميل

1. `showReturns()` يعرض فواتير الصرف المعتمدة والسطور القابلة للإرجاع.
2. `returnableDocumentLines()` يحسب المتبقي لكل سطر أصلي.
3. `createReturnDocument(kind: 'return_in')` ينشئ مستنداً مرتبطاً بالفاتورة وسطر الصرف الأصلي.
4. الإرسال والاعتماد يتمان عبر `submitDocument()` و`approveDocument()`.
5. عند الاعتماد تُسجل حركة IN.

### 3.4 مرتجع المورد

1. `showReturns()` يعرض فواتير التوريد المعتمدة.
2. `createReturnDocument(kind: 'return_out')` يربط المرتجع بسطر التوريد الأصلي.
3. التحقق يراجع الكمية غير المرتجعة والرصيد المتاح من دفعة الاستلام الأصلية.
4. عند الاعتماد تُسجل حركة OUT وتخصيصها لدفعة المخزون.

## 4. حقول الشاشة ومصادرها

| ما يظهر للمستخدم | مصدر البيانات |
|---|---|
| اسم الصنف | products.name أو document_lines.product_name_snapshot |
| رصيد الصنف | قيمة محسوبة من stock_movements، وتظهر باسم stock_base في نتيجة listProducts |
| وحدة الصنف | product_units.unit_name أو unit_name_snapshot في تفاصيل المستند |
| كمية الإدخال | document_lines.entered_quantity |
| كمية وحدة الأساس | document_lines.base_quantity |
| سعر السطر | document_lines.unit_price_minor |
| اسم المورد/العميل في الفاتورة | documents.party_name_snapshot |
| حالة المستند | documents.status |
| حالة التسليم | documents.delivery_status |
| تاريخ الصلاحية | stock_batches.expiry_date / document_line_expiry_splits.expiry_date |
| رصيد العميل/المورد | ناتج استعلام كشف الحساب، وليس عمود رصيد ثابتاً في جدول الطرف |

## 5. الواجهات غير الموجودة أو غير المكتملة في لقطة المصدر

وفق README الحالي، لا ينبغي اعتبار هذه الوظائف مكتملة لمجرد وجود بعض جداولها أو قيمها في قاعدة البيانات:
- تسجيل الدخول وإنشاء أول مدير وإدارة الأدوار والصلاحيات.
- الجرد الفعلي واعتماد فروق الجرد.
- التحويل بين المخازن.
- النسخ الاحتياطي والاستعادة.
- توزيع الدفعات على فواتير منفردة.
- تقارير مالية مؤرخة متكاملة.
- اختبار التطبيق على جهاز Android فعلي.
- الطباعة الحرارية المباشرة.

يجب تحديث هذه القائمة فقط بعد فحص الكود والاختبارات وواجهة المستخدم.
