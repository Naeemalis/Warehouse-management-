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
  String tr3(String ar, String en, String fr) => lang=='ar' ? ar : (lang=='fr' ? fr : en);
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) {
              if(v=='docs') showDocuments();
              else if(v=='statement') showCustomerAccounts();
              else if(v=='issues') showDocuments(kind:'issue');
              else if(v=='parties') manageParties();
              else if(v=='deliveries') showDeliveries();
              else if(v=='approvals') showApprovals();
              else if(v=='ar'||v=='en'||v=='fr') widget.onLanguage(v);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value:'docs',child:Text(tr3('الفواتير','Invoices','Factures'))),
              PopupMenuItem(value:'statement',child:Text(tr3('كشف حساب عميل والدفعات','Customer statement & payments','Relevé client et paiements'))),
              PopupMenuItem(value:'issues',child:Text(tr3('سجل المنصرف','Issue register','Registre des sorties'))),
              PopupMenuItem(value:'parties',child:Text(tr3('الموردون والعملاء','Suppliers and customers','Fournisseurs et clients'))),
              PopupMenuItem(value:'deliveries',child:Text(tr3('التسليمات','Deliveries','Livraisons'))),
              PopupMenuItem(value:'approvals',child:Text(t('approvals'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value:'ar',child:Text('العربية')),
              const PopupMenuItem(value:'en',child:Text('English')),
              const PopupMenuItem(value:'fr',child:Text('Français')),
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
                      return Card(child: Stack(children:[
                        Positioned.fill(child:InkWell(
                          borderRadius:BorderRadius.circular(12),
                          onTap:()=>openTransaction(false,selectedProduct:p),
                          onLongPress:()=>editProduct(p),
                          child:Padding(padding:const EdgeInsets.all(12),child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,children:[
                              const Icon(Icons.inventory_2_outlined),const Spacer(),
                              Text('${p['name']}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w600)),
                              const SizedBox(height:4),
                              Text('${p['stock_base']} ${p['base_unit_name']}',style:Theme.of(context).textTheme.bodySmall),
                            ],
                          )),
                        )),
                        PositionedDirectional(top:0,end:0,child:PopupMenuButton<String>(
                          icon:const Icon(Icons.more_vert,size:19),
                          onSelected:(v) async {
                            if(v=='edit'){await editProduct(p);}
                            if(v=='archive'){
                              final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
                                title:Text(tr3('حذف الصنف من القائمة؟','Remove product?','Retirer le produit ?')),
                                content:Text(tr3('سيتم إخفاؤه من الأصناف النشطة مع الاحتفاظ بسجل الفواتير وحركات المخزون.','It will be hidden from active products while invoice and stock history are preserved.','Il sera masqué des produits actifs, en conservant l’historique.')),
                                actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('confirm')))]));
                              if(ok==true){await db.archiveProduct(p['id'] as int);await refresh();}
                            }
                          },
                          itemBuilder:(_)=>[
                            PopupMenuItem(value:'edit',child:Text(tr3('تعديل الصنف','Edit product','Modifier le produit'))),
                            PopupMenuItem(value:'archive',child:Text(tr3('حذف / أرشفة','Archive product','Archiver le produit'))),
                          ],
                        )),
                      ]));
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
    List<Map<String,Object?>> units=await db.listUnits(productId);
    int? unitId=units.isEmpty?null:units.first['id'] as int;
    final quantity=TextEditingController(text:'1');
    final price=TextEditingController(text:'0');
    final factor=TextEditingController(text: units.isEmpty ? '1' : '${units.first['factor_to_base']}');
    final packaging=TextEditingController();
    final basket=<Map<String,Object?>>[];
    final expirySplits=<Map<String,Object?>>[];
    final expiryQty=TextEditingController(text:'1');
    DateTime? selectedExpiry;
    Future<void> addExpirySplit() async {
      final picked=await showDatePicker(
        context:ctx,
        initialDate:selectedExpiry??DateTime.now().add(const Duration(days:365)),
        firstDate:DateTime(2000),lastDate:DateTime(2100),
      );
      if(picked==null)return;
      final q=double.tryParse(expiryQty.text.replaceAll(',','.'))??0;
      final f=double.tryParse(factor.text.replaceAll(',','.'))??0;
      if(q<=0||f<=0){message(tr3('أدخل كمية ومعامل تحويل صحيحين','Enter a valid quantity and conversion factor','Saisissez une quantité et un facteur valides'));return;}
      setLocal((){
        selectedExpiry=picked;
        expirySplits.add({
          'expiry_date':picked.toIso8601String().substring(0,10),
          'quantity':q,'unit_name':units.firstWhere((u)=>u['id']==unitId)['unit_name'],
          'factor_to_base':f,
        });
        expiryQty.text='1';
      });
    }
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
        TextField(controller:quantity,readOnly:true,showCursor:true,decoration:InputDecoration(labelText:t('quantity'))),
        const SizedBox(height:8),
        GridView.count(
          crossAxisCount:3,
          shrinkWrap:true,
          mainAxisSpacing:5,
          crossAxisSpacing:5,
          childAspectRatio:2.5,
          physics:const NeverScrollableScrollPhysics(),
          children:['1','2','3','4','5','6','7','8','9','.','0','⌫'].map((key)=>OutlinedButton(
            onPressed:(){
              setLocal((){
                if(key=='⌫'){
                  if(quantity.text.isNotEmpty) quantity.text=quantity.text.substring(0,quantity.text.length-1);
                } else if(key=='.'){
                  if(!quantity.text.contains('.') && !quantity.text.contains(',')) quantity.text += '.';
                } else {
                  quantity.text += key;
                }
              });
            },
            child:Text(key,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),
          )).toList(),
        ),
        if(receiving) ...[
          const SizedBox(height:10),
          TextField(controller:factor,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr3('معامل التحويل إلى وحدة الأساس','Conversion factor to base unit','Facteur de conversion vers l’unité de base'))),
          const SizedBox(height:8),
          TextField(controller:packaging,decoration:InputDecoration(labelText:tr3('تفاصيل التعبئة الفعلية','Actual packaging details','Détails réels de l’emballage'),hintText:tr3('مثال: 4 بواكت × 6 حبات','e.g. 4 packs × 6 pieces','ex. : 4 paquets × 6 pièces'))),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(controller:expiryQty,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:tr3('كمية تاريخ الصلاحية','Quantity for expiry date','Quantité pour date d’expiration')))),
            const SizedBox(width:8),
            FilledButton.tonalIcon(onPressed:addExpirySplit,icon:const Icon(Icons.event),label:Text(tr3('إضافة صلاحية','Add expiry','Ajouter date'))),
          ]),
          if(expirySplits.isNotEmpty) ...[
            const SizedBox(height:6),
            Align(alignment:AlignmentDirectional.centerStart,child:Text(tr3('توزيع الكمية حسب الصلاحية','Quantity by expiry date','Quantité par date d’expiration'),style:const TextStyle(fontWeight:FontWeight.w600))),
            ...expirySplits.asMap().entries.map((entry)=>ListTile(
              dense:true,contentPadding:EdgeInsets.zero,
              title:Text('${entry.value['expiry_date']}'),
              subtitle:Text('${entry.value['quantity']} × ${entry.value['unit_name']}'),
              trailing:IconButton(icon:const Icon(Icons.close),onPressed:()=>setLocal(()=>expirySplits.removeAt(entry.key))),
            )),
            Text(tr3('يجب أن يساوي مجموع كميات الصلاحية كمية السطر.','Expiry quantities must equal the line quantity.','La somme des quantités doit égaler la quantité de la ligne.'),
              style:Theme.of(ctx).textTheme.bodySmall),
          ],
        ],
        const SizedBox(height:8),
        TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:receiving?tr3('سعر الشراء للوحدة','Purchase price per unit','Prix d’achat par unité'):tr3('سعر الصرف للوحدة','Issue price per unit','Prix de sortie par unité'))),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:(){
          if(productId==null||unitId==null)return;
          final product=productRows.firstWhere((p)=>p['id']==productId);
          final unit=units.firstWhere((u)=>u['id']==unitId);
          final q=double.tryParse(quantity.text.replaceAll(',','.'))??0;
          if(q<=0)return;
          final lineFactor=receiving?(double.tryParse(factor.text.replaceAll(',','.'))??0):(unit['factor_to_base'] as num).toDouble();
          if(receiving&&lineFactor<=0){message(t('badUnits'));return;}
          if(receiving&&expirySplits.isNotEmpty){
            final splitBase=expirySplits.fold<double>(0,(sum,s)=>
              sum+(s['quantity'] as num).toDouble()*(s['factor_to_base'] as num).toDouble());
            if((splitBase-q*lineFactor).abs()>0.000001){
              message(tr3('مجموع كميات الصلاحية لا يساوي كمية السطر','Expiry quantities do not equal line quantity','La somme des quantités ne correspond pas à la ligne'));
              return;
            }
          }
          basket.add({
            'product_id':productId,'product_name':product['name'],
            'unit_name':unit['unit_name'],'factor_to_base':lineFactor,
            'packaging_note':receiving?packaging.text:null,
            'expiry_splits':receiving?expirySplits.map((s)=>Map<String,Object?>.from(s)).toList():null,
            'quantity':q,'unit_price_minor':((double.tryParse(price.text)??0)*100).round(),
          });
          quantity.text='1';
          expirySplits.clear(); expiryQty.text='1'; selectedExpiry=null;
          setLocal((){});
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


  Future<void> editProduct(Map<String,Object?> product) async {
    final name=TextEditingController(text:'${product['name']}');
    final purchase=TextEditingController(text:'${((product['purchase_price_minor'] as num?)??0)/100}');
    final issue=TextEditingController(text:'${((product['issue_price_minor'] as num?)??0)/100}');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(tr3('تعديل المنتج','Edit product','Modifier le produit')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:InputDecoration(labelText:t('name'))),
        const SizedBox(height:8),
        TextField(controller:purchase,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr3('سعر الشراء','Purchase price','Prix d’achat'))),
        const SizedBox(height:8),
        TextField(controller:issue,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr3('سعر الصرف','Issue price','Prix de sortie'))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('save'))),
      ]));
    if(ok==true){
      try{
        await db.updateProduct(productId:product['id'] as int,name:name.text,
          purchasePriceMinor:((double.tryParse(purchase.text)??0)*100).round(),
          issuePriceMinor:((double.tryParse(issue.text)??0)*100).round());
        await refresh();
      }catch(e){message(e.toString());}
    }
  }

  Future<void> manageParties() async {
    String kind='suppliers';
    List<Map<String,Object?>> rows=await db.listParties(kind);
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Directionality(
        textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.7,
          child:Column(children:[
            Text(tr3('إدارة الموردين والعملاء','Manage suppliers and customers','Gérer les fournisseurs et les clients'),
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:12),
            SegmentedButton<String>(
              segments:[
                ButtonSegment(value:'suppliers',label:Text(t('supplier'))),
                ButtonSegment(value:'customers',label:Text(t('customer'))),
              ],
              selected:{kind},
              onSelectionChanged:(v) async {
                final k=v.first;
                final r=await db.listParties(k);
                setSheet(() { kind=k; rows=r; });
              },
            ),
            const SizedBox(height:8),
            Expanded(child:rows.isEmpty?Center(child:Text(tr3('لا توجد بيانات','No records','Aucune donnée'))):ListView(
              children:rows.map((p)=>ListTile(
                leading:const Icon(Icons.person_outline),
                title:Text('${p['name']}'),
                subtitle:Text('${p['phone']??''}'),
                trailing:PopupMenuButton<String>(
                  onSelected:(action) async {
                    if(action=='edit'){await editParty(kind,p);final refreshed=await db.listParties(kind);setSheet(()=>rows=refreshed);}
                    if(action=='archive'){
                      final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
                        title:Text(tr3('إيقاف هذا السجل؟','Archive this record?','Archiver cet enregistrement ?')),
                        content:Text(tr3('سيختفي من قوائم الاختيار مع بقاء الفواتير السابقة.','It will be hidden from selectors while historical documents remain.','Il sera masqué des listes, sans supprimer l’historique.')),
                        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('confirm')))]));
                      if(ok==true){await db.archiveParty(table:kind,id:p['id'] as int); final r=await db.listParties(kind);setSheet(()=>rows=r);}
                    }
                  },
                  itemBuilder:(_)=>[
                    PopupMenuItem(value:'edit',child:Text(tr3('تعديل الاسم','Edit name','Modifier le nom'))),
                    PopupMenuItem(value:'archive',child:Text(tr3('حذف / إيقاف','Archive','Archiver'))),
                  ],
                ),
              )).toList())),
            FilledButton.icon(
              onPressed:() async {
                final name=TextEditingController();
                final phone=TextEditingController();
                final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
                  title:Text(kind=='suppliers'?t('supplier'):t('customer')),
                  content:Column(mainAxisSize:MainAxisSize.min,children:[
                    TextField(controller:name,decoration:InputDecoration(labelText:t('name'))),
                    const SizedBox(height:8),
                    TextField(controller:phone,decoration:InputDecoration(labelText:tr3('الهاتف','Phone','Téléphone'))),
                  ]),
                  actions:[
                    TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),
                    FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('save'))),
                  ]));
                if(ok==true&&name.text.trim().isNotEmpty){
                  await db.saveParty(supplier:kind=='suppliers',name:name.text,phone:phone.text);
                  final r=await db.listParties(kind);
                  setSheet(() { rows=r; });
                }
              },
              icon:const Icon(Icons.add),label:Text(lang=='ar'?'إضافة':'Add')),
          ]),
        ))),
      )),
    );
  }

  Future<void> showDeliveries() async {
    final docs=await db.awaitingDeliveryDocuments();
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>Directionality(textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.65,
          child:Column(children:[
            Text(tr3('طلبات صرف معتمدة بانتظار التسليم','Approved issues awaiting delivery','Sorties approuvées en attente de livraison'),
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:12),
            Expanded(child:docs.isEmpty
              ?Center(child:Text(tr3('لا توجد تسليمات معلقة','No pending deliveries','Aucune livraison en attente')))
              :ListView.builder(itemCount:docs.length,itemBuilder:(ctx,i){
                final doc=docs[i];
                return Card(child:ListTile(
                  title:Text('${doc['document_no']} · ${doc['party_name_snapshot']}'),
                  subtitle:Text(tr3('معتمد — لم يؤكد التسليم','Approved — delivery not confirmed','Approuvé — livraison non confirmée')),
                  trailing:FilledButton.tonal(
                    onPressed:() async {
                      final recipient=TextEditingController(text:'${doc['party_name_snapshot']}');
                      final note=TextEditingController();
                      final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
                        title:Text(tr3('تأكيد التسليم الفعلي','Confirm physical delivery','Confirmer la livraison physique')),
                        content:Column(mainAxisSize:MainAxisSize.min,children:[
                          TextField(controller:recipient,decoration:InputDecoration(labelText:tr3('اسم المستلم','Recipient name','Nom du destinataire'))),
                          const SizedBox(height:8),
                          TextField(controller:note,decoration:InputDecoration(labelText:tr3('ملاحظة / إثبات التوقيع','Delivery note / signature record','Note de livraison / preuve de signature'))),
                        ]),
                        actions:[
                          TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),
                          FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('confirm'))),
                        ]));
                      if(ok==true&&recipient.text.trim().isNotEmpty){
                        await db.confirmDelivery(documentId:doc['id'] as int,userId:1,
                          recipientName:recipient.text.trim(),signatureNote:note.text.trim());
                        await refresh();
                        if(ctx.mounted)Navigator.pop(ctx);
                        message(tr3('تم تسجيل التسليم','Delivery recorded','Livraison enregistrée'));
                      }
                    },
                    child:Text(tr3('تأكيد التسليم','Confirm delivery','Confirmer la livraison')),
                  ),
                ));
              })),
          ]),
        )))),
    );
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

  Future<void> editParty(String table, Map<String,Object?> party) async {
    final name=TextEditingController(text:'${party['name']}');
    final phone=TextEditingController(text:'${party['phone']??''}');
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text(tr3('تعديل البيانات','Edit details','Modifier les informations')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:InputDecoration(labelText:t('name'))),
        const SizedBox(height:8),
        TextField(controller:phone,decoration:InputDecoration(labelText:tr3('الهاتف','Phone','Téléphone'))),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('save')))],
    ));
    if(ok==true){
      await db.updateParty(table:table,id:party['id'] as int,name:name.text,phone:phone.text);
      message(tr3('تم تحديث البيانات','Details updated','Informations mises à jour'));
    }
  }

  String money(Object? minor) => ((minor as num?)?.toDouble() ?? 0).toStringAsFixed(2);

  Future<void> showDocuments({String? kind}) async {
    final docs=await db.listDocuments(kind:kind);
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>Directionality(textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.78,
          child:Column(children:[
            Text(kind=='issue'?tr3('سجل المنصرف','Issue register','Registre des sorties'):tr3('الفواتير والمستندات','Invoices and documents','Factures et documents'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:10),
            Expanded(child:docs.isEmpty?Center(child:Text(tr3('لا توجد فواتير','No documents','Aucun document'))):ListView.builder(
              itemCount:docs.length,itemBuilder:(ctx,i){
                final d=docs[i];
                final isReceipt=d['kind']=='receipt';
                return Card(child:ListTile(
                  leading:Icon(isReceipt?Icons.move_to_inbox:Icons.outbox),
                  title:Text('${d['document_no']} · ${d['party_name_snapshot']??''}'),
                  subtitle:Text('${isReceipt?tr3('استلام','Receipt','Réception'):tr3('صرف','Issue','Sortie')} · ${d['status']} · ${money(d['total_minor'])}'),
                  trailing:const Icon(Icons.chevron_right),
                  onTap:()=>showDocumentDetails(d['id'] as int),
                ));
              })),
          ]),
        )))),
    );
  }

  Future<void> showDocumentDetails(int id) async {
    final result=await db.documentDetails(id);
    final doc=result['document'] as Map<String,Object?>;
    final lines=result['lines'] as List<Map<String,Object?>>;
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('${doc['document_no']}'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
          Text('${doc['party_name_snapshot']??''}'),
          Text('${doc['status']} · ${doc['created_at']}'),
          const Divider(),
          ...lines.map((l)=>ListTile(
            contentPadding:EdgeInsets.zero,dense:true,
            title:Text('${l['product_name_snapshot']}'),
            subtitle:Text('${l['entered_quantity']} × ${l['unit_name_snapshot']}'),
            trailing:Text(money((l['entered_quantity'] as num)* (l['unit_price_minor'] as num))),
          )),
          const Divider(),
          Text('${tr3('الإجمالي','Total','Total')}: ${money(doc['total_minor'])}',style:const TextStyle(fontWeight:FontWeight.bold)),
        ],
      ))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('cancel')))],
    ));
  }

  Future<void> showCustomerAccounts() async {
    final customers=await db.listParties('customers');
    if(customers.isEmpty){message(tr3('أضف عميلاً أولاً','Add a customer first','Ajoutez d’abord un client'));return;}
    int? selected=customers.first['id'] as int;
    Map<String,Object?>? statement=await db.customerStatement(selected);
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Directionality(
        textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.82,
          child:Column(children:[
            Text(tr3('كشف حساب العميل','Customer statement','Relevé du client'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:10),
            DropdownButtonFormField<int>(
              value:selected,decoration:InputDecoration(labelText:t('customer')),
              items:customers.map((c)=>DropdownMenuItem(value:c['id'] as int,child:Text('${c['name']}'))).toList(),
              onChanged:(v) async {if(v==null)return;final s=await db.customerStatement(v);setSheet((){selected=v;statement=s;});},
            ),
            if(statement!=null)...[
              const SizedBox(height:10),
              Row(children:[
                Expanded(child:Text('${tr3('إجمالي المستحق','Total issued','Total dû')}: ${money(statement!['total_debit_minor'])}')),
                Expanded(child:Text('${tr3('المدفوع','Paid','Payé')}: ${money(statement!['total_paid_minor'])}')),
              ]),
              const SizedBox(height:6),
              Text('${tr3('الرصيد المتبقي','Balance due','Solde restant')}: ${money(statement!['balance_minor'])}',style:Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:() async { await recordCustomerPayment(selected!,ctx); final updated=await db.customerStatement(selected!); setSheet((){statement=updated;}); },
                icon:const Icon(Icons.payments_outlined),label:Text(tr3('تسجيل دفعة','Record payment','Enregistrer un paiement')),
              )),
              const Divider(),
              Expanded(child:(statement!['entries'] as List<Map<String,Object?>>).isEmpty
                ?Center(child:Text(tr3('لا توجد حركات مالية','No account entries','Aucune opération')))
                :ListView.builder(itemCount:(statement!['entries'] as List).length,itemBuilder:(ctx,i){
                  final e=(statement!['entries'] as List<Map<String,Object?>>)[i];
                  final payment=e['entry_type']=='payment';
                  return ListTile(
                    dense:true,leading:Icon(payment?Icons.payments:Icons.receipt_long),
                    title:Text('${e['document_no']} · ${payment?tr3('دفعة','Payment','Paiement'):tr3('فاتورة صرف','Issue invoice','Facture de sortie')}'),
                    subtitle:Text('${e['entry_date']} · ${e['status']}'),
                    trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
                      Text(payment?'-${money(e['credit_minor'])}':'+${money(e['debit_minor'])}'),
                      Text('${tr3('الرصيد','Balance','Solde')}: ${money(e['balance_minor'])}',style:Theme.of(ctx).textTheme.bodySmall),
                    ]),
                  );
                })),
            ],
          ]),
        ))),
      )),
    );
  }

  Future<void> recordCustomerPayment(int customerId, BuildContext sheetContext) async {
    final amount=TextEditingController();
    final reference=TextEditingController();
    final notes=TextEditingController();
    String method='cash';
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setLocal)=>AlertDialog(
      title:Text(tr3('تسجيل دفعة من العميل','Record customer payment','Enregistrer un paiement client')),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr3('المبلغ','Amount','Montant'))),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(value:method,decoration:InputDecoration(labelText:tr3('طريقة الدفع','Payment method','Mode de paiement')),
          items:[DropdownMenuItem(value:'cash',child:Text(tr3('نقداً','Cash','Espèces'))),DropdownMenuItem(value:'bank',child:Text(tr3('تحويل بنكي','Bank transfer','Virement'))),DropdownMenuItem(value:'other',child:Text(tr3('أخرى','Other','Autre')))],
          onChanged:(v)=>setLocal(()=>method=v??'cash')),
        const SizedBox(height:8),
        TextField(controller:reference,decoration:InputDecoration(labelText:tr3('رقم المرجع','Reference','Référence'))),
        const SizedBox(height:8),
        TextField(controller:notes,decoration:InputDecoration(labelText:tr3('ملاحظات','Notes','Notes'))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('save')))],
    )));
    if(ok==true){
      final value=double.tryParse(amount.text.replaceAll(',','.'))??0;
      if(value<=0){message(tr3('أدخل مبلغاً صحيحاً','Enter a valid amount','Saisissez un montant valide'));return;}
      await db.addCustomerPayment(customerId:customerId,amountMinor:(value*100).round(),
        paymentDate:DateTime.now().toIso8601String(),method:method,
        referenceNo:reference.text,notes:notes.text);
      if(sheetContext.mounted){ message(tr3('تم تسجيل الدفعة','Payment recorded','Paiement enregistré')); }
    }
  }

}
