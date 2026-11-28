import 'package:flutter/material.dart';
import 'data/access_control.dart';
import 'data/market_analytics_database.dart';
import 'data/wms_database.dart';

class ProductMarketAnalyticsScreen extends StatefulWidget {
  const ProductMarketAnalyticsScreen({
    super.key,
    required this.language,
    required this.user,
  });

  final String language;
  final Map<String, Object?> user;

  @override
  State<ProductMarketAnalyticsScreen> createState() =>
      _ProductMarketAnalyticsScreenState();
}

class _ProductMarketAnalyticsScreenState
    extends State<ProductMarketAnalyticsScreen> {
  final WmsDatabase db = WmsDatabase.instance;
  bool loading = true;
  String? error;
  bool canManageCompetitors = false;
  bool canManageDemand = false;
  bool canManageDecisions = false;
  bool canViewConfidential = false;
  DateTime start = DateTime.now().subtract(const Duration(days: 29));
  DateTime end = DateTime.now();
  List<Map<String, Object?>> performance = [];
  List<Map<String, Object?>> competitors = [];
  List<Map<String, Object?>> demand = [];
  List<Map<String, Object?>> opportunities = [];
  List<Map<String, Object?>> areas = [];
  List<Map<String, Object?>> products = [];

  int get userId => (widget.user['id'] as num).toInt();
  bool get rtl => widget.language == 'ar';

  String tr(String ar, String en, String fr) =>
      widget.language == 'ar' ? ar : (widget.language == 'fr' ? fr : en);

  String dateText(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String money(Object? value) {
    if (value == null) return '—';
    return ((value as num).toDouble() / 100).toStringAsFixed(2);
  }

  String quantity(Object? value) =>
      value == null ? '0' : (value as num).toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final permissions = await Future.wait([
        db.userHasPermission(userId, 'market.analytics.view'),
        db.userHasPermission(userId, 'market.competitors.manage'),
        db.userHasPermission(userId, 'market.demand.manage'),
        db.userHasPermission(userId, 'market.decisions.manage'),
        db.userHasPermission(userId, 'competitor_confidential_view'),
      ]);
      if (!permissions[0]) {
        if (mounted) setState(() {
          loading = false;
          error = tr('ليس لديك إذن الاطلاع على تحليل السوق.',
            'You do not have permission to view market analytics.',
            'Vous n’avez pas l’autorisation de consulter l’analyse du marché.');
        });
        return;
      }
      final results = await Future.wait([
        db.productMarketPerformance(
          userId: userId, periodStart: dateText(start), periodEnd: dateText(end)),
        db.listCompetitors(userId: userId),
        db.listMarketDemandObservations(userId: userId),
        db.listUnfulfilledDemand(userId: userId),
        db.listGrowthOpportunities(userId: userId),
        db.listMarketAreas(userId: userId),
        db.listProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        canManageCompetitors = permissions[1];
        canManageDemand = permissions[2];
        canManageDecisions = permissions[3];
        canViewConfidential = permissions[4];
        performance = results[0] as List<Map<String, Object?>>;
        competitors = results[1] as List<Map<String, Object?>>;
        demand = results[2] as List<Map<String, Object?>>;
        opportunities = results[4] as List<Map<String, Object?>>;
        areas = results[5] as List<Map<String, Object?>>;
        products = results[6] as List<Map<String, Object?>>;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> choosePeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (picked == null) return;
    setState(() { start = picked.start; end = picked.end; });
    await refresh();
  }

  Future<void> addCompetitor() async {
    if (!canManageCompetitors) return;
    final name = TextEditingController();
    final phone = TextEditingController();
    final website = TextEditingController();
    String type = 'direct';
    bool confidential = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: Text(tr('إضافة منافس','Add competitor','Ajouter un concurrent')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: InputDecoration(labelText: tr('اسم المنافس','Competitor name','Nom du concurrent'))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: type,
            decoration: InputDecoration(labelText: tr('نوع المنافس','Competitor type','Type de concurrent')),
            items: [
              DropdownMenuItem(value:'direct',child:Text(tr('مباشر','Direct','Direct'))),
              DropdownMenuItem(value:'indirect',child:Text(tr('غير مباشر','Indirect','Indirect'))),
              DropdownMenuItem(value:'online',child:Text(tr('إلكتروني','Online','En ligne'))),
              DropdownMenuItem(value:'wholesale',child:Text(tr('جملة','Wholesale','Grossiste'))),
              DropdownMenuItem(value:'retail',child:Text(tr('تجزئة','Retail','Détail'))),
              DropdownMenuItem(value:'other',child:Text(tr('أخرى','Other','Autre'))),
            ],
            onChanged: (v) => setDialog(() => type = v ?? 'direct'),
          ),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('الهاتف (اختياري)','Phone (optional)','Téléphone (facultatif)'))),
          const SizedBox(height: 10),
          TextField(controller: website,
            decoration: InputDecoration(labelText: tr('الموقع (اختياري)','Website (optional)','Site web (facultatif)'))),
          if (canViewConfidential)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confidential,
              title: Text(tr('بيانات سرية','Confidential record','Donnée confidentielle')),
              onChanged: (v) => setDialog(() => confidential = v ?? false),
            ),
        ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel','Annuler'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('حفظ','Save','Enregistrer'))),
        ],
      )),
    );
    if (saved == true) {
      if (name.text.trim().isEmpty) {
        _message(tr('اسم المنافس مطلوب','Competitor name is required','Le nom du concurrent est obligatoire'));
      } else {
        try {
          await db.saveCompetitor(
            userId:userId,name:name.text,competitorType:type,
            phone:phone.text,website:website.text,isConfidential:confidential);
          await refresh();
        } catch (e) { _message(e.toString()); }
      }
    }
    name.dispose(); phone.dispose(); website.dispose();
  }

  Future<void> addCompetitorPrice() async {
    if (!canManageCompetitors || competitors.isEmpty || products.isEmpty) return;
    final externalName = TextEditingController();
    final price = TextEditingController();
    final quantity = TextEditingController(text:'1');
    final currency = TextEditingController(text:'DJF');
    int competitorId = (competitors.first['id'] as num).toInt();
    int productId = (products.first['id'] as num).toInt();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: Text(tr('تسجيل سعر منافس','Record competitor price','Enregistrer un prix concurrent')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            value:competitorId,
            decoration:InputDecoration(labelText:tr('المنافس','Competitor','Concurrent')),
            items:competitors.map((c)=>DropdownMenuItem(
              value:(c['id'] as num).toInt(),child:Text(c['name'].toString()))).toList(),
            onChanged:(v)=>setDialog(()=>competitorId=v??competitorId),
          ),
          const SizedBox(height:10),
          DropdownButtonFormField<int>(
            value:productId,
            decoration:InputDecoration(labelText:tr('الصنف المقارن في نظامنا','Matching internal product','Produit interne correspondant')),
            items:products.map((p)=>DropdownMenuItem(
              value:(p['id'] as num).toInt(),child:Text(p['name'].toString()))).toList(),
            onChanged:(v)=>setDialog(()=>productId=v??productId),
          ),
          const SizedBox(height:10),
          TextField(controller:externalName,decoration:InputDecoration(labelText:tr('اسم المنتج لدى المنافس','Competitor product name','Nom du produit concurrent'))),
          const SizedBox(height:10),
          TextField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr('السعر','Price','Prix'))),
          const SizedBox(height:10),
          TextField(controller:quantity,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:tr('الكمية التي يشملها السعر بوحدة الأساس','Quantity in internal base units','Quantité en unité de base interne'))),
          const SizedBox(height:10),
          TextField(controller:currency,decoration:InputDecoration(labelText:tr('رمز العملة','Currency code','Code devise'))),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel','Annuler'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('تسجيل السعر','Record price','Enregistrer le prix'))),
        ],
      )),
    );
    if (saved == true) {
      final parsedPrice = double.tryParse(price.text.replaceAll(',','.'));
      final parsedQuantity = double.tryParse(quantity.text.replaceAll(',','.'));
      final selected = products.firstWhere((p)=>(p['id'] as num).toInt()==productId);
      if (externalName.text.trim().isEmpty || parsedPrice == null || parsedPrice < 0 ||
          parsedQuantity == null || parsedQuantity <= 0 || currency.text.trim().isEmpty) {
        _message(tr('راجع اسم المنتج والسعر والكمية والعملة.','Check product name, price, quantity and currency.','Vérifiez le nom, le prix, la quantité et la devise.'));
      } else {
        try {
          final competitorProductId = await db.saveCompetitorProduct(
            userId:userId,competitorId:competitorId,internalProductId:productId,
            externalProductName:externalName.text.trim(),
            observedUnitName:selected['base_unit_name']?.toString(),
            quantityInInternalBase:parsedQuantity);
          await db.recordCompetitorPrice(
            userId:userId,competitorProductId:competitorProductId,
            priceMinor:(parsedPrice*100).round(),currencyCode:currency.text.trim().toUpperCase(),
            observedQuantityInInternalBase:parsedQuantity,
            observedAt:DateTime.now().toIso8601String());
          await refresh();
        } catch (e) { _message(e.toString()); }
      }
    }
    externalName.dispose(); price.dispose(); quantity.dispose(); currency.dispose();
  }

  Future<void> addArea() async {
    if (!canManageDemand) return;
    final name = TextEditingController();
    String type = 'city';
    final saved = await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text(tr('إضافة منطقة سوق','Add market area','Ajouter une zone de marché')),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:name,decoration:InputDecoration(labelText:tr('اسم المنطقة','Area name','Nom de la zone'))),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:type,
            items:[
              DropdownMenuItem(value:'country',child:Text(tr('دولة','Country','Pays'))),
              DropdownMenuItem(value:'city',child:Text(tr('مدينة','City','Ville'))),
              DropdownMenuItem(value:'district',child:Text(tr('مديرية','District','District'))),
              DropdownMenuItem(value:'neighborhood',child:Text(tr('حي','Neighborhood','Quartier'))),
              DropdownMenuItem(value:'other',child:Text(tr('أخرى','Other','Autre'))),
            ],
            onChanged:(v)=>setDialog(()=>type=v??'city'),
          ),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel','Annuler'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('حفظ','Save','Enregistrer'))),
        ],
      )));
    if(saved==true && name.text.trim().isNotEmpty){
      try{
        await db.saveMarketArea(userId:userId,name:name.text.trim(),areaType:type);
        await refresh();
      }catch(e){_message(e.toString());}
    }
    name.dispose();
  }

  Future<void> addDemandObservation() async {
    if (!canManageDemand || areas.isEmpty || products.isEmpty) return;
    int productId=(products.first['id'] as num).toInt();
    int areaId=(areas.first['id'] as num).toInt();
    String observationType='observed';
    final quantityController=TextEditingController();
    final confidenceController=TextEditingController(text:'70');
    final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text(tr('تسجيل احتياج السوق','Record market demand','Enregistrer la demande du marché')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<int>(
            value:productId,
            decoration:InputDecoration(labelText:tr('الصنف','Product','Produit')),
            items:products.map((p)=>DropdownMenuItem(value:(p['id'] as num).toInt(),child:Text(p['name'].toString()))).toList(),
            onChanged:(v)=>setDialog(()=>productId=v??productId)),
          const SizedBox(height:10),
          DropdownButtonFormField<int>(
            value:areaId,
            decoration:InputDecoration(labelText:tr('المنطقة','Area','Zone')),
            items:areas.map((a)=>DropdownMenuItem(value:(a['id'] as num).toInt(),child:Text(a['name'].toString()))).toList(),
            onChanged:(v)=>setDialog(()=>areaId=v??areaId)),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:observationType,
            decoration:InputDecoration(labelText:tr('نوع البيانات','Observation type','Type d’observation')),
            items:[
              DropdownMenuItem(value:'observed',child:Text(tr('مرصود فعلياً','Observed','Observée'))),
              DropdownMenuItem(value:'surveyed',child:Text(tr('استبيان ميداني','Surveyed','Enquête'))),
              DropdownMenuItem(value:'estimated',child:Text(tr('تقديري','Estimated','Estimée'))),
            ],
            onChanged:(v)=>setDialog(()=>observationType=v??'observed')),
          const SizedBox(height:10),
          TextField(controller:quantityController,keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(labelText:tr('الطلب خلال آخر 30 يوماً بوحدة الأساس','Demand over last 30 days in base units','Demande sur 30 jours en unité de base'))),
          const SizedBox(height:10),
          TextField(controller:confidenceController,keyboardType:TextInputType.number,
            decoration:InputDecoration(labelText:tr('درجة الثقة من 0 إلى 100','Confidence 0–100','Confiance de 0 à 100'))),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel','Annuler'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('حفظ','Save','Enregistrer'))),
        ],
      )));
    if(saved==true){
      final qty=double.tryParse(quantityController.text.replaceAll(',','.'));
      final confidence=int.tryParse(confidenceController.text);
      final product=products.firstWhere((p)=>(p['id'] as num).toInt()==productId);
      if(qty==null||qty<0||confidence==null||confidence<0||confidence>100){
        _message(tr('أدخل كمية ودرجة ثقة صحيحتين.','Enter a valid quantity and confidence score.','Saisissez une quantité et un niveau de confiance valides.'));
      }else{
        try{
          final today=DateTime.now();
          final from=today.subtract(const Duration(days:29));
          await db.saveMarketDemandObservation(
            userId:userId,productId:productId,productName:product['name'].toString(),
            areaId:areaId,observationType:observationType,
            periodStart:dateText(from),periodEnd:dateText(today),
            demandQuantityBase:qty,baseUnitName:product['base_unit_name'].toString(),
            confidenceScore:confidence);
          await refresh();
        }catch(e){_message(e.toString());}
      }
    }
    quantityController.dispose();confidenceController.dispose();
  }

  Future<void> addOpportunity() async {
    if(!canManageDecisions)return;
    final title=TextEditingController();
    final description=TextEditingController();
    String priority='medium';
    int? productId=products.isEmpty?null:(products.first['id'] as num).toInt();
    final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,setDialog)=>AlertDialog(
        title:Text(tr('إضافة فرصة نمو','Add growth opportunity','Ajouter une opportunité de croissance')),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,decoration:InputDecoration(labelText:tr('عنوان الفرصة','Opportunity title','Titre de l’opportunité'))),
          const SizedBox(height:10),
          DropdownButtonFormField<int?>(
            value:productId,
            decoration:InputDecoration(labelText:tr('الصنف (اختياري)','Product (optional)','Produit (facultatif)')),
            items:[
              DropdownMenuItem<int?>(value:null,child:Text(tr('غير محدد','Not specified','Non spécifié'))),
              ...products.map((p)=>DropdownMenuItem<int?>(value:(p['id'] as num).toInt(),child:Text(p['name'].toString()))),
            ],
            onChanged:(v)=>setDialog(()=>productId=v)),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:priority,
            decoration:InputDecoration(labelText:tr('الأولوية','Priority','Priorité')),
            items:[
              DropdownMenuItem(value:'low',child:Text(tr('منخفضة','Low','Faible'))),
              DropdownMenuItem(value:'medium',child:Text(tr('متوسطة','Medium','Moyenne'))),
              DropdownMenuItem(value:'high',child:Text(tr('مرتفعة','High','Élevée'))),
              DropdownMenuItem(value:'critical',child:Text(tr('حرجة','Critical','Critique'))),
            ],
            onChanged:(v)=>setDialog(()=>priority=v??'medium')),
          const SizedBox(height:10),
          TextField(controller:description,maxLines:3,decoration:InputDecoration(labelText:tr('الوصف والأدلة','Description and evidence','Description et preuves'))),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(tr('إلغاء','Cancel','Annuler'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(tr('حفظ','Save','Enregistrer'))),
        ],
      )));
    if(saved==true&&title.text.trim().isNotEmpty){
      try{
        await db.createGrowthOpportunity(userId:userId,productId:productId,
          opportunityType:'other',title:title.text.trim(),description:description.text.trim(),priority:priority);
        await refresh();
      }catch(e){_message(e.toString());}
    }
    title.dispose();description.dispose();
  }

  void _message(String value) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));
  }

  Widget _metric(String label,String value,IconData icon) => Card(
    child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
      Icon(icon,size:28,color:Theme.of(context).colorScheme.primary),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:4),
        Text(value,style:Theme.of(context).textTheme.titleLarge),
      ])),
    ])));

  Widget _performanceTab() {
    final netSales=performance.fold<double>(0,(v,p)=>v+((p['net_sales_minor'] as num?)?.toDouble()??0));
    final netProfit=performance.fold<double>(0,(v,p)=>v+((p['gross_profit_minor'] as num?)?.toDouble()??0));
    final sold=performance.fold<double>(0,(v,p)=>v+((p['net_sold_base'] as num?)?.toDouble()??0));
    return ListView(padding:const EdgeInsets.all(12),children:[
      OutlinedButton.icon(onPressed:choosePeriod,icon:const Icon(Icons.date_range),
        label:Text('${dateText(start)}  —  ${dateText(end)}')),
      const SizedBox(height:8),
      _metric(tr('صافي المبيعات','Net sales','Ventes nettes'),money(netSales*1),Icons.payments_outlined),
      _metric(tr('إجمالي الربح التقديري','Gross profit (estimated)','Marge brute (estimée)'),money(netProfit),Icons.trending_up),
      _metric(tr('الكمية المباعة','Net quantity sold','Quantité nette vendue'),quantity(sold),Icons.shopping_cart_outlined),
      const SizedBox(height:12),
      Text(tr('أداء الأصناف','Product performance','Performance des produits'),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      if(performance.isEmpty) Text(tr('لا توجد حركات معتمدة خلال الفترة.','No approved movements in this period.','Aucun mouvement approuvé sur cette période.')),
      ...performance.map((p)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(p['name']?.toString()??'—',style:Theme.of(context).textTheme.titleMedium),
        Text('${p['code']??''}  •  ${p['base_unit_name']??''}',style:Theme.of(context).textTheme.bodySmall),
        const Divider(),
        Wrap(spacing:16,runSpacing:8,children:[
          _stat(tr('توريد صافٍ','Net received','Reçu net'),quantity(p['net_received_base'])),
          _stat(tr('مبيعات صافية','Net sales qty','Qté vendue nette'),quantity(p['net_sold_base'])),
          _stat(tr('صرف صافٍ','Net issues','Sorties nettes'),quantity(p['net_issued_base'])),
          _stat(tr('الرصيد الحالي','Current stock','Stock actuel'),quantity(p['current_stock_base'])),
          _stat(tr('قيمة المبيعات','Sales value','Valeur des ventes'),money(p['net_sales_minor'])),
          _stat(tr('الربح الإجمالي','Gross profit','Marge brute'),money(p['gross_profit_minor'])),
        ]),
      ])))),
    ]);
  }

  Widget _stat(String label,String value)=>SizedBox(width:145,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:Theme.of(context).textTheme.bodySmall),
    Text(value,style:const TextStyle(fontWeight:FontWeight.w600)),
  ]));

  Widget _competitorsTab()=>ListView(padding:const EdgeInsets.all(12),children:[
    if(canManageCompetitors) Wrap(spacing:8,runSpacing:8,children:[
      FilledButton.icon(onPressed:addCompetitor,icon:const Icon(Icons.person_add_alt_1),label:Text(tr('إضافة منافس','Add competitor','Ajouter un concurrent'))),
      OutlinedButton.icon(onPressed:competitors.isEmpty||products.isEmpty?null:addCompetitorPrice,icon:const Icon(Icons.price_change),label:Text(tr('تسجيل سعر ومنتج','Record product and price','Enregistrer produit et prix'))),
    ]),
    const SizedBox(height:8),
    Text(tr('المنافسون المسجلون','Recorded competitors','Concurrents enregistrés'),style:Theme.of(context).textTheme.titleLarge),
    if(competitors.isEmpty) Text(tr('لم تسجل بيانات منافسين بعد.','No competitor data recorded yet.','Aucune donnée concurrentielle enregistrée.')),
    ...competitors.map((c)=>Card(child:ListTile(
      leading:const Icon(Icons.storefront_outlined),
      title:Text(c['name'].toString()),
      subtitle:Text('${c['competitor_type']}  •  ${c['branch_count']} ${tr('فروع','branches','succursales')}  •  ${c['product_count']} ${tr('منتجات','products','produits')}'),
      trailing:(c['is_confidential']==1)?const Icon(Icons.lock_outline):null,
    ))),
    if(!canManageCompetitors) Text(tr('تحتاج صلاحية مستقلة لإدارة بيانات المنافسين.','A separate permission is required to manage competitor data.','Une autorisation distincte est requise pour gérer les concurrents.')),
  ]);

  Widget _demandTab()=>ListView(padding:const EdgeInsets.all(12),children:[
    if(canManageDemand) Wrap(spacing:8,runSpacing:8,children:[
      FilledButton.icon(onPressed:addArea,icon:const Icon(Icons.add_location_alt),label:Text(tr('إضافة منطقة','Add area','Ajouter une zone'))),
      OutlinedButton.icon(onPressed:areas.isEmpty||products.isEmpty?null:addDemandObservation,icon:const Icon(Icons.add_chart),label:Text(tr('تسجيل طلب السوق','Record market demand','Enregistrer la demande'))),
    ]),
    const SizedBox(height:8),
    Text(tr('تقديرات الطلب حسب المنطقة','Demand observations by area','Observations de demande par zone'),style:Theme.of(context).textTheme.titleLarge),
    ...demand.map((d)=>Card(child:ListTile(
      leading:const Icon(Icons.insights_outlined),
      title:Text(d['product_name_snapshot'].toString()),
      subtitle:Text('${d['area_name']??''}  •  ${d['period_start']} — ${d['period_end']}  •  ${d['observation_type']}'),
      trailing:Text('${quantity(d['demand_quantity_base'])} ${d['base_unit_name_snapshot']}'),
    ))),
    const Divider(),
    Text(tr('الطلبات التي لم نتمكن من تلبيتها','Unfulfilled customer demand','Demandes non satisfaites'),style:Theme.of(context).textTheme.titleLarge),
    ...demand.isEmpty?[]:[],
  ]);

  Widget _opportunitiesTab()=>ListView(padding:const EdgeInsets.all(12),children:[
    if(canManageDecisions) Align(alignment:AlignmentDirectional.centerStart,
      child:FilledButton.icon(onPressed:addOpportunity,icon:const Icon(Icons.lightbulb_outline),label:Text(tr('إضافة فرصة نمو','Add opportunity','Ajouter une opportunité')))),
    const SizedBox(height:8),
    if(opportunities.isEmpty) Text(tr('لا توجد فرص مسجلة.','No opportunities recorded.','Aucune opportunité enregistrée.')),
    ...opportunities.map((o)=>Card(child:ListTile(
      leading:Icon(Icons.trending_up,color:o['priority']=='critical'||o['priority']=='high'?Colors.orange:Theme.of(context).colorScheme.primary),
      title:Text(o['title'].toString()),
      subtitle:Text('${o['product_name']??tr('جميع الأصناف','All products','Tous les produits')}  •  ${o['area_name']??''}  •  ${o['status']}'),
      trailing:Text(o['priority'].toString()),
    ))),
  ]);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection:rtl?TextDirection.rtl:TextDirection.ltr,
    child:Scaffold(
      appBar:AppBar(
        title:Text(tr('أداء وتحليل المنتجات والسوق','Product Performance & Market Intelligence','Performance des produits et intelligence de marché')),
        actions:[IconButton(onPressed:refresh,tooltip:tr('تحديث','Refresh','Actualiser'),icon:const Icon(Icons.refresh))],
        bottom:const TabBar(isScrollable:true,tabs:[
          Tab(icon:Icon(Icons.analytics_outlined),text:'Performance'),
          Tab(icon:Icon(Icons.storefront_outlined),text:'Competitors'),
          Tab(icon:Icon(Icons.public_outlined),text:'Demand'),
          Tab(icon:Icon(Icons.lightbulb_outline),text:'Opportunities'),
        ]),
      ),
      body:loading?const Center(child:CircularProgressIndicator())
        :error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(error!,textAlign:TextAlign.center)))
        :TabBarView(children:[
          _performanceTab(),_competitorsTab(),_demandTab(),_opportunitiesTab(),
        ]),
    ),
  );
}
