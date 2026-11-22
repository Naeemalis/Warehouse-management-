import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.inventory_2_outlined, title: 'الأصناف والمخزون', subtitle: 'الأرصدة وحالة التوفر'),
      (icon: Icons.move_to_inbox_outlined, title: 'استلام التوريد', subtitle: 'إنشاء واعتماد مستندات الاستلام'),
      (icon: Icons.outbox_outlined, title: 'صرف المخزون', subtitle: 'الصرف والتحقق من الرصيد'),
      (icon: Icons.assignment_return_outlined, title: 'مرتجعات الموردين', subtitle: 'الربط بدفعة الاستلام الأصلية'),
      (icon: Icons.fact_check_outlined, title: 'الجرد', subtitle: 'تجميد الحركات ومطابقة الرصيد'),
      (icon: Icons.assessment_outlined, title: 'التقارير', subtitle: 'الحركات والأرصدة وسجل التدقيق'),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('NaeemSoft WMS'), centerTitle: false),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('إدارة المخزون', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    const Text('نسخة محلية — مخزن واحد — تعمل دون اتصال'),
                    const SizedBox(height: 14),
                    const Row(children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('لا يُرحّل أي مستند إلى المخزون قبل اعتماده')),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                  childAspectRatio: 1.22,
                ),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('واجهة "${item.title}" ضمن مرحلة التنفيذ التالية')),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(item.icon, size: 30, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
