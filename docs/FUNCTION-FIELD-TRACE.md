# تتبع الدوال: الحقول المقروءة والمكتوبة والأثر التشغيلي

هذه الوثيقة أعمق من قائمة أسماء الدوال: تحدد مدخلاتها، وما تقرؤه من SQLite، وما تكتبه، وما ينعكس على الشاشة أو الرصيد.

## 1. `createDocument()` — إنشاء فاتورة توريد أو صرف

المصدر: `lib/data/wms_database.dart:715-791`.  
الشاشات: `_openReceiptTransaction()` و`_openIssueCashier()`.

### المدخلات
- `kind`: receipt أو issue.
- `partyType`, `partyId`, `partyName`.
- `createdBy`.
- `lines[]`: product_id, unit_name, quantity, unit_price_minor، وقد تتضمن packaging_note وexpiry_splits.

### القراءة
- `products.id` للتأكد أن الصنف موجود.
- `product_units.product_id + unit_name + is_active` لإيجاد تعريف الوحدة ومعامل التحويل وسعر البيع.
- `product_units.is_purchase_unit` لمنع التوريد بوحدة غير وحدة الشراء.

### الكتابة
**documents**
- document_no, kind, status='draft', party_type, party_id, party_name_snapshot, created_by, created_at.

**document_lines**
- document_id, product_id, product_name_snapshot, unit_name_snapshot.
- entered_quantity, factor_to_base_snapshot, base_quantity.
- unit_price_minor, packaging_note, created_at.

**document_line_expiry_splits** في التوريد
- document_line_id, expiry_date, entered_quantity, unit_name_snapshot, factor_to_base_snapshot, quantity_base, created_at.

### قواعد مهمة
- لا ينشئ هذا الإجراء حركة مخزون.
- التوريد يقبل وحدة الشراء المحددة فقط.
- سعر شراء التوريد يجب أن يكون أكبر من صفر.
- في الصرف، السعر المخزن في السطر يؤخذ من `product_units.sale_price_minor` وليس من قيمة سعر حر يرسلها نموذج السلة.
- معامل التحويل يعاد أخذه من تعريف الوحدة في قاعدة البيانات؛ لا يعتمد على معامل مرسل من الواجهة.
- قيم الاسم والوحدة ومعامل التحويل تحفظ كلقطات تاريخية.

## 2. `submitDocument()` — إرسال الفاتورة للاعتماد

المصدر: `lib/data/wms_database.dart:793-816`.  
الشاشات: كاشير التوريد والصرف والمرتجعات.

### القراءة والتحقق
- يتحقق من وجود سطر واحد على الأقل في `document_lines`.
- يتحقق من حالة المستند الحالية قبل الانتقال.

### الكتابة
- `documents.status = pending_approval`
- `documents.submitted_at`
- صف في `approval_history`: document_id, action='submitted', actor_id, actor_name_snapshot, created_at.

### الأثر
لا يتغير المخزون عند الإرسال. يبقى المستند بانتظار الاعتماد.

## 3. `approveDocument()` — اعتماد وترحيل المخزون

المصدر: `lib/data/wms_database.dart:427-604`.  
الشاشة: `showApprovals()`، ونتيجة العملية تظهر في معرض الأصناف وسجل الحركة.

### القراءة والتحقق
- `documents.id/status/kind`: لا يقبل إلا مستنداً موجوداً وحالته pending_approval.
- `document_lines`: يتأكد من وجود تفاصيل.
- في الصرف: يجمع `base_quantity` لكل product_id ثم يقارن المطلوب برصيد `stock_movements`.
- في المرتجعات: يستدعي `_validateReturnDocument()` ويعيد التحقق من المستند الأصلي والكمية.
- في مرتجع المورد: يتحقق من توافر الكمية في دفعات التوريد الأصلية.
- في مرتجع العميل: يطابق المرتجع مع دفعات الكمية التي خرجت في الصرف الأصلي.

### الكتابة
**stock_movements**
- document_id, document_line_id, product_id, direction, quantity_base, created_by, created_at.
- direction=IN للتوريد ومرتجع العميل.
- direction=OUT للصرف ومرتجع المورد.

**stock_batches** و**stock_movement_allocations**
- تنشأ دفعات عند اعتماد التوريد.
- تخصص الحركات على الدفعات عند التوريد والصرف والمرتجعات وفق منطق التتبع.

**documents**
- status='approved', approved_by, approved_at.
- delivery_status يصبح awaiting_delivery للصرف، وnot_ready للأنواع الأخرى.

**approval_history**
- action='approved', actor_id, actor_name_snapshot, created_at.

### ضمانات
- كل الكتابات تتم ضمن SQLite transaction.
- القيد UNIQUE على stock_movements.document_line_id يمنع حركة ثانية لسطر المستند نفسه.
- لا ينشأ ترحيل مخزون عند المسودة أو الإرسال.
- هذا الإجراء لا يطبق صلاحيات المستخدم؛ يستقبل معرف المعتمد كوسيط فقط.

## 4. `createReturnDocument()` — إنشاء مرتجع

المصدر: `lib/data/wms_database.dart:365-425`.  
الشاشة: `showReturns()` في `lib/main.dart:1096-1218`.

### المدخلات
- `originalDocumentId`, `kind`, `createdBy`, `lines[]`، و`notes` اختياري على رأس المرتجع.
- كل سطر: `source_line_id`, `quantity`، و`reason` اختياري داخل بيانات السطر (ليس وسيطاً مستقلاً في توقيع الدالة).

### القراءة والتحقق
- الفاتورة الأصلية يجب أن تكون approved.
- return_in يجب أن يرجع إلى issue وparty_type=customer.
- return_out يجب أن يرجع إلى receipt وparty_type=supplier.
- السطر المصدر يجب أن ينتمي إلى الفاتورة المحددة.
- يمنع تكرار source_line_id في نفس المرتجع.
- كمية الإدخال `quantity` تُفسر بوحدة `unit_name_snapshot` للسطر الأصلي، وليست بوحدة الأساس تلقائياً. مثال: إذا كان السطر الأصلي كرتوناً بمعامل 10 قطع، فـ`0.2` كرتون تعادل قطعتين.
- يحول كمية المرتجع إلى وحدة الأساس باستخدام معامل التحويل التاريخي `factor_to_base_snapshot` في السطر الأصلي.
- يجمع المرتجعات pending_approval وapproved بوحدة الأساس لمنع تجاوز الكمية.

### الكتابة
**documents**
- document_no, kind, status='draft', party_type, party_id, party_name_snapshot.
- notes, created_by, created_at, reference_document_id.

**document_lines**
- document_id, product_id, product_name_snapshot, unit_name_snapshot.
- entered_quantity, factor_to_base_snapshot, base_quantity, unit_price_minor.
- packaging_note من input['reason'].
- reference_document_line_id.

### فجوة الواجهة
واجهة المرتجعات الحالية لا تعرض خانة سبب المرتجع ولا ترسل `reason` داخل `lines`. لذلك `packaging_note` يكون `NULL` من هذا المسار. يمكن لمستدعٍ آخر تمرير `input['reason']` وتحفظه الدالة في هذا العمود. كما أن واجهة المرتجعات الحالية تمرر `createdBy: 1` و`userId: 1`.

## 5. `_validateReturnDocument()` و`_activeReturnedBase()`

المصدر: `lib/data/wms_database.dart:303-364`.

- يقرآن رأس المستند المرجعي وتفاصيله.
- يجمعان الكميات المرتجعة النشطة من `document_lines.base_quantity` المرتبطة بالسطر الأصلي.
- يتحققان من نوع الفاتورة الأصلية والطرف وحالة الاعتماد ومطابقة الصنف.
- مرتجع المورد يراجع رصيد دفعة التوريد الأصلية.
- عند الاعتماد، يعاد التحقق مع استثناء مستند المرتجع الجاري اعتماده من التجميع لتجنب احتساب المستند مرتين.

## 6. `listProducts()` — بيانات معرض الأصناف

المصدر: `lib/data/wms_database.dart:624-644`.  
الشاشة: `WarehouseHome.build()` في `lib/main.dart:167-273`.

### الأعمدة الأصلية
- `products.*`: تعريف الصنف ووحدة الأساس ونوع التتبع والأسعار العامة وحالة النشاط.

### أعمدة محسوبة في الاستعلام
- `stock_base`: مجموع حركات IN ناقص OUT.
- `nearest_expiry_date`: أقرب تاريخ صلاحية متبقٍ وفق حساب الدفعات.
- `last_activity_at`: أحدث نشاط حركة للصنف.

### استخدام العرض
- `name`, `stock_base`, `base_unit_name` تظهر على بطاقة الصنف.
- `productStatusColor()` تستخدم الرصيد والصلاحية وآخر حركة لتلوين أيقونة الصنف.
- هذه القيم المشتقة ليست أعمدة مخزنة في جدول products.

## 7. `customerStatement()` و`supplierStatement()` — كشف الحساب

المصدر: `lib/data/wms_database.dart:1012-1093`.  
الشاشات: `showCustomerAccounts()` و`showSupplierAccounts()`.

### كشف العميل
- يقرأ فواتير issue المعتمدة.
- يقرأ مرتجعات return_in المعتمدة.
- يقرأ دفعات customer_payments.
- يعيد قيود كشف حساب مرتبة ورصيداً جارياً.

### كشف المورد
- يقرأ فواتير receipt المعتمدة.
- يقرأ مرتجعات return_out المعتمدة.
- يقرأ دفعات supplier_payments.
- يعيد قيود كشف حساب مرتبة ورصيداً جارياً.

### حد وظيفي
الدفعات تخصم من رصيد الطرف الإجمالي؛ لا يوجد جدول تخصيص دفعة على فاتورة منفردة. ولا يوجد في هذا المسار دفتر صندوق/بنك مستقل.

## 8. ملاحظات هندسية يجب معالجتها لاحقاً

1. فصل `main.dart` إلى ملفات شاشة/مكونات وخدمات دون تغيير السلوك، بعد إضافة اختبارات واجهة وخدمات.
2. استبدال userId الثابت بجلسة مستخدم موثقة قبل تفعيل نظام الصلاحيات.
3. إضافة حقل سبب مستقل للمرتجع إذا كان مطلوباً تشغيلياً، وعدم إساءة استخدام packaging_note لوصف سبب مالي/تشغيلي.
4. تم تحديد سبب فشل اختبار التكامل السابق: كمية مرتجع المورد كانت مرسلة بوحدة القطعة بينما الدالة تفسرها بوحدة سطر فاتورة التوريد الأصلية (الكرتون). صُحح الاختبار إلى 0.2 كرتون لمرتجع قطعتين و0.9 كرتون لمحاولة تجاوز التسع قطع، وصُحح رصيد المخزون المتوقع إلى 8. تحقق من نتيجة CI الجديدة قبل إعلان الجاهزية.
5. إضافة اختبارات ترحيل SQLite من كل إصدار سابق مدعوم.
6. توثيق كل حقل محسوب على أنه query alias لا عموداً دائماً.
