# قاموس قاعدة البيانات — SQLite

## 1. معلومات عامة

- ملف قاعدة البيانات: `naeemsoft_wms.db`
- المحرك: SQLite عبر `sqflite`.
- موضع فتح قاعدة البيانات: `lib/data/wms_database.dart` — `WmsDatabase.database`.
- إصدار المخطط الحالي في لقطة المصدر: **7**.
- تفعيل المفاتيح الخارجية: `PRAGMA foreign_keys = ON`.
- قاعدة العمل: حركات المخزون تُنشأ عند اعتماد المستند، لا عند حفظ المسودة أو إرسالها للاعتماد.

## 2. اصطلاحات البيانات

- `id`: مفتاح أساسي رقمي Auto Increment ما لم يذكر خلاف ذلك.
- `*_minor`: مبلغ مخزن بوحدة العملة الصغرى كعدد صحيح؛ واجهة العرض تحول المبلغ بقسمته على 100 في دالة `money`. لا تفترض أن كل العملات لها منزلتان عشريتان دون مراجعة إعداد العملة.
- `*_base`: كمية محولة إلى وحدة المخزون الأساسية للصنف.
- `*_snapshot`: قيمة تاريخية محفوظة وقت إنشاء سطر المستند حتى لا تتغير الفاتورة القديمة عند تعديل تعريف الصنف أو وحداته.
- التواريخ: مخزنة كنص `TEXT`، وغالباً بصيغة ISO 8601.
- أعمدة `created_by` و`approved_by` و`actor_id` موجودة، لكن وجودها لا يعني أن واجهة تسجيل الدخول وربط المستخدم الحقيقي مكتملان.

## 3. الجداول والحقول

### 3.1 `products` — تعريف الأصناف

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف الصنف |
| code | TEXT UNIQUE | رمز اختياري فريد |
| name | TEXT NOT NULL | اسم الصنف |
| category | TEXT | التصنيف |
| base_unit_name | TEXT NOT NULL | وحدة المخزون الأساسية |
| tracking_mode | TEXT, count/weight/volume | طريقة تتبع الصنف |
| purchase_price_minor | INTEGER DEFAULT 0 | سعر شراء محفوظ على بطاقة الصنف |
| issue_price_minor | INTEGER DEFAULT 0 | سعر صرف عام محفوظ على بطاقة الصنف |
| min_stock_base | REAL DEFAULT 0 | حد أدنى بوحدة الأساس |
| is_active | INTEGER DEFAULT 1 | حالة النشاط/الأرشفة |
| created_at | TEXT NOT NULL | وقت الإنشاء |
| updated_at | TEXT NOT NULL | وقت آخر تحديث |

**يستخدم في:** معرض الأصناف، إنشاء وتعديل الصنف، قوائم الأصناف، احتساب الرصيد المعروض.

### 3.2 `product_units` — وحدات الصنف والتحويل

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف الوحدة |
| product_id | FK → products.id | الصنف المالك للوحدة |
| unit_name | TEXT NOT NULL | اسم الوحدة |
| factor_to_base | REAL > 0 | معامل التحويل إلى وحدة الأساس |
| sort_order | INTEGER DEFAULT 0 | ترتيب العرض |
| sale_price_minor | INTEGER >= 0 | سعر البيع لهذه الوحدة |
| is_purchase_unit | INTEGER 0/1 | هل هي وحدة التوريد |
| is_active | INTEGER 0/1 | حالة الوحدة |
| created_at | TEXT NOT NULL | وقت الإنشاء |

قيود: `UNIQUE(product_id, unit_name)`، وفهرس فريد جزئي يضمن وحدة توريد واحدة للصنف.

**يستخدم في:** محرر الصنف، كاشير التوريد، كاشير الصرف، تحويل الكميات والأسعار.

### 3.3 `suppliers` — الموردون

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف المورد |
| name | TEXT NOT NULL | الاسم |
| phone | TEXT | الهاتف |
| address | TEXT | العنوان |
| notes | TEXT | ملاحظات |
| is_active | INTEGER DEFAULT 1 | نشط أو مؤرشف |
| created_at | TEXT NOT NULL | وقت الإنشاء |

### 3.4 `customers` — العملاء

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف العميل |
| name | TEXT NOT NULL | الاسم |
| phone | TEXT | الهاتف |
| address | TEXT | العنوان |
| notes | TEXT | ملاحظات |
| is_active | INTEGER DEFAULT 1 | نشط أو مؤرشف |
| created_at | TEXT NOT NULL | وقت الإنشاء |

### 3.5 `documents` — رأس المستندات

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف المستند |
| document_no | TEXT UNIQUE NOT NULL | رقم المستند |
| kind | receipt/issue/transfer/return_in/return_out/adjustment | نوع الحركة |
| status | draft/pending_approval/approved/rejected/cancelled | حالة المستند |
| party_type | supplier/customer/department/warehouse | نوع الطرف |
| party_id | INTEGER | معرف الطرف؛ لا يظهر قيد FK مباشر هنا |
| party_name_snapshot | TEXT | اسم الطرف وقت العملية |
| notes | TEXT | ملاحظات |
| reference_document_id | FK → documents.id | المستند الأصلي للمرتجع أو المرجع |
| created_by | INTEGER | منشئ المستند |
| created_at | TEXT NOT NULL | تاريخ الإنشاء |
| submitted_at | TEXT | تاريخ الإرسال للاعتماد |
| approved_by | INTEGER | المعتمد |
| approved_at | TEXT | وقت الاعتماد |
| rejection_reason | TEXT | سبب الرفض |
| delivery_status | not_ready/awaiting_delivery/delivered/partially_delivered | حالة التسليم |
| delivered_by | INTEGER | منفذ التسليم |
| delivered_at | TEXT | وقت التسليم |
| recipient_name | TEXT | اسم المستلم |
| recipient_signature_note | TEXT | ملاحظة التوقيع/الاستلام |

**قاعدة مهمة:** `party_id` لا يملك في تعريف الجدول الحالي مفتاحاً خارجياً موحداً لأن الطرف قد يكون مورداً أو عميلاً أو جهة.

### 3.6 `document_lines` — تفاصيل المستند

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف السطر |
| document_id | FK → documents.id | المستند |
| product_id | FK → products.id | الصنف |
| product_name_snapshot | TEXT NOT NULL | اسم الصنف تاريخياً |
| unit_name_snapshot | TEXT NOT NULL | الوحدة المستخدمة |
| entered_quantity | REAL > 0 | الكمية كما أدخلها المستخدم |
| factor_to_base_snapshot | REAL > 0 | معامل التحويل وقت العملية |
| base_quantity | REAL > 0 | الكمية المحولة لوحدة الأساس |
| unit_price_minor | INTEGER DEFAULT 0 | سعر الوحدة في السطر |
| packaging_note | TEXT | وصف العبوة/سبب المرتجع |
| created_at | TEXT NOT NULL | وقت إنشاء السطر |
| reference_document_line_id | FK → document_lines.id | سطر الفاتورة الأصلية للمرتجع |

هذه اللقطات التاريخية تحفظ معنى الفاتورة حتى لو تغير اسم الصنف أو معامل وحدته لاحقاً.

### 3.7 `stock_movements` — دفتر حركة المخزون

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف الحركة |
| document_id | FK → documents.id | المستند المصدر |
| document_line_id | FK → document_lines.id | سطر المستند |
| product_id | FK → products.id | الصنف |
| direction | IN/OUT | دخول أو خروج |
| quantity_base | REAL > 0 | الكمية بوحدة الأساس |
| created_by | INTEGER | منفذ الحركة |
| created_at | TEXT NOT NULL | وقت الحركة |

قيد `UNIQUE(document_line_id)` يمنع ترحيل حركة ثانية لنفس سطر المستند.

**الرصيد الحالي** يحسب من مجموع حركات IN ناقص OUT؛ ليس حقلاً ثابتاً في جدول المنتجات.

### 3.8 `approval_history` — سجل الاعتمادات

| الحقل | الغرض |
|---|---|
| id | معرف السجل |
| document_id | المستند المرتبط |
| action | submitted / approved / rejected / cancelled |
| actor_id | المستخدم المنفذ |
| actor_name_snapshot | اسم المستخدم وقت العملية |
| notes | ملاحظات |
| created_at | وقت الحدث |

### 3.9 `audit_log` — سجل التدقيق

| الحقل | الغرض |
|---|---|
| id | معرف السجل |
| entity_type | نوع الكيان |
| entity_id | معرف الكيان |
| action | العملية |
| actor_id | المستخدم |
| details | تفاصيل إضافية |
| created_at | وقت العملية |

### 3.10 `customer_payments` — دفعات العملاء

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| id | INTEGER PK | معرف الدفعة |
| customer_id | FK → customers.id | العميل |
| amount_minor | INTEGER > 0 | المبلغ |
| payment_date | TEXT NOT NULL | تاريخ الدفعة |
| payment_method | TEXT DEFAULT cash | طريقة الدفع |
| reference_no | TEXT | مرجع الدفع |
| notes | TEXT | ملاحظات |
| created_by | INTEGER | المستخدم |
| created_at | TEXT NOT NULL | وقت التسجيل |

### 3.11 `supplier_payments` — دفعات الموردين

نفس بنية دفعات العملاء، مع `supplier_id` المرتبط بجدول `suppliers`.

### 3.12 `app_settings` — إعدادات التطبيق

| الحقل | النوع / القيد | الغرض |
|---|---|---|
| setting_key | TEXT PK | مفتاح الإعداد |
| setting_value | TEXT NOT NULL | قيمة الإعداد |

الإعداد الافتراضي المسجل حالياً: `language = ar`.

### 3.13 `document_line_expiry_splits` — توزيع الكمية حسب الصلاحية

| الحقل | الغرض |
|---|---|
| id | معرف السجل |
| document_line_id | سطر التوريد |
| expiry_date | تاريخ الانتهاء |
| entered_quantity | الكمية المدخلة |
| unit_name_snapshot | اسم الوحدة وقت التوريد |
| factor_to_base_snapshot | معامل التحويل التاريخي |
| quantity_base | الكمية بوحدة الأساس |
| created_at | وقت التسجيل |

### 3.14 `stock_batches` — دفعات المخزون

| الحقل | الغرض |
|---|---|
| id | معرف الدفعة |
| product_id | الصنف |
| receipt_document_id | مستند التوريد |
| receipt_document_line_id | سطر التوريد |
| expiry_date | تاريخ الصلاحية |
| received_quantity_base | الكمية المستلمة بوحدة الأساس |
| received_quantity | الكمية المدخلة بوحدة التوريد |
| unit_name_snapshot | الوحدة التاريخية |
| factor_to_base_snapshot | معامل التحويل التاريخي |
| created_at | وقت الاستلام |

### 3.15 `stock_movement_allocations` — توزيع حركات المخزون على الدفعات

| الحقل | الغرض |
|---|---|
| id | معرف التوزيع |
| stock_movement_id | حركة المخزون |
| batch_id | دفعة المخزون |
| quantity_base | الكمية المخصصة بوحدة الأساس |
| entered_quantity | الكمية بوحدة الحركة |
| unit_name_snapshot | اسم الوحدة |
| factor_to_base_snapshot | معامل التحويل |

## 4. العلاقات الأساسية

- `products 1—N product_units`
- `documents 1—N document_lines`
- `products 1—N document_lines`
- `documents 1—N stock_movements`
- `document_lines 1—0..1 stock_movements` بسبب القيد الفريد على `document_line_id`
- `documents 1—N approval_history`
- `customers 1—N customer_payments`
- `suppliers 1—N supplier_payments`
- `documents 1—N stock_batches` عبر مستند وسطر التوريد
- `document_lines 1—N document_line_expiry_splits`
- `document_lines 1—N document_lines` عبر `reference_document_line_id` لربط المرتجع بالسطر الأصلي
- `stock_movements 1—N stock_movement_allocations`
- `stock_batches 1—N stock_movement_allocations`

## 5. قواعد العمل التي تفرضها طبقة البيانات

1. المسودة والمستند المرسل للاعتماد والمرفوض والملغى لا يرحّلون حركة مخزون.
2. الاعتماد ينشئ حركة المخزون داخل معاملة SQLite.
3. الصرف يتحقق من توفر الرصيد قبل ترحيل OUT.
4. لا يرحّل سطر المستند أكثر من حركة واحدة.
5. المرتجع يجب أن يشير إلى فاتورة أصلية معتمدة وسطر أصلي مطابق للصنف.
6. الكمية المرتجعة لا تتجاوز الكمية الأصلية بعد احتساب المرتجعات النشطة.
7. مرتجع المورد يتحقق أيضاً من الكمية المتاحة في دفعات الاستلام الأصلية.
8. أرصدة العميل والمورد تعرض من مستندات معتمدة ودفعات ومرتجعات وفق استعلامات كشف الحساب.

## 6. سجل الترحيلات (Migrations)

الإصدار الحالي 7. الشفرة الحالية تتضمن ترقيات شرطية:
- قبل الإصدار 2: إنشاء `customer_payments`.
- قبل الإصدار 3: إنشاء جداول تتبع الصلاحية والدفعات وتوزيع الحركات التاريخية.
- قبل الإصدار 4: إضافة `sale_price_minor` إلى `product_units` وتعبئته من سعر الصنف القديم.
- قبل الإصدار 5: إنشاء `supplier_payments`.
- قبل الإصدار 6: إضافة `is_purchase_unit` وتحديد وحدة شراء واحدة لكل صنف.
- قبل الإصدار 7: إضافة مرجع المستند الأصلي وسطره للمرتجعات.

> يجب مراجعة ترتيب كل Migration واختباره على قواعد بيانات حقيقية من الإصدارات السابقة قبل أي رفع لإصدار المخطط. لا تُجرّب الترحيلات على قاعدة بيانات المستخدم الفعلية دون نسخة احتياطية.

## 7. ما لا ينبغي افتراضه

- وجود حقول المستخدم لا يثبت اكتمال المصادقة أو صلاحيات الأدوار.
- وجود جداول الدفعات لا يعني أن الدفعات موزعة على فواتير منفردة؛ الكود الحالي يعرض كشف حساب إجمالياً للطرف.
- وجود جداول الدفعات والصلاحية لا يعني اكتمال واجهة الجرد أو إدارة الدفعات أو تقارير الصلاحية.
- `transfer` و`adjustment` موجودان ضمن القيم المقبولة لنوع المستند، لكن وجود القيمة في القيد لا يثبت اكتمال شاشة التحويل أو التسوية.
