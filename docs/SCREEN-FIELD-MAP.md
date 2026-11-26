# خريطة حقول الشاشات إلى أعمدة SQLite

هذه الوثيقة تربط عناصر الإدخال والاختيار الظاهرة في الواجهة بأسماء المتغيرات البرمجية وحقول التخزين. أرقام الأسطر تشير إلى لقطة المصدر الموثقة، وقد تتغير مع التعديلات.

## 1. إضافة صنف — `addProduct()`

الموضع: `lib/main.dart:278-328`  
حفظ البيانات: `WmsDatabase.saveProduct()` في `lib/data/wms_database.dart:658-697`.

| العنصر في الشاشة | متغير الواجهة | وسيط الحفظ / العمود | ملاحظات |
|---|---|---|---|
| اسم الصنف | `name` | `products.name` | إلزامي |
| وحدة الأساس | `base` | `products.base_unit_name` | وحدة المخزون المرجعية |
| نوع التتبع | `mode` | `products.tracking_mode` | count / weight / volume |
| سعر بيع وحدة الأساس | `baseSalePrice` | `product_units.sale_price_minor` للوحدة الأساسية | يحول إلى أصغر وحدة نقدية |
| سعر بيع وحدة التوريد | `supplySalePrice` | `product_units.sale_price_minor` للوحدة المحددة بوصفها purchase unit | سعر مستقل |
| وحدات التعبئة المتفرعة | `units` ثم `unitRows` | `product_units.unit_name`, `factor_to_base`, `sort_order`, `is_purchase_unit`, `sale_price_minor` | التحويل يبنى كسلسلة وحدات متدرجة |

**تنبيه مهم:** لا يوجد في هذه الشاشة حقل إدخال مباشر لـ `products.purchase_price_minor` أو `products.issue_price_minor` عند إنشاء الصنف. أسعار البيع تُحفظ على صفوف `product_units`. لذلك يجب عدم الخلط بين سعر الشراء الفعلي في فاتورة التوريد وسعر بطاقة الصنف.

## 2. كاشير الصرف — `_openIssueCashier()`

الموضع: `lib/main.dart:335-462`.  
الحفظ: `createDocument(kind: 'issue')` ثم `submitDocument()`.

| العنصر | متغير / مصدر UI | العمود الذي يستقر فيه | ملاحظات |
|---|---|---|---|
| العميل | `customerId` من قائمة `listParties('customers')` | `documents.party_type='customer'`, `documents.party_id`, `documents.party_name_snapshot` | الاسم يحفظ كلقطة تاريخية |
| الصنف | `productId` من `listProducts()` | `document_lines.product_id`, `product_name_snapshot` | الاسم التاريخي لا يتغير بتعديل بطاقة الصنف |
| الوحدة | الوحدة المختارة من `listUnits(productId)` | `document_lines.unit_name_snapshot`, `factor_to_base_snapshot` | معامل التحويل يثبت وقت العملية |
| الكمية | `n` بعد إدخالها بلوحة الأرقام | `document_lines.entered_quantity`, `base_quantity` | الثانية محولة لوحدة الأساس |
| سعر البيع | `u['sale_price_minor']` | `document_lines.unit_price_minor` | السعر المعروض لكل وحدة |
| إجمالي السطر | يحسب في الواجهة | لا يوجد عمود مستقل | مشتق من الكمية × سعر الوحدة |
| منشئ المستند | قيمة ثابتة `userId: 1` في الاستدعاء | `documents.created_by` | معرف تجريبي؛ لا يمثل جلسة مستخدم حقيقية |

**سلوك غير موجود في هذه الشاشة حالياً:** لا يوجد حقل مبلغ نقدي حر أو خصم أو ضريبة أو اختيار طريقة دفع في كاشير الصرف في هذا المصدر.

## 3. كاشير التوريد — `_openReceiptTransaction()`

الموضع: `lib/main.dart:463-635`.  
الحفظ: `createDocument(kind: 'receipt')` ثم `submitDocument()`.

| العنصر | متغير UI | العمود / الجدول | ملاحظات |
|---|---|---|---|
| المورد | `partyId` | `documents.party_type='supplier'`, `party_id`, `party_name_snapshot` | طرف الفاتورة |
| الصنف | `productId` | `document_lines.product_id`, `product_name_snapshot` | — |
| وحدة التوريد | `unitId` من `listPurchaseUnits()` | `unit_name_snapshot`, `factor_to_base_snapshot` | الشاشة تقيد الاختيار بوحدة الشراء |
| الكمية | `quantity` | `entered_quantity`, `base_quantity` | تتحول لوحدة الأساس |
| سعر الشراء | `price` | `document_lines.unit_price_minor` | سعر العملية الفعلي، وليس سعر بطاقة الصنف |
| توزيع الصلاحية | `expirySplits` | `document_line_expiry_splits` | لكل توزيع تاريخ وكمية ووحدة ومعامل تحويل |
| ملاحظة العبوة | بيانات السطر | `document_lines.packaging_note` | وصف إضافي محفوظ بالسطر |
| اسم الطرف | `partyName` | `documents.party_name_snapshot` | لقطة اسم المورد أو العميل |

**ملاحظة:** يوجد حقل سعر في نموذج العملية لكلا الوضعين، لكن في مسار التوريد يجب إدخال سعر شراء موجب. لا يعني ذلك أن النظام ينفذ متوسط تكلفة مرجحاً؛ لا يوجد في هذا المخطط حقل تكلفة مخزون موزونة أو سجل تقييم تكلفة مستقل.

## 4. بطاقة الصنف وسجل الحركة

### بطاقة الصنف — `editProduct()`
الموضع: `lib/main.dart:689-714`; الحفظ `updateProduct()` في قاعدة البيانات.

| عنصر الشاشة | متغير | العمود |
|---|---|---|
| الاسم | `name` | `products.name` |
| سعر الشراء | `purchase` | `products.purchase_price_minor` |
| سعر الصرف | `issue` | `products.issue_price_minor` |

هذه الحقول على بطاقة الصنف لا تستبدل سعر السطر التاريخي في الفاتورة.

### سجل حركة وصلاحية الصنف — `showProductHistory()`
الموضع: `lib/main.dart:636-688`.

- `productBatchBalances(productId)` يعرض الدفعات وتواريخ الانتهاء والكميات المستلمة والمتبقية.
- `productMovementHistory(productId)` يعرض الحركات واتجاهها وتاريخها والمستند المرتبط.
- المصدر المخزن: `stock_batches`, `stock_movement_allocations`, `stock_movements`, `documents`, `document_lines`.
- الرصيد المعروض محسوب من الحركات والتخصيصات، وليس حقل رصيد يدوي.

## 5. إدارة الموردين والعملاء

الموضع: `manageParties()` من `lib/main.dart:716-791`.

| العنصر | العمود |
|---|---|
| نوع الطرف (مورد / عميل) | يحدد الجدول `suppliers` أو `customers` |
| الاسم | `name` |
| الهاتف | `phone` |
| العنوان | لا يوجد حقل إدخال في نموذج الإدارة الحالي، رغم وجود العمود |
| الملاحظات | لا يوجد حقل إدخال في نموذج الإدارة الحالي، رغم وجود العمود |
| أرشفة الطرف | `is_active=0` عبر `archiveParty()` |

## 6. تأكيد التسليم

الموضع: `showDeliveries()` في `lib/main.dart:792-843`.

| العنصر | العمود |
|---|---|
| اسم المستلم | `documents.recipient_name` |
| ملاحظة / إثبات توقيع | `documents.recipient_signature_note` |
| حالة التسليم | `documents.delivery_status` |
| المستخدم المنفذ | `documents.delivered_by` |
| وقت التسليم | `documents.delivered_at` |

استدعاء الواجهة الحالي يمرر `userId: 1`، لذلك هو معرف تجريبي وليس حساب مستخدم مصادقاً عليه.

## 7. شاشة الاعتمادات

الموضع: `showApprovals()` في `lib/main.dart:844-888`.

- الاعتماد: `approveDocument(documentId, approverId: 1)`.
- الرفض: حقل السبب يحفظ في `documents.rejection_reason`، ويسجل حدثاً في `approval_history`.
- حقول الحالة: `documents.status`, `approved_by`, `approved_at`.
- الحركات لا تنشأ عند إنشاء المسودة أو إرسالها؛ الترحيل مرتبط بالاعتماد في `approveDocument()`.

**قيد أمني:** معرف المعتمد ثابت 1 في الواجهة الحالية؛ لا توجد مصادقة/صلاحيات فعلية تربط الإجراء بمستخدم حقيقي.

## 8. شاشة المرتجعات

الموضع: `showReturns()` في `lib/main.dart:1096-1218`.

| العنصر | المتغير | العمود / الأثر |
|---|---|---|
| نوع المرتجع | `return_in` أو `return_out` | `documents.kind` |
| الفاتورة الأصلية | `selectedId` | `documents.reference_document_id` |
| السطر الأصلي | `source_line_id` | `document_lines.reference_document_line_id` |
| الكمية المرتجعة | `quantities[lineId]` | `document_lines.entered_quantity` و`base_quantity` بعد التحويل |
| سبب المرتجع | `reason` | في لقطة المصدر يمرر إلى `createReturnDocument`; يجب التحقق من موضع حفظه الدقيق قبل اعتباره حقلاً دائماً |

**حالة التنفيذ:** توجد واجهة ودوال إنشاء واعتماد للمرتجع، لكن اختبار التكامل الحالي فشل. كما أن README يدرج مسار المرتجعات الكامل ضمن الأعمال غير الجاهزة للإنتاج. لذلك وجود الواجهة والكود لا يساوي اعتماد الميزة تشغيلياً.

## 9. كشوف الحساب والدفعات

### كشف حساب العميل
الموضع: `showCustomerAccounts()` في `lib/main.dart:1281-1352`.
- اختيار العميل يحدد `customer_id`.
- الكشف يجمع فواتير الصرف المعتمدة والمرتجعات المعتمدة ودفعات العميل.
- الدفعة تحفظ في `customer_payments`.

### كشف حساب المورد
الموضع: `showSupplierAccounts()` في `lib/main.dart:1353-1421`.
- اختيار المورد يحدد `supplier_id`.
- الكشف يجمع فواتير التوريد المعتمدة ومرتجعات المورد المعتمدة ودفعات المورد.
- الدفعة تحفظ في `supplier_payments`.

### نموذج الدفعة
الموضع: `recordSupplierPayment()` و`recordCustomerPayment()` في `lib/main.dart:1423-1479`.

| عنصر النموذج | متغير | عمود قاعدة البيانات |
|---|---|---|
| المبلغ | `amount` | `amount_minor` |
| تاريخ الدفع | يولد داخل طبقة البيانات | `payment_date` |
| طريقة الدفع | `method` | `payment_method` |
| رقم المرجع | `reference` | `reference_no` |
| ملاحظات | `notes` | `notes` |
| المستخدم | ثابت 1 في الاستدعاء | `created_by` |

لا يوجد حالياً تخصيص للدفعة على فاتورة بعينها، ولا ربط واضح بسند صندوق/بنك منفصل؛ الدفعات تخصم من رصيد الطرف الإجمالي.

## 10. عناصر واجهة غير مرتبطة حالياً بحقول تخزين

- اختيار اللغة في القائمة يغير Locale داخل حالة التطبيق؛ يوجد `app_settings` لكن لا يظهر من هذا المسار أن الاختيار يحفظ فيه.
- إجمالي الفاتورة وبعض المجاميع يعاد حسابها في الاستعلام أو الواجهة، وليست أعمدة مستقلة.
- اللون التحذيري لبطاقة الصنف مشتق من `stock_base` و`nearest_expiry_date` و`last_activity_at`.
- رسائل Snackbar والحالة المؤقتة للسلة لا تحفظ ككيانات مستقلة.

## 11. ما ينبغي أن يضاف في أي شاشة جديدة

لكل حقل جديد يجب توثيق:
1. اسم عنصر الإدخال في الواجهة.
2. اسم متغير Dart الذي يحمل القيمة.
3. التحقق من القيمة قبل الحفظ.
4. وسيط الدالة التي تستقبلها.
5. الجدول والعمود النهائيان.
6. هل القيمة أصلية أم محسوبة أم Snapshot.
7. أثرها على الرصيد أو الحسابات أو التقارير.
8. اختبار يغطي الإدخال والحفظ وإعادة القراءة وحالات الرفض.
