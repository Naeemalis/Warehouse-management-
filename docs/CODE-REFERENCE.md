# مرجع الدوال البرمجية ومسؤولياتها

## 1. طبقة البيانات: `lib/data/wms_database.dart`

الصنف المركزي هو `WmsDatabase`، ويستخدم نمط Singleton عبر `WmsDatabase.instance`.

| الدالة | الغرض | الجداول التي تتعامل معها / الأثر |
|---|---|---|
| `database` | فتح قاعدة البيانات وترقية المخطط وتفعيل FK | جميع الجداول |
| `_createSchema()` | إنشاء مخطط قاعدة بيانات جديدة | جميع الجداول الأساسية |
| `_createExpiryTraceabilitySchema()` | إنشاء جداول الصلاحية والدفعات وتخصيص الحركات | document_line_expiry_splits, stock_batches, stock_movement_allocations |
| `getAvailableStock(productId)` | حساب الرصيد من حركات IN وOUT | stock_movements |
| `_batchAvailableBase(txn, batchId)` | حساب الرصيد المتاح في دفعة محددة | stock_batches, stock_movement_allocations, stock_movements |
| `_activeReturnedBase(txn, sourceLineId)` | جمع كميات المرتجعات النشطة لسطر أصلي | documents, document_lines |
| `_validateReturnDocument(txn, doc)` | التحقق من نوع الفاتورة الأصلية والسطر والكمية ودفعة المورد | documents, document_lines, stock_movements, stock_movement_allocations, stock_batches |
| `createReturnDocument()` | إنشاء مسودة مرتجع وربطها بالفاتورة والسطر الأصليين | documents, document_lines |
| `approveDocument()` | اعتماد المستند وترحيل حركة المخزون داخل معاملة | documents, document_lines, stock_movements, stock_batches, stock_movement_allocations, approval_history |
| `confirmDelivery()` | تسجيل تسليم مستند صرف معتمد | documents |
| `listProducts()` | عرض الأصناف مع الرصيد وبيانات مساعدة | products, product_units, stock_movements, stock_batches |
| `listUnits(productId)` | جلب وحدات الصنف | product_units |
| `listPurchaseUnits(productId)` | جلب وحدة/وحدات التوريد المفعلة | product_units |
| `saveProduct()` | إنشاء الصنف ووحداته | products, product_units |
| `listParties(table)` | جلب الموردين أو العملاء | suppliers أو customers |
| `saveParty()` | إنشاء مورد أو عميل | suppliers أو customers |
| `createDocument()` | إنشاء رأس مستند وسطور أصنافه | documents, document_lines |
| `submitDocument()` | إرسال مستند للاعتماد وتسجيل حدثه | documents, approval_history |
| `pendingDocuments()` | جلب المستندات المنتظرة للاعتماد | documents, document_lines |
| `rejectDocument()` | رفض مستند وتسجيل السبب والحدث | documents, approval_history |
| `productBatchBalances()` | عرض أرصدة دفعات صنف | stock_batches, stock_movement_allocations, stock_movements |
| `productMovementHistory()` | عرض سجل حركة الصنف | stock_movements, documents, document_lines |
| `awaitingDeliveryDocuments()` | جلب مستندات الصرف المعتمدة التي تنتظر التسليم | documents |
| `updateProduct()` | تعديل بيانات الصنف ووحداته/أسعاره وفق الدالة | products, product_units |
| `listDocuments()` | قائمة المستندات مع مرشحات النوع والطرف | documents |
| `returnableDocumentLines()` | جلب سطور الفاتورة الأصلية والمتبقي القابل للإرجاع | documents, document_lines |
| `documentDetails()` | جلب رأس المستند وتفاصيل سطوره | documents, document_lines |
| `addCustomerPayment()` | تسجيل دفعة عميل | customer_payments |
| `addSupplierPayment()` | تسجيل دفعة مورد | supplier_payments |
| `customerStatement()` | إعداد كشف حساب العميل من الفواتير والمرتجعات والدفعات | customers, documents, document_lines, customer_payments |
| `supplierStatement()` | إعداد كشف حساب المورد من التوريد والمرتجعات والدفعات | suppliers, documents, document_lines, supplier_payments |
| `updateParty()` | تعديل بيانات مورد أو عميل | suppliers أو customers |
| `archiveParty()` | أرشفة مورد أو عميل مع حفظ السجل التاريخي | suppliers أو customers |
| `archiveProduct()` | أرشفة صنف دون حذف الحركات التاريخية | products |

## 2. طبقة التحويل: `lib/domain/unit_conversion.dart`

هذه الوحدة مسؤولة عن قواعد التحويل الحسابية وتعريف وحدات التعبئة المتدرجة. من الوظائف المستخدمة في الواجهة:
- `buildHierarchicalUnitDefinitions()`: بناء تعريفات الوحدات المتداخلة وأسعار البيع.
- `convertToBaseQuantity()`: تحويل الكمية المدخلة إلى وحدة المخزون الأساسية.

يجب أن تبقى معاملات التحويل التاريخية محفوظة في سطر المستند؛ لا يعاد تفسير فاتورة قديمة وفق تعريف الوحدة الحالي.

## 3. طبقة الواجهة: `lib/main.dart`

| الدالة / المكوّن | الشاشة أو المسؤولية |
|---|---|
| `main()` | تشغيل التطبيق |
| `NaeemWmsApp` | إعداد MaterialApp واللغة |
| `WarehouseHome` | شاشة التطبيق الرئيسية |
| `refresh()` | تحديث معرض الأصناف وقائمة الاعتمادات |
| `productStatusColor()` | تحديد لون حالة بطاقة الصنف حسب الرصيد والصلاحية وآخر حركة |
| `addProduct()` | حوار إضافة صنف ووحداته وأسعاره |
| `openTransaction()` | توجيه المستخدم إلى كاشير التوريد أو الصرف |
| `_openIssueCashier()` | واجهة كاشير الصرف |
| `_openReceiptTransaction()` | واجهة كاشير التوريد |
| `showProductHistory()` | سجل حركة وصلاحية الصنف |
| `editProduct()` | حوار تعديل الصنف |
| `manageParties()` | إدارة الموردين والعملاء |
| `showDeliveries()` | شاشة التسليمات |
| `showApprovals()` | شاشة الاعتمادات |
| `editParty()` | تعديل بيانات طرف |
| `buildDocumentPdf()` | تكوين PDF للمستند |
| `buildStatementPdf()` | تكوين PDF لكشف الحساب |
| `shareDocumentPdf()` / `printDocumentPdf()` | مشاركة أو طباعة الفاتورة |
| `shareStatementPdf()` / `printStatementPdf()` | مشاركة أو طباعة كشف الحساب |
| `showReturns()` | شاشة المرتجعات |
| `showDocuments()` | سجل الفواتير |
| `showDocumentDetails()` | تفاصيل الفاتورة |
| `showCustomerAccounts()` | كشف حساب العميل |
| `showSupplierAccounts()` | كشف حساب المورد |
| `recordCustomerPayment()` | حوار تسجيل دفعة عميل |
| `recordSupplierPayment()` | حوار تسجيل دفعة مورد |

## 4. مثال تتبع وظيفة كاملة: اعتماد الصرف

**الشاشة:** كاشير الصرف ثم قائمة الاعتمادات.

**مسار الاستدعاء:**
1. `_openIssueCashier()` يجمع بيانات العميل والصنف والوحدة والكمية والسعر.
2. `createDocument(kind: 'issue')` ينشئ `documents` و`document_lines`.
3. `submitDocument()` يغير حالة المستند إلى `pending_approval` ويسجل حدث الإرسال في `approval_history`.
4. `showApprovals()` تعرض المستندات من `pendingDocuments()`.
5. `approveDocument()` يتحقق من الحالة والرصيد ثم يكتب حركة `OUT` في `stock_movements` ضمن Transaction.
6. `listProducts()` يعيد احتساب رصيد الصنف بعد الترحيل.

**الحقول الأساسية في هذا المسار:**
- documents: `kind`, `status`, `party_type`, `party_id`, `created_by`, `approved_by`, `approved_at`.
- document_lines: `product_id`, `entered_quantity`, `factor_to_base_snapshot`, `base_quantity`, `unit_price_minor`.
- stock_movements: `document_id`, `document_line_id`, `product_id`, `direction`, `quantity_base`.

## 5. ملاحظة حول المسؤولية والصلاحيات

توجد حقول لتسجيل معرف المستخدم في عدة جداول، لكن README في لقطة المصدر يقر بأن المصادقة والصلاحيات الفعلية غير منفذة بالكامل وأن بعض الواجهات تستخدم معرف مستخدم تجريبياً. لذلك لا يجوز اعتبار `created_by` أو `approved_by` دليلاً على حماية الصلاحيات.
