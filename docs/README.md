# NaeemSoft WMS — Technical Documentation

هذه الوثائق تشرح التنفيذ الفعلي في الشفرة، لا التصميم النظري فقط.

## نطاق النسخة الموثقة

- Repository: `Naeemalis/Warehouse-management-`
- Documentation branch: `docs/technical-reference`
- Source snapshot: `5ba022c3e9fb428c1554e94217762cb19951cf37`
- Main UI: `lib/main.dart`
- SQLite/data layer: `lib/data/wms_database.dart`
- Unit conversion: `lib/domain/unit_conversion.dart`
- Current database schema version in this snapshot: **7**

> عند تغير الشفرة، يجب تحديث هذه الوثائق في نفس Pull Request. أسماء الدوال والحقول هي المرجع؛ أرقام الأسطر قد تتغير مع التطوير.

## دليل الوثائق

| الملف | المحتوى |
|---|---|
| [DATABASE-DICTIONARY.md](DATABASE-DICTIONARY.md) | الجداول والحقول والقيود والعلاقات في SQLite |
| [SCREEN-TO-CODE-MAP.md](SCREEN-TO-CODE-MAP.md) | كل شاشة، الدوال التي تشغلها، وطبقة البيانات التي تستدعيها |
| [SCREEN-FIELD-MAP.md](SCREEN-FIELD-MAP.md) | عناصر الإدخال في كل شاشة، متغيرات Dart، وأعمدة SQLite التي تحفظها |
| [CODE-REFERENCE.md](CODE-REFERENCE.md) | وظيفة دوال قاعدة البيانات ومدخلاتها ومخرجاتها والجداول التي تتعامل معها |
| [FUNCTION-FIELD-TRACE.md](FUNCTION-FIELD-TRACE.md) | تتبع الدوال: الحقول المقروءة والمكتوبة وتأثيرها على المخزون والحسابات |
| [VERIFICATION-STATUS.md](VERIFICATION-STATUS.md) | حالة الاختبارات والتحقق والقيود المعروفة في لقطة المصدر |

## قاعدة التوثيق

1. لا نصف وظيفة بأنها منفذة إلا إذا وجد تنفيذها في الشفرة.
2. نفرّق بين الحقل المخزن فعلياً والقيمة المحسوبة عند القراءة.
3. نذكر الشاشة التي تستدعي الوظيفة، أو نكتب «لا توجد شاشة مرتبطة حالياً» إذا كانت الوظيفة داخلية.
4. نذكر الاختبار الذي يغطي الوظيفة، ولا نعتبر وجود الاختبار دليلاً على نجاحه قبل مرور CI.
5. أي تغيير في Schema يتطلب تحديث قاموس البيانات وتوثيق Migration.
6. لا نغيّر سلوك التطبيق لمجرد إضافة الوثائق.
