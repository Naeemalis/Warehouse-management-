import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:srag_printer/srag_printer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'data/wms_database.dart';
import 'auth_gate.dart';
import 'access_admin_screen.dart';
import 'data/master_data_import.dart';
import 'data/master_data_transfer.dart';
import 'domain/unit_conversion.dart';

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
    home: AuthGate(
      language: locale.languageCode,
      onLanguage: (v) => setState(() => locale = Locale(v)),
      homeBuilder: (user, onLogout) => WarehouseHome(
        language: locale.languageCode,
        onLanguage: (v) => setState(() => locale = Locale(v)),
        currentUser: user,
        onLogout: onLogout,
      ),
    ),
  );
}

class WarehouseHome extends StatefulWidget {
  const WarehouseHome({super.key, required this.language, required this.onLanguage, required this.currentUser, required this.onLogout});
  final String language;
  final ValueChanged<String> onLanguage;
  final Map<String,Object?> currentUser;
  final VoidCallback onLogout;
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
      'stock':'الرصيد بوحدة الأساس','empty':'لا توجد منتجات بعد','name':'اسم المنتج','supplierName':'اسم المورد','customerName':'اسم العميل',
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
      'stock':'Base-unit balance','empty':'No products yet','name':'Product name','supplierName':'Supplier name','customerName':'Customer name',
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
      'stock':'Solde en unité de base','empty':'Aucun produit','name':'Nom du produit','supplierName':'Nom du fournisseur','customerName':'Nom du client',
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
  Color productStatusColor(Map<String,Object?> product) {
    final stock=(product['stock_base'] as num?)?.toDouble() ?? 0;
    final expiry=DateTime.tryParse(product['nearest_expiry_date']?.toString() ?? '');
    final today=DateTime.now();
    final todayDate=DateTime(today.year,today.month,today.day);
    if(expiry!=null && !expiry.isAfter(todayDate)) return Colors.red.shade900;
    if(expiry!=null && expiry.difference(todayDate).inDays<=30) return Colors.deepOrange;
    if(stock<=0) return Colors.red;
    final lastActivity=DateTime.tryParse(product['last_activity_at']?.toString() ?? '');
    if(lastActivity!=null && todayDate.difference(DateTime(lastActivity.year,lastActivity.month,lastActivity.day)).inDays>=30) return Colors.deepPurple;
    return Colors.green;
  }

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
    textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t('title')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) {
              if(v=='returns') showReturns();
              else if(v=='docs') showDocuments();
              else if(v=='statement') showCustomerAccounts();
              else if(v=='supplierStatement') showSupplierAccounts();
              else if(v=='issues') showDocuments(kind:'issue',documentType:'standard');
              else if(v=='sales') showDocuments(kind:'issue',documentType:'sale');
              else if(v=='parties') manageParties();
              else if(v=='deliveries') showDeliveries();
              else if(v=='approvals') showApprovals();
              else if(v=='admin') showAccessAdmin();
              else if(v=='company') showCompanyProfile();
              else if(v=='logout') widget.onLogout();
              else if(v=='ar'||v=='en'||v=='fr') widget.onLanguage(v);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value:'returns',child:Text(tr3('المرتجعات','Returns','Retours'))),
              PopupMenuItem(value:'docs',child:Text(tr3('الفواتير','Invoices','Factures'))),
              PopupMenuItem(value:'statement',child:Text(tr3('كشف حساب عميل والدفعات','Customer statement & payments','Relevé client et paiements'))),
              PopupMenuItem(value:'supplierStatement',child:Text(tr3('كشف حساب المورد والدفعات','Supplier statement & payments','Relevé fournisseur et paiements'))),
              PopupMenuItem(value:'issues',child:Text(tr3('سجل الصرف','Issue register','Registre des sorties'))),
              PopupMenuItem(value:'sales',child:Text(tr3('سجل المبيعات','Sales register','Registre des ventes'))),
              PopupMenuItem(value:'parties',child:Text(tr3('الموردون والعملاء','Suppliers and customers','Fournisseurs et clients'))),
              PopupMenuItem(value:'deliveries',child:Text(tr3('التسليمات','Deliveries','Livraisons'))),
              PopupMenuItem(value:'approvals',child:Text(t('approvals'))),
              PopupMenuItem(value:'admin',child:Text(tr3('المستخدمون والأقسام والصلاحيات','Users, Departments & Permissions','Utilisateurs, services et autorisations'))),
              PopupMenuItem(value:'company',child:Text(tr3('بيانات المؤسسة','Organization profile','Profil de l’organisation'))),
              PopupMenuItem(value:'logout',child:Text(tr3('تسجيل الخروج','Sign out','Déconnexion'))),
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
                  const SizedBox(width:8),
                  Expanded(child: _action(tr3('مبيعات','Sales','Ventes'), Icons.point_of_sale, () => _openSalesCashier())),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16,14,16,8),
                child: Row(children: [
                  Expanded(child: Text(t('gallery'), style: Theme.of(context).textTheme.titleLarge)),
                  PopupMenuButton<String>(
  tooltip:tr3('استيراد وتصدير الأصناف','Import / export products','Importer / exporter les produits'),
  onSelected:(v){if(v=='import')importMasterData('products');if(v=='xlsx')exportMasterData('products');if(v=='csv')exportMasterData('products',csv:true);},
  itemBuilder:(_)=>[
    PopupMenuItem(value:'import',child:Text(tr3('استيراد ملف','Import file','Importer un fichier'))),
    PopupMenuItem(value:'xlsx',child:Text(tr3('تصدير Excel','Export Excel','Exporter Excel'))),
    PopupMenuItem(value:'csv',child:Text(tr3('تصدير CSV','Export CSV','Exporter CSV'))),
  ],
),
FilledButton.tonalIcon(onPressed: addProduct, icon: const Icon(Icons.add), label: Text(t('add'))),
                ]),
              ),
              Expanded(child: products.isEmpty
                ? ListView(children: [const SizedBox(height:90), Icon(Icons.inventory_2_outlined,size:68,color:Theme.of(context).colorScheme.primary), const SizedBox(height:12), Center(child:Text(t('empty')))])
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, mainAxisExtent: 112,
                      crossAxisSpacing: 6, mainAxisSpacing: 6),
                    itemCount: products.length,
                    itemBuilder: (context,index) {
                      final p = products[index];
                      return Card(child: Stack(children:[
                        Positioned.fill(child:InkWell(
                          borderRadius:BorderRadius.circular(12),
                          onTap:()=>openTransaction(false,selectedProduct:p),
                          onLongPress:()=>editProduct(p),
                          child:Padding(padding:const EdgeInsets.all(6),child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,children:[
                              Icon(Icons.inventory_2_outlined,size:22,color:productStatusColor(p)),const Spacer(),
                              Text('${p['name']}',maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)),
                              const SizedBox(height:2),
                              Text('${p['stock_base']} ${p['base_unit_name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.labelSmall?.copyWith(fontSize:9)),
                            ],
                          )),
                        )),
                        PositionedDirectional(top:0,end:0,child:PopupMenuButton<String>(
                          icon:const Icon(Icons.more_vert,size:16),padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:30,minHeight:30),
                          onSelected:(v) async {
                            if(v=='edit'){await editProduct(p);}
                            if(v=='history'){await showProductHistory(p);}
                            if(v=='archive'){
                              final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
                                title:Text(tr3('حذف الصنف من القائمة؟','Remove product?','Retirer le produit ?')),
                                content:Text(tr3('سيتم إخفاؤه من الأصناف النشطة مع الاحتفاظ بسجل الفواتير وحركات المخزون.','It will be hidden from active products while invoice and stock history are preserved.','Il sera masqué des produits actifs, en conservant l’historique.')),
                                actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('confirm')))]));
                              if(ok==true){await db.archiveProduct(p['id'] as int);await refresh();}
                            }
                          },
                          itemBuilder:(_)=>[
                            PopupMenuItem(value:'history',child:Text(tr3('كشف حركة وصلاحية الصنف','Stock & expiry history','Historique du stock et des dates'))),
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
    final baseSalePrice = TextEditingController();
    final supplySalePrice = TextEditingController();
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
          TextField(controller:baseSalePrice,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:tr3('سعر بيع وحدة الأساس','Base-unit sale price','Prix de vente de l’unité de base'))),
          const SizedBox(height:10),
          TextField(controller:supplySalePrice,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:tr3('سعر بيع وحدة التوريد','Supply-unit sale price','Prix de vente de l’unité d’approvisionnement'))),
          const SizedBox(height:10),
          TextField(controller:units, decoration:InputDecoration(labelText:tr3('وحدات التفرّع (من الأكبر إلى الأصغر)','Nested units (largest to smallest)','Unités imbriquées (de la plus grande à la plus petite)'),
            hintText:tr3('مثال: كرتون=12، باكت=12 (كل معامل نسبةً إلى الوحدة الأصغر التالية)','Example: Carton=12, Pack=12 (each factor is relative to the next smaller unit)','Exemple : Carton=12, Paquet=12 (facteur relatif à la plus petite unité suivante)')), maxLines:3),
          Align(alignment:AlignmentDirectional.centerStart, child:Text(t('baseNote'),style:Theme.of(ctx).textTheme.bodySmall)),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('save'))),
        ],
      )));
    if (result != true) return;
    if (name.text.trim().isEmpty || base.text.trim().isEmpty) { message(t('selectAll')); return; }
    final parsedBasePrice=double.tryParse(baseSalePrice.text.replaceAll(',','.'));
    final parsedSupplyPrice=double.tryParse(supplySalePrice.text.replaceAll(',','.'));
    if(parsedBasePrice==null||!parsedBasePrice.isFinite||parsedBasePrice<=0||
      parsedSupplyPrice==null||!parsedSupplyPrice.isFinite||parsedSupplyPrice<=0){
      message(tr3('أدخل سعراً صحيحاً لوحدة الأساس ووحدة التوريد','Enter valid base-unit and supply-unit sale prices','Saisissez des prix valides pour l’unité de base et l’unité d’approvisionnement'));return;
    }
    try {
      final unitRows=buildHierarchicalUnitDefinitions(
        baseUnitName:base.text.trim(), baseSalePrice:parsedBasePrice,
        supplySalePrice:parsedSupplyPrice, definitions:units.text);
      await db.saveProduct(name:name.text,baseUnit:base.text,trackingMode:mode,units:unitRows);
      await refresh(); message(t('created'));
    } catch (_) { message(t('badUnits')); }
  }

  Future<void> openTransaction(bool receiving,{Map<String,Object?>? selectedProduct}) async {
    if(receiving){await _openReceiptTransaction(receiving:receiving,selectedProduct:selectedProduct);}
    else{await _openIssueCashier(selectedProduct:selectedProduct);}
  }

  Future<void> _openSalesCashier({Map<String,Object?>? selectedProduct}) async {
    await _openIssueCashier(selectedProduct:selectedProduct,sales:true);
  }

  Future<void> _openIssueCashier({Map<String,Object?>? selectedProduct,bool sales=false}) async {
    final customers=await db.listParties('customers');
    final available=(await db.listProducts()).where((p)=>((p['stock_base'] as num?)?.toDouble()??0)>0).toList();
    if(!mounted)return;
    if(customers.isEmpty){
      final c=TextEditingController();
      final phone=TextEditingController();
      final address=TextEditingController();
      final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(
        title:Text(t('customer')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:c,decoration:InputDecoration(labelText:tr3('اسم العميل','Customer name','Nom du client'))),
          const SizedBox(height:8),
          TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:tr3('رقم الهاتف','Phone number','Numéro de téléphone'))),
          const SizedBox(height:8),
          TextField(controller:address,maxLines:2,decoration:InputDecoration(labelText:tr3('العنوان','Address','Adresse'))),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(x,true),child:Text(t('save')))]));
      if(ok==true&&c.text.trim().isNotEmpty){await db.saveParty(supplier:false,name:c.text.trim(),phone:phone.text,address:address.text);await _openIssueCashier(selectedProduct:selectedProduct,sales:sales);}
      return;
    }
    if(available.isEmpty){message(tr3('لا توجد أصناف لها رصيد متاح للصرف','No products have available stock','Aucun produit avec stock disponible'));return;}
    int? customerId=customers.first['id'] as int;
    int? productId;
    Map<String,Object?>? unit;
    List<Map<String,Object?>> units=[];
    final basket=<Map<String,Object?>>[];
    final productSearch=TextEditingController();
    List<Map<String,Object?>> visibleAvailable=List.of(available);
    String qty='';
    Future<void> selectProduct(Map<String,Object?> p,StateSetter setLocal) async {
      final loaded=await db.listUnits(p['id'] as int);
      setLocal(() { productId=p['id'] as int; units=loaded; unit=null; });
    }
    Map<String,Object?>? initial;
    if(selectedProduct!=null){
      for(final candidate in available){
        if(candidate['id']==selectedProduct['id']){initial=candidate;break;}
      }
    }
    if(initial!=null){productId=initial['id'] as int;units=await db.listUnits(productId!);}
    await showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>Dialog(
      insetPadding:const EdgeInsets.all(10),
      child:SafeArea(child:SizedBox(width:560,height:MediaQuery.of(ctx).size.height*.92,
        child:StatefulBuilder(builder:(ctx,setLocal)=>Padding(padding:const EdgeInsets.all(10),child:Column(children:[
          Row(children:[Expanded(child:Text(sales?tr3('كاشير المبيعات','Sales cashier','Caisse de vente'):tr3('كاشير الصرف','Issue cashier','Caisse de sortie'),style:Theme.of(ctx).textTheme.titleLarge)),
            IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),
          DropdownButtonFormField<int>(value:customerId,isExpanded:true,decoration:InputDecoration(labelText:t('customer')),
            items:customers.map((c)=>DropdownMenuItem(value:c['id'] as int,child:Text(c['name'].toString()))).toList(),
            onChanged:(v)=>setLocal(()=>customerId=v)),
          const SizedBox(height:6),
          Align(alignment:AlignmentDirectional.centerStart,child:Text(tr3('معرض الأصناف المتاحة','Available products','Produits disponibles'))),
          const SizedBox(height:4),
          TextField(
            controller:productSearch,
            textInputAction:TextInputAction.search,
            decoration:InputDecoration(
              isDense:true,
              prefixIcon:const Icon(Icons.search,size:18),
              labelText:tr3('بحث عن صنف بالاسم أو الرمز','Search products by name or code','Rechercher par nom ou code'),
              suffixIcon:productSearch.text.isEmpty?null:IconButton(
                icon:const Icon(Icons.close,size:18),
                tooltip:tr3('مسح البحث','Clear search','Effacer la recherche'),
                onPressed:()=>setLocal((){productSearch.clear();visibleAvailable=List.of(available);}),
              ),
            ),
            onChanged:(value){
              final query=value.trim().toLowerCase();
              setLocal((){
                visibleAvailable=query.isEmpty?List.of(available):available.where((p){
                  final name=(p['name']??'').toString().toLowerCase();
                  final code=(p['code']??'').toString().toLowerCase();
                  return name.contains(query)||code.contains(query);
                }).toList();
              });
            },
          ),
          Expanded(flex:5,child:visibleAvailable.isEmpty
            ?Center(child:Text(tr3('لا توجد أصناف مطابقة للبحث','No matching products','Aucun produit correspondant')))
            :GridView.builder(
            padding:const EdgeInsets.symmetric(vertical:4),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,mainAxisExtent:58,crossAxisSpacing:3,mainAxisSpacing:3),
            itemCount:visibleAvailable.length,itemBuilder:(ctx,i){
              final p=visibleAvailable[i];final active=productId==p['id'];
              return OutlinedButton(
                style:OutlinedButton.styleFrom(padding:const EdgeInsets.all(2),
                  backgroundColor:active?Theme.of(ctx).colorScheme.primaryContainer:null),
                onPressed:()=>selectProduct(p,setLocal),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  const Icon(Icons.inventory_2_outlined,size:12),
                  Text(p['name'].toString(),maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w600,height:1.0)),
                  Text((p['stock_base'] as num).toStringAsFixed(2)+' '+p['base_unit_name'].toString(),style:Theme.of(ctx).textTheme.labelSmall?.copyWith(fontSize:7),maxLines:1,overflow:TextOverflow.ellipsis),
                ]));
            })),
          const Divider(height:10),
          Row(children:[
            Text(tr3('الكمية','Quantity','Quantité')+': ',style:Theme.of(ctx).textTheme.titleSmall),
            Text(qty.isEmpty?'0':qty,style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
          ]),
          SizedBox(height:142,child:Row(children:[
            Expanded(flex:3,child:GridView.count(
              crossAxisCount:4,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
              mainAxisSpacing:4,crossAxisSpacing:4,childAspectRatio:1.5,
              children:['1','2','3','4','5','6','7','8','9','½','0','¼','⌫','.'].map((k)=>
                OutlinedButton(style:OutlinedButton.styleFrom(padding:EdgeInsets.zero),
                  onPressed:()=>setLocal((){
                    if(k=='⌫'){if(qty.isNotEmpty)qty=qty.substring(0,qty.length-1);}
                    else if(k=='½'){qty='0.5';}
                    else if(k=='¼'){qty='0.25';}
                    else if(k=='.'){if(!qty.contains('.'))qty+='.';}
                    else{qty+=k;}
                  }),child:Text(k,style:const TextStyle(fontWeight:FontWeight.w600)))).toList(),
            )),
            const VerticalDivider(width:10),
            Expanded(flex:2,child:units.isEmpty
              ?Center(child:Text(tr3('اختر صنفاً','Select product','Choisir un produit'),textAlign:TextAlign.center))
              :GridView.builder(
                gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:2,mainAxisExtent:58,crossAxisSpacing:4,mainAxisSpacing:4),
                itemCount:units.length,
                itemBuilder:(ctx,i){
                  final u=units[i];final active=unit?['id']==u['id'];
                  final price=((u['sale_price_minor'] as num?)?.toDouble()??0)/100;
                  return OutlinedButton(
                    style:OutlinedButton.styleFrom(
                      padding:const EdgeInsets.all(3),
                      backgroundColor:active?Theme.of(ctx).colorScheme.secondaryContainer:null),
                    onPressed:()=>setLocal(()=>unit=u),
                    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Text(u['unit_name'].toString(),maxLines:1,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                      Text(price.toStringAsFixed(2),style:Theme.of(ctx).textTheme.labelSmall),
                    ]));
                })),
          ])),
          const SizedBox(height:5),
          SizedBox(width:double.infinity,child:FilledButton.icon(
            onPressed:productId==null||unit==null?null:(){
              final n=double.tryParse(qty.replaceAll(',','.'))??0;
              if(n<=0){message(tr3('أدخل كمية صحيحة','Enter a valid quantity','Saisissez une quantité valide'));return;}
              final p=available.firstWhere((p)=>p['id']==productId);final u=unit!;
              basket.add({'product_id':productId,'product_name':p['name'],'unit_name':u['unit_name'],
                'factor_to_base':u['factor_to_base'],'quantity':n,'unit_price_minor':u['sale_price_minor']??0});
              qty='';unit=null;setLocal((){});
            },icon:const Icon(Icons.add_shopping_cart),label:Text(t('addCart')))),
          const Divider(height:10),
          Align(alignment:AlignmentDirectional.centerStart,child:Text(t('cart')+' ('+basket.length.toString()+')')),
          Expanded(flex:2,child:ListView.builder(itemCount:basket.length,itemBuilder:(ctx,i){
            final l=basket[i];final total=(l['quantity'] as num)*(l['unit_price_minor'] as num)/100;
            return ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text(l['product_name'].toString()),
              subtitle:Text(l['quantity'].toString()+' × '+l['unit_name'].toString()),
              trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(total.toStringAsFixed(2)),
                IconButton(icon:const Icon(Icons.close),onPressed:()=>setLocal(()=>basket.removeAt(i)))]));
          })),
          SizedBox(width:double.infinity,child:FilledButton(onPressed:basket.isEmpty?null:()async{
            try{
              final customer=customers.firstWhere((c)=>c['id']==customerId);
              final id=await db.createDocument(kind:'issue',documentType:sales?'sale':'standard',partyType:'customer',partyId:customerId!,
                partyName:customer['name'] as String,createdBy:1,lines:basket.map((e)=>Map<String,Object?>.from(e)).toList());
              await db.submitDocument(documentId:id,userId:1);
              if(ctx.mounted)Navigator.pop(ctx);await refresh();message(t('sent'));
            }catch(e){message(e.toString());}
          },child:Text(t('submit')))),
        ]))))),
    ));
  }

  Future<void> _openReceiptTransaction({required bool receiving,Map<String,Object?>? selectedProduct}) async {
    final partyTable=receiving?'suppliers':'customers';
    final partyRows=await db.listParties(partyTable);
    var productRows=await db.listProducts();
    if (!mounted) return;
    if (partyRows.isEmpty) {
      final controller=TextEditingController();
      final created=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text(receiving?t('supplier'):t('customer')),
        content:TextField(controller:controller,decoration:InputDecoration(labelText:t(receiving?'supplierName':'customerName'))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(t('save')))]));
      if (created==true && controller.text.trim().isNotEmpty) {
        await db.saveParty(supplier:receiving,name:controller.text);
        await openTransaction(receiving,selectedProduct:selectedProduct);
      }
      return;
    }
    if (productRows.isEmpty) { await addProduct(); productRows=await db.listProducts(); if(productRows.isEmpty)return; }
    int? partyId=partyRows.first['id'] as int;
    int? productId=selectedProduct?['id'] as int? ?? productRows.first['id'] as int;
    List<Map<String,Object?>> units=await db.listPurchaseUnits(productId);
    int? unitId=units.isEmpty?null:units.first['id'] as int;
    final quantity=TextEditingController();
    final price=TextEditingController();
    final productSearch=TextEditingController();
    List<Map<String,Object?>> visibleProductRows=List.of(productRows);
    final basket=<Map<String,Object?>>[];
    final expirySplits=<Map<String,Object?>>[];
    final expiryQty=TextEditingController(text:'1');

    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(
      title:Text(receiving?t('receive'):t('issue')),
      content:SizedBox(
        width:MediaQuery.of(ctx).size.width*.94,
        height:MediaQuery.of(ctx).size.height*.78,
        child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<int>(
          value:partyId,decoration:InputDecoration(labelText:receiving?t('supplier'):t('customer')),
          items:partyRows.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
          onChanged:(v)=>setLocal(()=>partyId=v)),
        const SizedBox(height:10),
        Align(
          alignment:AlignmentDirectional.centerStart,
          child:Text(tr3('معرض الأصناف','Product gallery','Catalogue des produits'),
            style:Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold))),
        const SizedBox(height:8),
        TextField(
          controller:productSearch,
          textInputAction:TextInputAction.search,
          decoration:InputDecoration(
            prefixIcon:const Icon(Icons.search),
            labelText:tr3('بحث عن صنف بالاسم أو الرمز','Search by product name or code','Rechercher par nom ou code'),
            suffixIcon:productSearch.text.isEmpty?null:IconButton(
              tooltip:tr3('مسح البحث','Clear search','Effacer la recherche'),
              icon:const Icon(Icons.close),
              onPressed:()=>setLocal((){productSearch.clear();visibleProductRows=List.of(productRows);}),
            ),
          ),
          onChanged:(value){
            final query=value.trim().toLowerCase();
            setLocal((){
              visibleProductRows=query.isEmpty?List.of(productRows):productRows.where((p){
                final name=(p['name']??'').toString().toLowerCase();
                final code=(p['code']??'').toString().toLowerCase();
                return name.contains(query)||code.contains(query);
              }).toList();
            });
          },
        ),
        const SizedBox(height:6),
        SizedBox(
          height:visibleProductRows.isEmpty?58:320,
          child:visibleProductRows.isEmpty
            ? Center(child:Text(productSearch.text.trim().isEmpty?t('empty'):tr3('لا توجد أصناف مطابقة للبحث','No matching products','Aucun produit correspondant')))
            : GridView.builder(
                gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:4,mainAxisExtent:58,crossAxisSpacing:3,mainAxisSpacing:3),
                itemCount:visibleProductRows.length,
                itemBuilder:(context,index){
                  final p=visibleProductRows[index];
                  final selected=p['id']==productId;
                  return Card(
                    color:selected?Theme.of(ctx).colorScheme.primaryContainer:null,
                    child:InkWell(
                      borderRadius:BorderRadius.circular(10),
                      onTap:() async {
                        final v=p['id'] as int;
                        final u=await db.listPurchaseUnits(v);
                        setLocal(() {
                          productId=v; units=u;
                          unitId=u.isEmpty?null:u.first['id'] as int;
                          quantity.clear(); price.clear(); expirySplits.clear();
                        });
                      },
                      child:Padding(padding:const EdgeInsets.all(3),child:Column(
                        mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          const Icon(Icons.inventory_2_outlined,size:12),
                          const SizedBox(height:2),
                          Text('${p['name']}',maxLines:2,textAlign:TextAlign.center,
                            overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8,fontWeight:FontWeight.w600,height:1.0)),
                          Text('${p['base_unit_name']}',maxLines:1,overflow:TextOverflow.ellipsis,
                            style:Theme.of(ctx).textTheme.labelSmall?.copyWith(fontSize:7)),
                        ]))),
                  );
                })),
        Align(
          alignment:AlignmentDirectional.centerStart,
          child:TextButton.icon(
            onPressed:() async {
              final previousIds=productRows.map((p)=>p['id']).toSet();
              await addProduct();
              final refreshed=await db.listProducts();
              final newlyCreated=refreshed.where((p)=>!previousIds.contains(p['id'])).toList();
              if(newlyCreated.isEmpty)return;
              newlyCreated.sort((a,b)=>(a['id'] as int).compareTo(b['id'] as int));
              final createdProduct=newlyCreated.last;
              final v=createdProduct['id'] as int;
              final u=await db.listPurchaseUnits(v);
              setLocal(() {
                productRows=refreshed;
                final query=productSearch.text.trim().toLowerCase();
                visibleProductRows=query.isEmpty?List.of(refreshed):refreshed.where((p){
                  final name=(p['name']??'').toString().toLowerCase();
                  final code=(p['code']??'').toString().toLowerCase();
                  return name.contains(query)||code.contains(query);
                }).toList();
                productId=v; units=u;
                unitId=u.isEmpty?null:u.first['id'] as int;
              });
            },
            icon:const Icon(Icons.add_circle_outline),
            label:Text(tr3('تعريف صنف جديد','Define new product','Définir un nouveau produit')))),
        if(productId!=null) ...[
          const SizedBox(height:6),
          DropdownButtonFormField<int>(
            value:units.any((u)=>u['id']==unitId)?unitId:null,
            decoration:InputDecoration(labelText:t('unit')),
            items:units.map((u)=>DropdownMenuItem(value:u['id'] as int,
              child:Text('${u['unit_name']}  (×${u['factor_to_base']})'))).toList(),
            onChanged:(v) { setLocal(() { unitId=v; expirySplits.clear(); }); }),
        ],
        const SizedBox(height:10),
        TextField(controller:quantity,readOnly:true,showCursor:true,decoration:InputDecoration(labelText:t('quantity'),hintText:'0')),
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
          Row(children:[
            Expanded(child:TextField(controller:expiryQty,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:InputDecoration(labelText:tr3('كمية تاريخ الصلاحية','Quantity for expiry date','Quantité pour date d’expiration')))),
            const SizedBox(width:8),
            FilledButton.tonalIcon(onPressed:() async {
              final picked=await showDatePicker(
                context:ctx,
                initialDate:DateTime.now().add(const Duration(days:365)),
                firstDate:DateTime(2000),lastDate:DateTime(2100),
              );
              if(picked==null)return;
              final splitQty=double.tryParse(expiryQty.text.replaceAll(',','.'))??0;
              final selectedUnit=units.firstWhere((u)=>u['id']==unitId);
              final splitFactor=(selectedUnit['factor_to_base'] as num).toDouble();
              if(splitQty<=0){message(tr3('أدخل كمية صحيحة','Enter a valid quantity','Saisissez une quantité valide'));return;}
              setLocal((){
                expirySplits.add({
                  'expiry_date':picked.toIso8601String().substring(0,10),
                  'quantity':splitQty,
                  'unit_name':selectedUnit['unit_name'],
                  'factor_to_base':splitFactor,
                });
                expiryQty.text='1';
              });
            },icon:const Icon(Icons.event),label:Text(tr3('إضافة صلاحية','Add expiry','Ajouter date')) ),
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
          final enteredPrice=double.tryParse(price.text.replaceAll(',','.'));
          if(receiving&&(enteredPrice==null||!enteredPrice.isFinite||enteredPrice<=0)){
            message(tr3('سعر الشراء إلزامي ويجب أن يكون أكبر من صفر','Purchase price is required and must be greater than zero','Le prix d’achat est obligatoire et doit être supérieur à zéro'));return;
          }
          final lineFactor=(unit['factor_to_base'] as num).toDouble();
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
            'expiry_splits':receiving?expirySplits.map((s)=>Map<String,Object?>.from(s)).toList():null,
            'quantity':q,'unit_price_minor':((double.tryParse(price.text.replaceAll(',','.'))??0)*100).round(),
          });
          quantity.clear();
          expirySplits.clear(); expiryQty.text='1';
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


  Future<void> showProductHistory(Map<String,Object?> product) async {
    final productId=product['id'] as int;
    final batches=await db.productBatchBalances(productId);
    final movements=await db.productMovementHistory(productId);
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('${tr3('كشف حركة وصلاحية','Stock and expiry history','Historique du stock et des dates')} — ${product['name']}'),
      content:SizedBox(width:520,height:520,child:ListView(
        children:[
          Text(tr3('الكميات حسب تاريخ الصلاحية','Quantities by expiry date','Quantités par date d’expiration'),
            style:Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height:8),
          if(batches.isEmpty) Text(tr3('لا توجد دفعات استلام معتمدة','No approved receipt batches','Aucun lot de réception approuvé')),
          ...batches.map((b){
            final received=(b['received_quantity'] as num).toDouble();
            final remaining=(b['remaining_quantity_base'] as num).toDouble();
            final receivedBase=(b['received_quantity_base'] as num).toDouble();
            final issued=receivedBase-remaining;
            final factor=(b['factor_to_base_snapshot'] as num).toDouble();
            final remainingInReceiptUnit=factor==0?0:remaining/factor;
            final issuedInReceiptUnit=factor==0?0:issued/factor;
            final expiry=b['expiry_date']?.toString()??tr3('غير محدد','Not recorded','Non renseignée');
            return Card(child:ListTile(
              title:Text('${tr3('الصلاحية','Expiry','Expiration')}: $expiry'),
              subtitle:Text('${tr3('المستلم','Received','Reçu')}: $received ${b['unit_name_snapshot']}  •  ${tr3('المصروف','Issued','Sorti')}: ${issuedInReceiptUnit.toStringAsFixed(3)} ${b['unit_name_snapshot']}  •  ${tr3('المتبقي','Remaining','Restant')}: ${remainingInReceiptUnit.toStringAsFixed(3)} ${b['unit_name_snapshot']}'),
              trailing:Text('${remaining.toStringAsFixed(2)} ${product['base_unit_name']}'),
            ));
          }),
          const Divider(height:24),
          Text(tr3('سجل الحركات','Movement ledger','Journal des mouvements'),style:Theme.of(ctx).textTheme.titleMedium),
          const SizedBox(height:8),
          if(movements.isEmpty) Text(tr3('لا توجد حركات بعد','No movements yet','Aucun mouvement')),
          ...movements.map((m){
            final incoming=m['direction']=='IN';
            final allocated=(m['allocated_quantity'] as num?)?.toDouble();
            final unit=m['allocated_unit']??m['unit_name_snapshot'];
            final qty=allocated??(m['entered_quantity'] as num).toDouble();
            return ListTile(
              dense:true,
              leading:Icon(incoming?Icons.south_west:Icons.north_east,
                color:incoming?Colors.green:Colors.deepOrange),
              title:Text('${incoming?tr3('استلام','Receipt','Réception'):tr3('صرف','Issue','Sortie')} • ${m['document_no']}'),
              subtitle:Text('${m['created_at']}\n$qty $unit • ${tr3('الصلاحية','Expiry','Expiration')}: ${m['expiry_date']??'—'}'),
              trailing:Text('${(m['allocated_base_quantity'] as num?)?.toStringAsFixed(2)??(m['quantity_base'] as num).toStringAsFixed(2)} ${product['base_unit_name']}'),
            );
          }),
        ],
      )),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('cancel')))],
    ));
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
        textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
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
            Row(children:[
              Expanded(child:OutlinedButton.icon(
                onPressed:() async {
                  await importMasterData(kind);
                  final refreshed=await db.listParties(kind);
                  setSheet(()=>rows=refreshed);
                },
                icon:const Icon(Icons.file_upload_outlined),
                label:Text(tr3('استيراد','Import','Importer')),
              )),
              const SizedBox(width:8),
              PopupMenuButton<String>(
                tooltip:tr3('تصدير البيانات','Export data','Exporter les données'),
                onSelected:(v)=>exportMasterData(kind,csv:v=='csv'),
                itemBuilder:(_)=>[
                  PopupMenuItem(value:'xlsx',child:Text(tr3('تصدير Excel','Export Excel','Exporter Excel'))),
                  PopupMenuItem(value:'csv',child:Text(tr3('تصدير CSV','Export CSV','Exporter CSV'))),
                ],
                icon:const Icon(Icons.file_download_outlined),
              ),
            ]),
            const SizedBox(height:8),
            Expanded(child:rows.isEmpty?Center(child:Text(tr3('لا توجد بيانات','No records','Aucune donnée'))):ListView(
              children:rows.map((p)=>ListTile(
                leading:const Icon(Icons.person_outline),
                title:Text('${p['name']}'),
                subtitle:Text([p['phone'],p['address']].where((v)=>v!=null&&v.toString().trim().isNotEmpty).join(' · ')),
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
                final address=TextEditingController();
                final notes=TextEditingController();
                final ok=await showDialog<bool>(context:ctx,builder:(d)=>AlertDialog(
                  title:Text(kind=='suppliers'?t('supplier'):t('customer')),
                  content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
                    TextField(controller:name,decoration:InputDecoration(labelText:kind=='suppliers'?tr3('اسم المورد / اسم المؤسسة','Supplier / company name','Fournisseur / nom de l’entreprise'):tr3('اسم العميل الكامل','Customer full name','Nom complet du client'))),
                    const SizedBox(height:8),
                    TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:tr3('رقم الهاتف','Phone number','Numéro de téléphone'))),
                    const SizedBox(height:8),
                    TextField(controller:address,maxLines:2,decoration:InputDecoration(labelText:tr3('العنوان','Address','Adresse'))),
                    const SizedBox(height:8),
                    TextField(controller:notes,maxLines:2,decoration:InputDecoration(labelText:tr3('ملاحظات (اختياري)','Notes (optional)','Notes (facultatif)'))),
                  ])),
                  actions:[
                    TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),
                    FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('save'))),
                  ]));
                if(ok==true&&name.text.trim().isNotEmpty){
                  await db.saveParty(supplier:kind=='suppliers',name:name.text,phone:phone.text,address:address.text,notes:notes.text);
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


  Future<void> importMasterData(String kind) async {
    try {
      final picked=await MasterDataTransfer.pickImportFile();
      if(picked==null)return;
      final rows=MasterDataTransfer.readRows(picked.bytes,picked.name);
      if(rows.isEmpty){message(tr3('الملف لا يحتوي على سجلات','The file contains no records','Le fichier ne contient aucun enregistrement'));return;}
      final preview=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
        title:Text(tr3('معاينة الاستيراد','Import preview','Aperçu de l’importation')),
        content:SizedBox(width:420,height:260,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(tr3('عدد السجلات: '+rows.length.toString(),'Records: '+rows.length.toString(),'Enregistrements : '+rows.length.toString())),
          const SizedBox(height:8),
          Text(tr3('سيتم تحديث السجلات المطابقة وإضافة السجلات الجديدة. لن تتغير أرصدة الحسابات أو حركات المخزون.','Matching records will be updated and new records added. Account balances and stock movements will not change.','Les enregistrements correspondants seront mis à jour et les soldes et mouvements de stock resteront inchangés.'),style:Theme.of(d).textTheme.bodySmall),
          const Divider(),
          Expanded(child:ListView.builder(itemCount:rows.length<8?rows.length:8,itemBuilder:(_,i)=>ListTile(dense:true,leading:Text((i+1).toString()),title:Text(rows[i]['name']??rows[i]['code']??'—',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(rows[i]['phone']??rows[i]['base_unit_name']??'')))),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(tr3('اعتماد الاستيراد','Import','Importer')))],
      ));
      if(preview!=true)return;
      final result=kind=='products'?await db.importProducts(rows):await db.importParties(table:kind,rows:rows);
      if(kind=='products')await refresh();
      final inserted=result['inserted']??0,updated=result['updated']??0,skipped=result['skipped']??0;
      final errors=(result['errors'] as List?)??[];
      message(tr3('اكتمل الاستيراد: أضيف '+inserted.toString()+'، حُدّث '+updated.toString()+'، تم تخطي '+skipped.toString(),'Import complete: '+inserted.toString()+' added, '+updated.toString()+' updated, '+skipped.toString()+' skipped','Importation terminée : '+inserted.toString()+' ajoutés, '+updated.toString()+' mis à jour, '+skipped.toString()+' ignorés'));
      if(errors.isNotEmpty&&mounted){
        await showDialog<void>(context:context,builder:(d)=>AlertDialog(
          title:Text(tr3('ملاحظات الاستيراد','Import notes','Notes d’importation')),
          content:SizedBox(width:420,height:260,child:ListView(children:errors.take(40).map((e)=>Text(e.toString())).toList())),
          actions:[TextButton(onPressed:()=>Navigator.pop(d),child:Text(t('confirm')))],
        ));
      }
    }catch(e){message(tr3('تعذر استيراد الملف: '+e.toString(),'Could not import file: '+e.toString(),'Impossible d’importer le fichier : '+e.toString()));}
  }

  Future<void> exportMasterData(String kind,{bool csv=false}) async {
    try{
      final headers=<String>[];
      final rows=<Map<String,String>>[];
      if(kind=='suppliers'||kind=='customers'){
        headers.addAll(['name','phone','address','notes']);
        final records=await db.listParties(kind);
        for(final r in records){rows.add({'name':(r['name']??'').toString(),'phone':(r['phone']??'').toString(),'address':(r['address']??'').toString(),'notes':(r['notes']??'').toString()});}
      }else{
        headers.addAll(['code','name','category','base_unit_name','tracking_mode','base_sale_price','supply_sale_price','unit_definitions']);
        final records=await db.listProducts();
        for(final p in records){
          final units=await db.listUnits(p['id'] as int);
          final baseName=p['base_unit_name'].toString();
          final base=units.where((u)=>u['unit_name']==baseName).toList();
          final purchase=units.where((u)=>(u['is_purchase_unit'] as num? ?? 0)==1).toList();
          final nested=units.where((u)=>u['unit_name']!=baseName).toList()..sort((a,b)=>(b['factor_to_base'] as num).compareTo(a['factor_to_base'] as num));
          final definitions=<String>[];
          for(var i=0;i<nested.length;i++){
            final current=(nested[i]['factor_to_base'] as num).toDouble();
            final next=i+1<nested.length?(nested[i+1]['factor_to_base'] as num).toDouble():1.0;
            definitions.add(nested[i]['unit_name'].toString()+'='+(current/next).toString());
          }
          rows.add({'code':(p['code']??'').toString(),'name':(p['name']??'').toString(),'category':(p['category']??'').toString(),'base_unit_name':baseName,'tracking_mode':(p['tracking_mode']??'count').toString(),'base_sale_price':base.isEmpty?'0':(((base.first['sale_price_minor'] as num?)??0)/100).toStringAsFixed(2),'supply_sale_price':purchase.isEmpty?'0':(((purchase.first['sale_price_minor'] as num?)??0)/100).toStringAsFixed(2),'unit_definitions':definitions.join(',')});
        }
      }
      final bytes=MasterDataTransfer.encodeRows(headers,rows,csv:csv);
      final ext=csv?'csv':'xlsx';
      await MasterDataTransfer.shareExport(bytes:bytes,filename:'naeemsoft-'+kind+'.'+ext,csv:csv);
    }catch(e){message(tr3('تعذر تصدير البيانات: '+e.toString(),'Could not export data: '+e.toString(),'Impossible d’exporter les données : '+e.toString()));}
  }

  Future<void> showDeliveries() async {
    final docs=await db.awaitingDeliveryDocuments();
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>Directionality(textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
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
      builder:(ctx)=>Directionality(textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
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
                  subtitle:Text(doc['document_type']=='sale'?tr3('مبيعات','Sales','Ventes'):doc['kind']=='receipt'?t('receipt')
                    :doc['kind']=='issue'?t('issue')
                    :doc['kind']=='return_in'?tr3('مرتجع عميل','Customer return','Retour client')
                    :tr3('مرتجع مورد','Supplier return','Retour fournisseur')),
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
    final address=TextEditingController(text:'${party['address']??''}');
    final notes=TextEditingController(text:'${party['notes']??''}');
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text(tr3('تعديل البيانات','Edit details','Modifier les informations')),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:InputDecoration(labelText:table=='suppliers'?tr3('اسم المورد / اسم المؤسسة','Supplier / company name','Fournisseur / nom de l’entreprise'):tr3('اسم العميل الكامل','Customer full name','Nom complet du client'))),
        const SizedBox(height:8),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:tr3('رقم الهاتف','Phone number','Numéro de téléphone'))),
        const SizedBox(height:8),
        TextField(controller:address,maxLines:2,decoration:InputDecoration(labelText:tr3('العنوان','Address','Adresse'))),
        const SizedBox(height:8),
        TextField(controller:notes,maxLines:2,decoration:InputDecoration(labelText:tr3('ملاحظات (اختياري)','Notes (optional)','Notes (facultatif)'))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:Text(t('cancel'))),FilledButton(onPressed:()=>Navigator.pop(d,true),child:Text(t('save')))],
    ));
    if(ok==true){
      await db.updateParty(table:table,id:party['id'] as int,name:name.text,phone:phone.text,address:address.text,notes:notes.text);
      message(tr3('تم تحديث البيانات','Details updated','Informations mises à jour'));
    }
  }

  String money(Object? minor) => (((minor as num?)?.toDouble() ?? 0) / 100).toStringAsFixed(2);

  String pdfMoney(Object? minor) {
    final value = ((minor as num?)?.toDouble() ?? 0) / 100;
    return NumberFormat('#,##0.00', lang).format(value);
  }

  String pdfDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '';
    return DateFormat('yyyy-MM-dd HH:mm', lang).format(parsed);
  }

  pw.TextDirection get pdfTextDirection =>
      rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;


  pw.Widget companyPdfHeader(Map<String, String> profile) {
    final name = (profile['company_name'] ?? '').trim();
    final details = <String>[
      profile['company_phone'] ?? '',
      profile['company_email'] ?? '',
      [
        profile['company_country'] ?? '',
        profile['company_city'] ?? '',
        profile['company_area'] ?? '',
        profile['company_address'] ?? '',
      ].where((v) => v.trim().isNotEmpty).join(' - '),
      profile['company_website'] ?? '',
      profile['company_registration'] ?? '',
    ].where((v) => v.trim().isNotEmpty).toList();
    pw.MemoryImage? logo;
    final encoded = profile['company_logo_base64'] ?? '';
    if (encoded.isNotEmpty) {
      try { logo = pw.MemoryImage(base64Decode(encoded)); } catch (_) {}
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (logo != null)
          pw.Center(child: pw.Container(
            height: 58, width: 150,
            margin: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )),
        pw.Center(child: pw.Text(
          name.isEmpty ? 'NaeemSoft WMS' : name,
          style: pw.TextStyle(font: SragFonts.bold!, fontSize: 20),
        )),
        ...details.map((line) => pw.Center(child: pw.Text(
          line, style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ))),
        pw.SizedBox(height: 8),
      ],
    );
  }

  Future<Uint8List> buildDocumentPdf(int documentId) async {
    await SragFonts.load();
    final companyProfile=await db.companyProfile();
    final result = await db.documentDetails(documentId);
    final doc = result['document'] as Map<String, Object?>;
    final lines = result['lines'] as List<Map<String, Object?>>;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: SragFonts.regular!, bold: SragFonts.bold!),
    );
    final documentKind = doc['kind'];
    final isSupplierDocument = documentKind == 'receipt' || documentKind == 'return_out';
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Directionality(
          textDirection: pdfTextDirection,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              companyPdfHeader(companyProfile),
              pw.Center(child: pw.Text(
                documentKind == 'receipt'
                    ? tr3('سند استلام بضاعة', 'Goods Receipt', 'Bon de réception')
                    : documentKind == 'issue' && doc['document_type']=='sale'
                        ? tr3('فاتورة مبيعات', 'Sales Invoice', 'Facture de vente')
                        : documentKind == 'issue'
                        ? tr3('سند صرف بضاعة', 'Goods Issue', 'Bon de sortie')
                        : documentKind == 'return_in'
                            ? tr3('مرتجع عميل', 'Customer Return', 'Retour client')
                            : tr3('مرتجع مورد', 'Supplier Return', 'Retour fournisseur'),
                style: pw.TextStyle(font: SragFonts.bold!, fontSize: 16),
              )),
              pw.SizedBox(height: 10),
              pw.Text('${tr3('رقم السند', 'Document No.', 'N° du document')}: ${doc['document_no']}'),
              pw.Text('${tr3('التاريخ', 'Date', 'Date')}: ${pdfDate(doc['created_at'])}'),
              pw.Text('${isSupplierDocument ? tr3('المورد', 'Supplier', 'Fournisseur') : tr3('العميل / الجهة', 'Customer / Department', 'Client / Service')}: ${doc['party_name_snapshot'] ?? ''}'),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    tr3('الصنف', 'Product', 'Produit'),
                    tr3('الكمية', 'Quantity', 'Quantité'),
                    tr3('الوحدة', 'Unit', 'Unité'),
                    tr3('سعر الوحدة', 'Unit Price', 'Prix unitaire'),
                    tr3('الإجمالي', 'Total', 'Total'),
                  ].map((v) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(v, style: pw.TextStyle(font: SragFonts.bold!, fontSize: 9)),
                  )).toList()),
                  ...lines.map((line) => pw.TableRow(children: [
                    '${line['product_name_snapshot']}',
                    '${line['entered_quantity']}',
                    '${line['unit_name_snapshot']}',
                    pdfMoney(line['unit_price_minor']),
                    pdfMoney((line['entered_quantity'] as num) * (line['unit_price_minor'] as num)),
                  ].map((v) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
                  )).toList())),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(
                  '${tr3('الإجمالي', 'Grand Total', 'Total général')}: ${pdfMoney(doc['total_minor'])}',
                  style: pw.TextStyle(font: SragFonts.bold!, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }

  Future<Uint8List> buildStatementPdf({
    required bool supplier,
    required Map<String, Object?> statement,
  }) async {
    await SragFonts.load();
    final companyProfile=await db.companyProfile();
    final party = (supplier ? statement['supplier'] : statement['customer']) as Map<String, Object?>;
    final entries = statement['entries'] as List<Map<String, Object?>>;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: SragFonts.regular!, bold: SragFonts.bold!),
    );
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Directionality(
          textDirection: pdfTextDirection,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              companyPdfHeader(companyProfile),
              pw.Center(child: pw.Text(
                supplier
                    ? tr3('كشف حساب مورد', 'Supplier Statement', 'Relevé fournisseur')
                    : tr3('كشف حساب عميل', 'Customer Statement', 'Relevé client'),
                style: pw.TextStyle(font: SragFonts.bold!, fontSize: 16),
              )),
              pw.Text('${tr3('الطرف', 'Party', 'Tiers')}: ${party['name']}'),
              pw.Text('${tr3('تاريخ الطباعة', 'Print Date', 'Date d’impression')}: ${pdfDate(DateTime.now().toIso8601String())}'),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    tr3('المستند', 'Document', 'Document'),
                    tr3('التاريخ', 'Date', 'Date'),
                    tr3('مدين', 'Debit', 'Débit'),
                    tr3('دائن', 'Credit', 'Crédit'),
                    tr3('الرصيد', 'Balance', 'Solde'),
                  ].map((v) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(v, style: pw.TextStyle(font: SragFonts.bold!, fontSize: 8)),
                  )).toList()),
                  ...entries.map((e) => pw.TableRow(children: [
                    '${e['document_no']}',
                    pdfDate(e['entry_date']),
                    pdfMoney(e['debit_minor']),
                    pdfMoney(e['credit_minor']),
                    pdfMoney(e['balance_minor']),
                  ].map((v) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(v, style: const pw.TextStyle(fontSize: 8)),
                  )).toList())),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('${tr3('إجمالي الفواتير', 'Total Invoices', 'Total des factures')}: ${pdfMoney(statement['total_debit_minor'])}'),
              pw.Text('${tr3('إجمالي المرتجعات', 'Total Returns', 'Total des retours')}: ${pdfMoney(statement['total_returned_minor'])}'),
              pw.Text('${tr3('إجمالي الدفعات', 'Total Payments', 'Total des paiements')}: ${pdfMoney(statement['total_paid_minor'])}'),
              pw.Text(
                '${tr3('الرصيد النهائي', 'Final Balance', 'Solde final')}: ${pdfMoney(statement['balance_minor'])}',
                style: pw.TextStyle(font: SragFonts.bold!, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ));
    return pdf.save();
  }

  Future<void> shareDocumentPdf(int id) async {
    final bytes=await buildDocumentPdf(id);
    final result=await db.documentDetails(id);
    final doc=result['document'] as Map<String,Object?>;
    await Printing.sharePdf(bytes:bytes,filename:'${doc['document_no']}.pdf');
  }

  Future<void> printDocumentPdf(int id) async {
    final bytes=await buildDocumentPdf(id);
    final result=await db.documentDetails(id);
    final doc=result['document'] as Map<String,Object?>;
    await Printing.layoutPdf(name:'${doc['document_no']}.pdf',onLayout:(_)=>bytes);
  }

  Future<void> shareStatementPdf({required bool supplier,required Map<String,Object?> statement}) async {
    final bytes=await buildStatementPdf(supplier:supplier,statement:statement);
    final party=(supplier?statement['supplier']:statement['customer']) as Map<String,Object?>;
    await Printing.sharePdf(bytes:bytes,filename:'statement-${party['name']}.pdf');
  }

  Future<void> printStatementPdf({required bool supplier,required Map<String,Object?> statement}) async {
    final bytes=await buildStatementPdf(supplier:supplier,statement:statement);
    await Printing.layoutPdf(name:supplier?'supplier-statement.pdf':'customer-statement.pdf',onLayout:(_)=>bytes);
  }




  Future<void> showCompanyProfile() async {
    final profile = await db.companyProfile();
    final fields = <String, TextEditingController>{
      'company_name': TextEditingController(text: profile['company_name']),
      'company_phone': TextEditingController(text: profile['company_phone']),
      'company_email': TextEditingController(text: profile['company_email']),
      'company_country': TextEditingController(text: profile['company_country']),
      'company_city': TextEditingController(text: profile['company_city']),
      'company_area': TextEditingController(text: profile['company_area']),
      'company_address': TextEditingController(text: profile['company_address']),
      'company_website': TextEditingController(text: profile['company_website']),
      'company_registration': TextEditingController(text: profile['company_registration']),
    };
    String logoBase64 = profile['company_logo_base64'] ?? '';
    String? error;
    String label(String ar, String en, String fr) => tr3(ar, en, fr);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text(label('بيانات المؤسسة', 'Organization profile', 'Profil de l’organisation')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logoBase64.isNotEmpty)
                    Container(
                      height: 90, width: double.infinity,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Image.memory(base64Decode(logoBase64), fit: BoxFit.contain),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.business, size: 48),
                    ),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.image, allowMultiple: false, withData: true,
                        );
                        if (picked == null || picked.files.isEmpty) return;
                        final bytes = picked.files.single.bytes;
                        if (bytes == null || bytes.isEmpty) {
                          setLocal(() => error = label('تعذر قراءة الصورة المختارة','Could not read the selected image','Impossible de lire l’image sélectionnée'));
                          return;
                        }
                        if (bytes.length > 3 * 1024 * 1024) {
                          setLocal(() => error = label('حجم الشعار أكبر من 3 ميجابايت','Logo must be 3 MB or smaller','Le logo doit faire 3 Mo ou moins'));
                          return;
                        }
                        setLocal(() { logoBase64 = base64Encode(bytes); error = null; });
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(label('اختيار الشعار','Choose logo','Choisir le logo')),
                    )),
                    if (logoBase64.isNotEmpty)
                      IconButton(
                        tooltip: label('إزالة الشعار','Remove logo','Supprimer le logo'),
                        onPressed: () => setLocal(() => logoBase64 = ''),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: fields['company_name'], decoration: InputDecoration(
                    labelText: label('اسم المؤسسة الرسمي *','Official organization name *','Nom officiel de l’organisation *'),
                  )),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_phone'], keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: label('رقم الهاتف','Phone','Téléphone'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_email'], keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: label('البريد الإلكتروني','Email','E-mail'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_country'], decoration: InputDecoration(labelText: label('الدولة','Country','Pays'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_city'], decoration: InputDecoration(labelText: label('المدينة','City','Ville'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_area'], decoration: InputDecoration(labelText: label('المنطقة / الحي','Area / district','Zone / quartier'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_address'], maxLines: 2,
                    decoration: InputDecoration(labelText: label('العنوان التفصيلي','Detailed address','Adresse détaillée'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_website'], keyboardType: TextInputType.url,
                    decoration: InputDecoration(labelText: label('الموقع الإلكتروني','Website','Site web'))),
                  const SizedBox(height: 8),
                  TextField(controller: fields['company_registration'],
                    decoration: InputDecoration(labelText: label('رقم التسجيل (اختياري)','Registration number (optional)','Numéro d’enregistrement (facultatif)'))),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('cancel'))),
            FilledButton(
              onPressed: () {
                if ((fields['company_name']?.text.trim() ?? '').isEmpty) {
                  setLocal(() => error = label('اسم المؤسسة مطلوب','Organization name is required','Le nom de l’organisation est obligatoire'));
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(t('save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        final values = <String, String>{
          for (final entry in fields.entries) entry.key: entry.value.text.trim(),
          'company_logo_base64': logoBase64,
        };
        await db.saveCompanyProfile(values);
        message(label('تم حفظ بيانات المؤسسة','Organization profile saved','Profil de l’organisation enregistré'));
      } catch (e) {
        message(e.toString());
      }
    }
    for (final controller in fields.values) {
      controller.dispose();
    }
  }

  Future<void> showAccessAdmin() async {
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>AccessAdminScreen(language: lang)));
  }

  Future<void> showReturns() async {
    String returnKind='return_in';
    String sourceKind='issue';
    List<Map<String,Object?>> sourceDocs=(await db.listDocuments(kind:sourceKind))
        .where((d)=>d['status']=='approved').toList();
    int? selectedId=sourceDocs.isEmpty?null:sourceDocs.first['id'] as int;
    List<Map<String,Object?>> sourceLines=selectedId==null?[]:await db.returnableDocumentLines(selectedId);
    final quantities=<int,TextEditingController>{};
    for(final line in sourceLines){quantities[line['id'] as int]=TextEditingController();}
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Directionality(
        textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.84,
          child:Column(children:[
            Text(tr3('إنشاء مرتجع','Create a return','Créer un retour'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:10),
            DropdownButtonFormField<String>(
              value:returnKind,
              decoration:InputDecoration(labelText:tr3('نوع المرتجع','Return type','Type de retour')),
              items:[
                DropdownMenuItem(value:'return_in',child:Text(tr3('مرتجع عميل','Customer return','Retour client'))),
                DropdownMenuItem(value:'return_out',child:Text(tr3('مرتجع مورد','Supplier return','Retour fournisseur'))),
              ],
              onChanged:(v) async {
                if(v==null)return;
                final nextSource=v=='return_in'?'issue':'receipt';
                final found=(await db.listDocuments(kind:nextSource)).where((d)=>d['status']=='approved').toList();
                final nextId=found.isEmpty?null:found.first['id'] as int;
                final nextLines=nextId==null? <Map<String,Object?>>[] : await db.returnableDocumentLines(nextId);
                for(final c in quantities.values){c.dispose();}
                quantities.clear();
                for(final line in nextLines){quantities[line['id'] as int]=TextEditingController();}
                if(ctx.mounted)setSheet((){returnKind=v;sourceKind=nextSource;sourceDocs=found;selectedId=nextId;sourceLines=nextLines;});
              },
            ),
            const SizedBox(height:8),
            DropdownButtonFormField<int>(
              value:selectedId,
              isExpanded:true,
              decoration:InputDecoration(labelText:tr3('الفاتورة الأصلية المعتمدة','Approved original invoice','Facture originale approuvée')),
              items:sourceDocs.map((d)=>DropdownMenuItem<int>(
                value:d['id'] as int,
                child:Text(d['document_no'].toString()+' · '+(d['party_name_snapshot']??'').toString()),
              )).toList(),
              onChanged:(v) async {
                if(v==null)return;
                final found=await db.returnableDocumentLines(v);
                for(final c in quantities.values){c.dispose();}
                quantities.clear();
                for(final line in found){quantities[line['id'] as int]=TextEditingController();}
                if(ctx.mounted)setSheet((){selectedId=v;sourceLines=found;});
              },
            ),
            const SizedBox(height:8),
            Expanded(child:sourceDocs.isEmpty
              ?Center(child:Text(tr3('لا توجد فواتير معتمدة قابلة للمرتجع','No approved invoices available for return','Aucune facture approuvée disponible pour retour')))
              :sourceLines.isEmpty
                ?Center(child:Text(tr3('لا توجد كميات متبقية للمرتجع','No remaining quantities to return','Aucune quantité restante à retourner')))
                :ListView.separated(
                  itemCount:sourceLines.length,
                  separatorBuilder:(_,__)=>const Divider(height:1),
                  itemBuilder:(ctx,i){
                    final line=sourceLines[i];
                    final remaining=(line['remaining_base'] as num).toDouble()/
                      (line['factor_to_base_snapshot'] as num).toDouble();
                    return ListTile(
                      contentPadding:EdgeInsets.zero,
                      title:Text(line['product_name_snapshot'].toString()),
                      subtitle:Text(
                        tr3('المتبقي للمرتجع','Remaining returnable','Restant à retourner')+
                        ': '+remaining.toStringAsFixed(3)+' '+line['unit_name_snapshot'].toString(),
                      ),
                      trailing:SizedBox(width:104,child:TextField(
                        controller:quantities[line['id'] as int],
                        keyboardType:const TextInputType.numberWithOptions(decimal:true),
                        decoration:InputDecoration(
                          isDense:true,
                          labelText:tr3('الكمية','Quantity','Quantité'),
                          hintText:'0',
                        ),
                      )),
                    );
                  },
                )),
            const SizedBox(height:8),
            SizedBox(width:double.infinity,child:FilledButton.icon(
              onPressed:sourceDocs.isEmpty||selectedId==null?null:() async {
                final selected=<Map<String,Object?>>[];
                for(final line in sourceLines){
                  final controller=quantities[line['id'] as int];
                  final qty=double.tryParse(controller?.text.trim().replaceAll(',','.')??'')??0;
                  if(qty>0)selected.add({'source_line_id':line['id'],'quantity':qty});
                }
                if(selected.isEmpty){
                  message(tr3('أدخل كمية مرتجع واحدة على الأقل','Enter at least one return quantity','Saisissez au moins une quantité à retourner'));
                  return;
                }
                try{
                  final id=await db.createReturnDocument(
                    originalDocumentId:selectedId!,
                    kind:returnKind,
                    createdBy:1,
                    lines:selected,
                  );
                  await db.submitDocument(documentId:id,userId:1);
                  if(ctx.mounted)Navigator.pop(ctx);
                  await refresh();
                  message(tr3('تم إرسال المرتجع للموافقة','Return submitted for approval','Retour soumis pour approbation'));
                }catch(e){message(e.toString());}
              },
              icon:const Icon(Icons.assignment_return),
              label:Text(tr3('إرسال المرتجع للموافقة','Submit return for approval','Soumettre le retour pour approbation')),
            )),
          ]),
        )))),
      ),
    );
    for(final c in quantities.values){c.dispose();}
  }

  Future<void> showDocuments({String? kind,String? documentType}) async {
    final docs=await db.listDocuments(kind:kind,documentType:documentType);
    if(!mounted)return;
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>Directionality(textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.78,
          child:Column(children:[
            Text(documentType=='sale'?tr3('سجل المبيعات','Sales register','Registre des ventes'):kind=='issue'?tr3('سجل الصرف','Issue register','Registre des sorties'):tr3('الفواتير والمستندات','Invoices and documents','Factures et documents'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:10),
            Expanded(child:docs.isEmpty?Center(child:Text(tr3('لا توجد فواتير','No documents','Aucun document'))):ListView.builder(
              itemCount:docs.length,itemBuilder:(ctx,i){
                final d=docs[i];
                final kind=d['kind'];
                final kindLabel=d['document_type']=='sale'?tr3('مبيعات','Sale','Vente')
                  :kind=='receipt'?tr3('استلام','Receipt','Réception')
                  :kind=='issue'?tr3('صرف','Issue','Sortie')
                  :kind=='return_in'?tr3('مرتجع عميل','Customer return','Retour client')
                  :tr3('مرتجع مورد','Supplier return','Retour fournisseur');
                return Card(child:ListTile(
                  leading:Icon(d['document_type']=='sale'?Icons.point_of_sale:kind=='receipt'?Icons.move_to_inbox:kind=='issue'?Icons.outbox:Icons.assignment_return),
                  title:Text('${d['document_no']} · ${d['party_name_snapshot']??''}'),
                  subtitle:Text('${kindLabel} · ${d['status']} · ${money(d['total_minor'])}'),
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
          Text(doc['document_type']=='sale'?tr3('نوع المستند: مبيعات','Document type: Sale','Type de document : vente'):doc['kind']=='issue'?tr3('نوع المستند: صرف','Document type: Issue','Type de document : sortie'):doc['kind']=='receipt'?tr3('نوع المستند: استلام','Document type: Receipt','Type de document : réception'):tr3('نوع المستند: مرتجع','Document type: Return','Type de document : retour')),
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
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('cancel'))),
        IconButton(tooltip:tr3('طباعة','Print','Imprimer'),onPressed:()=>printDocumentPdf(id),icon:const Icon(Icons.print)),
        IconButton(tooltip:tr3('مشاركة PDF','Share PDF','Partager PDF'),onPressed:()=>shareDocumentPdf(id),icon:const Icon(Icons.share)),
      ],
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
        textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
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
              Row(children:[
                Expanded(child:Text('${tr3('المرتجعات','Returns','Retours')}: ${money(statement!['total_returned_minor'])}')),
              ]),
              const SizedBox(height:6),
              Text('${tr3('الرصيد المتبقي','Balance due','Solde restant')}: ${money(statement!['balance_minor'])}',style:Theme.of(ctx).textTheme.titleMedium),
              Text((statement!['balance_minor'] as num).toDouble()>=0
                ?tr3('حالة الحساب: العميل مدين','Account status: customer owes','Statut : le client est débiteur')
                :tr3('حالة الحساب: رصيد دائن للعميل','Account status: credit owed to customer','Statut : solde créditeur du client'),
                style:Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:() async { await recordCustomerPayment(selected!,ctx); final updated=await db.customerStatement(selected!); setSheet((){statement=updated;}); },
                icon:const Icon(Icons.payments_outlined),label:Text(tr3('تسجيل دفعة','Record payment','Enregistrer un paiement')),
              )),
              Row(children:[
                Expanded(child:OutlinedButton.icon(onPressed:()=>printStatementPdf(supplier:false,statement:statement!),icon:const Icon(Icons.print),label:Text(tr3('طباعة الكشف','Print statement','Imprimer')))),
                const SizedBox(width:8),
                Expanded(child:OutlinedButton.icon(onPressed:()=>shareStatementPdf(supplier:false,statement:statement!),icon:const Icon(Icons.share),label:Text(tr3('مشاركة PDF','Share PDF','Partager PDF')))),
              ]),
              const Divider(),
              Expanded(child:(statement!['entries'] as List<Map<String,Object?>>).isEmpty
                ?Center(child:Text(tr3('لا توجد حركات مالية','No account entries','Aucune opération')))
                :ListView.builder(itemCount:(statement!['entries'] as List).length,itemBuilder:(ctx,i){
                  final e=(statement!['entries'] as List<Map<String,Object?>>)[i];
                  final payment=e['entry_type']=='payment';
                  final isReturn=e['entry_type']=='return_in';
                  final credit=payment||isReturn;
                  final label=payment?tr3('دفعة','Payment','Paiement')
                    :(isReturn?tr3('مرتجع عميل','Customer return','Retour client'):(e['document_type']=='sale'?tr3('فاتورة مبيعات','Sales invoice','Facture de vente'):tr3('فاتورة صرف','Issue invoice','Facture de sortie')));
                  return ListTile(
                    dense:true,leading:Icon(credit?Icons.receipt_long:Icons.payments),
                    title:Text('${e['document_no']} · $label'),
                    subtitle:Text('${e['entry_date']} · ${e['status']}'),
                    trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
                      Text(credit?'+${money(e['credit_minor'])}':'-${money(e['debit_minor'])}'),
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


  Future<void> showSupplierAccounts() async {
    final suppliers=await db.listParties('suppliers');
    if(suppliers.isEmpty){message(tr3('أضف مورداً أولاً','Add a supplier first','Ajoutez d’abord un fournisseur'));return;}
    int? selected=suppliers.first['id'] as int;
    Map<String,Object?>? statement=await db.supplierStatement(selected);
    await showModalBottomSheet<void>(
      context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>Directionality(
        textDirection:rtl?ui.TextDirection.rtl:ui.TextDirection.ltr,
        child:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:SizedBox(
          height:MediaQuery.of(ctx).size.height*.82,
          child:Column(children:[
            Text(tr3('كشف حساب المورد','Supplier statement','Relevé du fournisseur'),style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:10),
            DropdownButtonFormField<int>(
              value:selected,decoration:InputDecoration(labelText:t('supplier')),
              items:suppliers.map((p)=>DropdownMenuItem(value:p['id'] as int,child:Text('${p['name']}'))).toList(),
              onChanged:(v) async {if(v==null)return;final s=await db.supplierStatement(v);setSheet((){selected=v;statement=s;});},
            ),
            if(statement!=null)...[
              const SizedBox(height:10),
              Row(children:[
                Expanded(child:Text('${tr3('إجمالي التوريد','Total receipts','Total des réceptions')}: ${money(statement!['total_debit_minor'])}')),
                Expanded(child:Text('${tr3('المدفوع','Paid','Payé')}: ${money(statement!['total_paid_minor'])}')),
              ]),
              Row(children:[
                Expanded(child:Text('${tr3('مرتجعات المورد','Supplier returns','Retours fournisseur')}: ${money(statement!['total_returned_minor'])}')),
              ]),
              const SizedBox(height:6),
              Text('${tr3('الرصيد المتبقي','Outstanding balance','Solde restant')}: ${money(statement!['balance_minor'])}',style:Theme.of(ctx).textTheme.titleMedium),
              Text((statement!['balance_minor'] as num).toDouble()>=0
                ?tr3('حالة الحساب: رصيد دائن للمورد (مستحق علينا)','Account status: payable to supplier','Statut : dette envers le fournisseur')
                :tr3('حالة الحساب: رصيد مدين للمورد','Account status: supplier owes us','Statut : le fournisseur nous doit'),
                style:Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height:8),
              SizedBox(width:double.infinity,child:FilledButton.icon(
                onPressed:() async {await recordSupplierPayment(selected!,ctx);final updated=await db.supplierStatement(selected!);setSheet((){statement=updated;});},
                icon:const Icon(Icons.payments_outlined),label:Text(tr3('تسجيل دفعة للمورد','Record supplier payment','Enregistrer un paiement fournisseur')),
              )),
              Row(children:[
                Expanded(child:OutlinedButton.icon(onPressed:()=>printStatementPdf(supplier:true,statement:statement!),icon:const Icon(Icons.print),label:Text(tr3('طباعة الكشف','Print statement','Imprimer')))),
                const SizedBox(width:8),
                Expanded(child:OutlinedButton.icon(onPressed:()=>shareStatementPdf(supplier:true,statement:statement!),icon:const Icon(Icons.share),label:Text(tr3('مشاركة PDF','Share PDF','Partager PDF')))),
              ]),
              const Divider(),
              Expanded(child:(statement!['entries'] as List<Map<String,Object?>>).isEmpty
                ?Center(child:Text(tr3('لا توجد حركات مالية','No account entries','Aucune opération')))
                :ListView.builder(itemCount:(statement!['entries'] as List).length,itemBuilder:(ctx,i){
                  final e=(statement!['entries'] as List<Map<String,Object?>>)[i];
                  final credit=(e['credit_minor'] as num).round()>0;
                  final isPayment=e['entry_type']=='payment';
                  final label=isPayment?tr3('دفعة للمورد','Payment to supplier','Paiement fournisseur')
                    :(e['entry_type']=='return_out'?tr3('مرتجع مورد','Supplier return','Retour fournisseur'):tr3('فاتورة توريد','Receipt invoice','Facture de réception'));
                  return ListTile(
                    dense:true,leading:Icon(credit?Icons.payments:Icons.receipt_long),
                    title:Text('${e['document_no']} · $label'),
                    subtitle:Text('${e['entry_date']} · ${e['status']}'),
                    trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
                      Text(credit?'-${money(e['credit_minor'])}':'+${money(e['debit_minor'])}'),
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

  Future<void> recordSupplierPayment(int supplierId, BuildContext sheetContext) async {
    final amount=TextEditingController();
    final reference=TextEditingController();
    final notes=TextEditingController();
    String method='cash';
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setLocal)=>AlertDialog(
      title:Text(tr3('تسجيل دفعة للمورد','Record supplier payment','Enregistrer un paiement fournisseur')),
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
      await db.addSupplierPayment(supplierId:supplierId,amountMinor:(value*100).round(),
        paymentDate:DateTime.now().toIso8601String(),method:method,
        referenceNo:reference.text,notes:notes.text);
      if(sheetContext.mounted){message(tr3('تم تسجيل الدفعة','Payment recorded','Paiement enregistré'));}
    }
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
