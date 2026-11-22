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
  Locale locale = const Locale('ar');
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'NaeemSoft WMS',
    locale: locale,
    supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF176B57),
      scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: WarehouseHome(
      language: locale.languageCode,
      onLanguage: (v) => setState(() => locale = Locale(v)),
    ),
  );
}

class WarehouseHome extends StatefulWidget {
  const WarehouseHome({super.key, required this.language, required this.onLanguage});
  final String language;
  final ValueChanged<String> onLanguage;
  @override
  State<WarehouseHome> createState() => _WarehouseHomeState();
}

class _WarehouseHomeState extends State<WarehouseHome> {
  final db = WmsDatabase.instance;
  List<Map<String, Object?>> products = [];
  List<Map<String, Object?>> pending = [];
  bool loading = true;

  static const Map<String, Map<String, String>> words = {
    'ar': {
      'title':'إدارة المستودع','gallery':'معرض المنتجات','receive':'استلام بضاعة',
      'issue':'صرف بضاعة','approvals':'طلبات الاعتماد','add':'إضافة منتج',
      'stock':'الرصيد بوحدة الأساس','empty':'لا توجد منتجات بعد','name':'اسم المنتج',
      'base':'وحدة الأساس','mode':'نوع الصنف','count':'عددي','weight':'وزني',
      'volume':'سائل/حجمي','units':'وحدات التعبئة الإضافية',
      'unitHint':'مثال: باكت=6، كرتون=24 (مقابل وحدة الأساس)',
      'save':'حفظ','cancel':'إلغاء','supplier':'المورد','customer':'العميل / الجهة',
      'chooseParty':'اختر الطرف','chooseProduct':'اختر المنتج','chooseUnit':'اختر الوحدة',
      'quantity':'الكمية','price':'سعر الوحدة','addCart':'إضافة إلى السلة',
      'cart':'السلة','submit':'إرسال للاعتماد','pending':'بانتظار الاعتماد',
      'approve':'اعتماد','reject':'رفض','noPending':'لا توجد طلبات معلقة',
      'created':'تم حفظ المنتج','sent':'تم إرسال المستند للاعتماد',
      'selectAll':'أكمل البيانات المطلوبة','badUnits':'صيغة الوحدات غير صحيحة',
      'baseNote':'وحدة الأساس تسجل تلقائياً بمعامل 1',
      'receipt':'استلام','issueDoc':'صرف','approved':'تم الاعتماد وترحيل المخزون',
      'rejection':'سبب الرفض','confirm':'تأكيد','noStock':'لا يوجد رصيد متاح',
      'unit':'الوحدة','product':'المنتج','qty':'الكمية','document':'المستند',
      'language':'اللغة','loading':'جارٍ التحميل'
    },
    'en': {
      'title':'Warehouse Management','gallery':'Product Gallery','receive':'Receive Goods',
      'issue':'Issue Goods','approvals':'Approval Queue','add':'Add Product',
      'stock':'Base-unit balance','empty':'No products yet','name':'Product name',
      'base':'Base unit','mode':'Product type','count':'Countable','weight':'Weight',
      'volume':'Liquid / volume','units':'Additional packaging units',
      'unitHint':'Example: Pack=6, Carton=24 (in base units)',
      'save':'Save','cancel':'Cancel','supplier':'Supplier','customer':'Customer / department',
      'chooseParty':'Choose party','chooseProduct':'Choose product','chooseUnit':'Choose unit',
      'quantity':'Quantity','price':'Unit price','addCart':'Add to basket',
      'cart':'Basket','submit':'Submit for approval','pending':'Pending approval',
      'approve':'Approve','reject':'Reject','noPending':'No pending documents',
      'created':'Product saved','sent':'Document submitted for approval',
      'selectAll':'Complete all required fields','badUnits':'Invalid unit format',
      'baseNote':'Base unit is automatically stored with factor 1',
      'receipt':'Receipt','issueDoc':'Issue','approved':'Approved and stock posted',
      'rejection':'Rejection reason','confirm':'Confirm','noStock':'No available stock',
      'unit':'Unit','product':'Product','qty':'Quantity','document':'Document',
      'language':'Language','loading':'Loading'
    },
    'fr': {
      'title':'Gestion de l’entrepôt','gallery':'Catalogue des produits','receive':'Réception',
      'issue':'Sortie de stock','approvals':'Demandes d’approbation','add':'Ajouter un produit',
      'stock':'Solde en unité de base','empty':'Aucun produit','name':'Nom du produit',
      'base':'Unité de base','mode':'Type de produit','count':'Unité','weight':'Poids',
      'volume':'Liquide / volume','units':'Unités d’emballage supplémentaires',
      'unitHint':'Exemple : Paquet=6, Carton=24 (en unités de base)',
      'save':'Enregistrer','cancel':'Annuler','supplier':'Fournisseur','customer':'Client / service',
      'chooseParty':'Choisir un tiers','chooseProduct':'Choisir un produit','chooseUnit':'Choisir une unité',
      'quantity':'Quantité','price':'Prix unitaire','addCart':'Ajouter au panier',
      'cart':'Panier','submit':'Soumettre pour approbation','pending':'En attente',
      'approve':'Approuver','reject':'Rejeter','noPending':'Aucune demande en attente',
      'created':'Produit enregistré','sent':'Document soumis pour approbation',
      'selectAll':'Veuillez remplir les champs obligatoires','badUnits':'Format des unités invalide',
      'baseNote':'L’unité de base est enregistrée avec le facteur 1',
      'receipt':'Réception','issueDoc':'Sortie','approved':'Approuvé et stock mis à jour',
      'rejection':'Motif du rejet','confirm':'Confirmer','noStock':'Stock disponible insuffisant',
      'unit':'Unité','product':'Produit','qty':'Quantité','document':'Document',
      'language':'Langue','loading':'Chargement'
    },
  };

  String get lang => widget.language;
  String t(String key) => words[lang]?[key] ?? words['en']![key]!;
  bool get rtl => lang == 'ar';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    products = await db.listProducts();
    pending = await db.pendingDocuments();
    if (mounted) setState(() => loading = false);
  }

  void message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('title')),
        actions: [
          IconButton(tooltip: lang=='ar'?'التسليمات':'Delivery', onPressed: () => showDeliveries(), icon: const Icon(Icons.local_shipping_outlined)),
          IconButton(tooltip: t('approvals'), onPressed: () => showApprovals(), icon: Badge(
            label: Text('${pending.length}'), isLabelVisible: pending.isNotEmpty,
            child: const Icon(Icons.fact_check_outlined))),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(value:'ar', child:Text('العربية')),
              PopupMenuItem(value:'en', child:Text('English')),
              PopupMenuItem(value:'fr', child:Text('Français')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: loading
          ? Center(child: Text(t('loading')))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12,12,12,4),
                child: Row(children: [
                  Expanded(child: _action(t('receive'), Icons.move_to_inbox, () => openTransaction(true))),
                  const SizedBox(width:8),
                  Expanded(child: _action(t('issue'), Icons.outbox, () => openTransaction(false))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16,14,16,8),
                child: Row(children: [
                  Expanded(child: Text(t('gallery'), style: Theme.of(context).textTheme.titleLarge)),
                  FilledButton.tonalIcon(onPressed: addProduct, icon: const Icon(Icons.add), label: Text(t('add'))),
                ]),
              ),
              Expanded(child: products.isEmpty
                ? ListView(children: [const SizedBox(height:90), Icon(Icons.inventory_2_outlined,size:68,color:Theme.of(context).colorScheme.primary), const SizedBox(height:12), Center(child:Text(t('empty')))])
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190, mainAxisExtent: 128,
                      crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: products.length,
                    itemBuilder: (context,index) {
                      final p = products[index];
                      return Card(child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => openTransaction(false, selectedProduct: p),
                        onLongPress: () => editProduct(p),
                        child: Padding(padding: const EdgeInsets.all(12), child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.inventory_2_outlined),
                            const Spacer(),
                            Text('${p['name']}', maxLines:2, overflow:TextOverflow.ellipsis, style: const TextStyle(fontWeight:FontWeight.w600)),
                            const SizedBox(height:4),
                            Text('${p['stock_base']} ${p['base_unit_name']}', style:Theme.of(context).textTheme.bodySmall),
                          ],
                        )),
                      ));
                    },
                  )),
            ]),
      ),
    ),
  );

  Widget _action(String label, IconData icon, VoidCallback onTap) => FilledButton.icon(
    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical:14)),
    onPressed: onTap, icon: Icon(icon), label: Text(label, maxLines:1, overflow:TextOverflow.ellipsis));

  Future<void> addProduct() async {
    final name = TextEditingController();
    final base = TextEditingController(text: lang == 'ar' ? 'حبة' : 'piece');
    final units = TextEditingController();
    String mode = 'count';
    final result = await showDialog<bool>(context:context, builder:(ctx) => StatefulBuilder(
      builder:(ctx,setLocal) => AlertDialog(
        title:Text(t('add')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min, children:[
          TextField(controller:name, decoration:InputDecoration(labelText:t('name'))),
          const SizedBox(height:10),
          TextField(controller:base, decoration:InputDecoration(labelText:t('base'))),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:mode, decoration:InputDecoration(labelText:t('mode')),
            items:[DropdownMenuItem(value:'count',child:Text(t('count'))),DropdownMenuItem(value:'weight',child:Text(t('weight'))),DropdownMenuItem(value:'volume',child:Text(t('volume')))],
            onChanged:(v)=>setLocal(()=>mode=v??'count')),
          const SizedBox(height:10),
          TextField(controller:units, decoration:InputDecoration(labelText:t('units'),hintText:t('unitHint')), maxLines:2),
          Align(alignment:AlignmentDirectional.centerStart, child:Text(t('baseNote'),style:Theme.of(ctx).textTheme.bodySmall)),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('save'))),
        ],
      )));
    if (result != true) return;
    if (name.text.trim().isEmpty || base.text.trim().isEmpty) { message(t('selectAll')); return; }
    final unitRows=<Map<String,Object?>>[
      {'unit_name':base.text.trim(),'factor_to_base':1.0}
    ];
    try {
      for (final part in units.text.split(',')) {
        if (part.trim().isEmpty) continue;
        final bits=part.split('=');
        if (bits.length!=2 || bits[0].trim().isEmpty) throw FormatException();
        final factor=double.parse(bits[1].trim().replaceAll(',', '.'));
        unitRows.add({'unit_name':bits[0].trim(),'factor_to_base':factor});
      }
      await db.saveProduct(name:name.text,baseUnit:base.text,trackingMode:mode,units:unitRows);
      await refresh(); message(t('created'));
    } catch (_) { message(t('badUnits')); }
  }

  Future<void> openTransaction(bool receiving,{Map<String,Object?>? selectedProduct}) async {
    final partyTable=receiving?'suppliers':'customers';
    final partyRows=await db.listParties(partyTable);
    final productRows=await db.listProducts();
    if (!mounted) return;
    if (partyRows.isEmpty) {
      final controller=TextEditingController();
      final created=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text(receiving?t('supplier'):t('customer')),
        content:TextField(controller:controller,decoration:InputDecoration(labelText:t('name'))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('save')))]));
      if (created==true && controller.text.trim().isNotEmpty) {
        await db.saveParty(supplier:receiving,name:controller.text);
        await openTransaction(receiving,selectedProduct:selectedProduct);
      }
      return;
    }
    if (productRows.isEmpty) { message(t('empty')); await addProduct(); return; }
    int? partyId=partyRows.first['id'] as int;
    int? productId=selectedProduct?['id'] as int? ?? productRows.first['id'] as int;
    List<Map<String,Object?>> units=await db.listUnits(productId!);
    int? unitId=units.isEmpty?null:units.first['id'] as int;
    final quantity=TextEditingController(text:'1');
    final price=TextEditingController(text:'0');
    final factor=TextEditingController(text: units.isEmpty ? '1' : '${units.first['factor_to_base']}');
    final packaging=TextEditingController();
    final basket=<Map<String,Object?>>[];
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(receiving?t('receive'):t('issue')),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(
          value:partyId,decoration:InputDecoration(labelText:receiving?t('supplier'):t('customer')),
          items:partyRows.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
          onChanged:(v)=>setLocal(()=>partyId=v)),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(
          value:productId,decoration:InputDecoration(labelText:t('product')),
          items:productRows.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
          onChanged:(v) async { if(v==null)return; final u=await db.listUnits(v); setLocal(() { productId=v; units=u; unitId=u.isEmpty?null:u.first['id'] as int; factor.text=u.isEmpty?'1':'${u.first['factor_to_base']}'; }); }),
        const SizedBox(height:10),
        DropdownButtonFormField<int>(
          value:unitId,decoration:InputDecoration(labelText:t('unit')),
          items:units.map((u)=>DropdownMenuItem(value:u['id'] as int,child:Text('${u['unit_name']}  (×${u['factor_to_base']})'))).toList(),
          onChanged:(v) { final u=units.firstWhere((x)=>x['id']==v); setLocal(() { unitId=v; factor.text='${u['factor_to_base']}'; }); }),
        const SizedBox(height:10),
        TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:t('quantity'))),
        if(receiving) ...[
          const SizedBox(height:10),
          TextField(controller:factor,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:lang=='ar'?'معامل التحويل إلى وحدة الأساس':'Conversion factor to base unit')),
          const SizedBox(height:8),
          TextField(controller:packaging,decoration:InputDecoration(labelText:lang=='ar'?'تفاصيل التعبئة الفعلية':'Actual packaging details',hintText:lang=='ar'?'مثال: 4 بواكت × 6 حبات':'e.g. 4 packs × 6 pieces')),
          const SizedBox(height:8),
          TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:t('price'))),
        ],
        const SizedBox(height:12),
        FilledButton.icon(onPressed:(){
          if(productId==null||unitId==null)return;
          final product=productRows.firstWhere((p)=>p['id']==productId);
          final unit=units.firstWhere((u)=>u['id']==unitId);
          final q=double.tryParse(quantity.text.replaceAll(',','.'))??0;
          if(q<=0)return;
          basket.add({
            'product_id':productId,'product_name':product['name'],
            'unit_name':unit['unit_name'],'factor_to_base':receiving?(double.tryParse(factor.text.replaceAll(',','.'))??0):unit['factor_to_base'],
            'packaging_note':receiving?packaging.text:null,
            'quantity':q,'unit_price_minor':((double.tryParse(price.text)??0)*100).round(),
          });
          quantity.text='1'; setLocal((){});
        },icon:const Icon(Icons.add_shopping_cart),label:Text(t('addCart'))),
        const Divider(height:22),
        Align(alignment:AlignmentDirectional.centerStart,child:Text('${t('cart')} (${basket.length})',style:const TextStyle(fontWeight:FontWeight.bold))),
        ...basket.map((line)=>ListTile(
          dense:true,contentPadding:EdgeInsets.zero,
          title:Text('${line['product_name']}'),
          subtitle:Text('${line['quantity']} × ${line['unit_name']}'),
          trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setLocal(()=>basket.remove(line))),
        )),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('cancel'))),
        FilledButton(onPressed:basket.isEmpty?null:() async {
          try {
            final party=partyRows.firstWhere((p)=>p['id']==partyId);
            final id=await db.createDocument(
              kind:receiving?'receipt':'issue',
              partyType:receiving?'supplier':'customer',
              partyId:partyId!,partyName:party['name'] as String,createdBy:1,
              lines:basket.map((e)=>Map<String,Object?>.from(e)).toList(),
            );
            await db.submitDocument(documentId:id,userId:1);
            if(ctx.mounted) Navigator.pop(ctx);
            await refresh(); message(t('sent'));
          } catch(e) { message(e.toString()); }
        },child:Text(t('submit'))),
      ],
    )));
  }

  Future<void> showApprovals() async {
    await refresh();
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>Directionality(textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.72,
          child:Column(children:[
            Text(t('approvals'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:12),
            Expanded(child:pending.isEmpty?Center(child:Text(t('noPending'))):ListView.builder(
              itemCount:pending.length,
              itemBuilder:(ctx,i){
                final doc=pending[i];
                return Card(child:ListTile(
                  title:Text('${doc['document_no']} · ${doc['party_name_snapshot']}'),
                  subtitle:Text(doc['kind']=='receipt'?t('receipt'):t('issue')),
                  isThreeLine:false,
                  trailing:Wrap(spacing:4,children:[
                    IconButton(tooltip:t('approve'),icon:const Icon(Icons.check_circle,color:Colors.green),onPressed:() async {
                      try { await db.approveDocument(documentId:doc['id'] as int,approverId:1); await refresh(); if(ctx.mounted)Navigator.pop(ctx); message(t('approved')); }
                      catch(e){message(e.toString());}
                    }),
                    IconButton(tooltip:t('reject'),icon:const Icon(Icons.cancel,color:Colors.red),onPressed:() async {
                      final reason=TextEditingController();
                      final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
                        title:Text(t('rejection')),content:TextField(controller:reason),
                        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('confirm')))]));
                      if(ok==true&&reason.text.trim().isNotEmpty){
                        await db.rejectDocument(documentId:doc['id'] as int,userId:1,reason:reason.text);
                        await refresh(); if(ctx.mounted)Navigator.pop(ctx);
                      }
                    }),
                  ]),
                ));
              })),
          ]),
        )))),
    );
  }
}
