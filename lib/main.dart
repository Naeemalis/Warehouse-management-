import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/wms_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WmsDatabase.instance.database;
  runApp(const NaeemWmsApp());
}

class NaeemWmsApp extends StatefulWidget {
  const NaeemWmsApp({super.key});
  @override
  State<NaeemWmsApp> createState() => _NaeemWmsAppState();
}

class _NaeemWmsAppState extends State<NaeemWmsApp> {
  Locale _locale = const Locale('ar');
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'NaeemSoft WMS',
    locale: _locale,
    supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF176B57), scaffoldBackgroundColor: const Color(0xFFF5F7F6)),
    home: WarehouseHome(onLanguageChanged: (code) => setState(() => _locale = Locale(code)), languageCode: _locale.languageCode),
  );
}

class WarehouseHome extends StatelessWidget {
  const WarehouseHome({super.key, required this.onLanguageChanged, required this.languageCode});
  final ValueChanged<String> onLanguageChanged;
  final String languageCode;
  static const words = {
    'ar': ['إدارة المستودع','معرض المنتجات','استلام بضاعة','صرف بضاعة','المخزون','لم تتم إضافة منتجات بعد','ابدأ بإضافة الأصناف ووحدات التعبئة الخاصة بها.','إضافة منتج','نسخة تأسيسية قيد التطوير'],
    'en': ['Warehouse Management','Product Gallery','Receive Goods','Issue Goods','Inventory','No products have been added yet','Start by adding products and their packaging units.','Add Product','Foundation build in progress'],
    'fr': ['Gestion de l’entrepôt','Catalogue des produits','Réception','Sortie','Stock','Aucun produit ajouté','Ajoutez des produits et leurs unités d’emballage.','Ajouter un produit','Version initiale en développement'],
  };
  @override
  Widget build(BuildContext context) {
    final t = words[languageCode] ?? words['ar']!;
    final rtl = languageCode == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(t[0]), actions: [PopupMenuButton<String>(icon: const Icon(Icons.language), onSelected: onLanguageChanged, itemBuilder: (_) => const [PopupMenuItem(value: 'ar', child: Text('العربية')), PopupMenuItem(value: 'en', child: Text('English')), PopupMenuItem(value: 'fr', child: Text('Français'))])]),
        body: SafeArea(child: Column(children: [
          Container(margin: const EdgeInsets.fromLTRB(16, 12, 16, 0), padding: const EdgeInsets.all(18), width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.warehouse_outlined, color: Colors.white, size: 38), const SizedBox(width: 14), Text(t[4], style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white))])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Row(children: [Expanded(child: Text(t[1], style: Theme.of(context).textTheme.titleLarge)), FilledButton.tonalIcon(onPressed: () => _notReady(context, t[7]), icon: const Icon(Icons.add), label: Text(t[7]))])),
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inventory_2_outlined, size: 72, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text(t[5], style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center), const SizedBox(height: 8), Text(t[6], textAlign: TextAlign.center), const SizedBox(height: 12), Text(t[8], style: Theme.of(context).textTheme.labelSmall)])))),
        ])),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [Expanded(child: FilledButton.icon(onPressed: () => _notReady(context, t[2]), icon: const Icon(Icons.move_to_inbox_outlined), label: Text(t[2]))), const SizedBox(width: 10), Expanded(child: FilledButton.tonalIcon(onPressed: () => _notReady(context, t[3]), icon: const Icon(Icons.outbox_outlined), label: Text(t[3])))]))),
      ),
    );
  }
  void _notReady(BuildContext context, String feature) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature — implementation is in progress')));
}
