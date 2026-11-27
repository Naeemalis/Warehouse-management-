import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'data/access_control.dart';
import 'data/wms_database.dart';

class AccessAdminScreen extends StatefulWidget {
  const AccessAdminScreen({super.key, required this.language});
  final String language;

  @override
  State<AccessAdminScreen> createState() => _AccessAdminScreenState();
}

class _AccessAdminScreenState extends State<AccessAdminScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, Map<String, String>> _translations = {
    "إضافة قسم": {'en': "Add department", 'fr': "Ajouter un service"},
    "اسم القسم": {'en': "Department name", 'fr': "Nom du service"},
    "إلغاء": {'en': "Cancel", 'fr': "Annuler"},
    "حفظ": {'en': "Save", 'fr': "Enregistrer"},
    "تعذر حفظ القسم: ": {'en': "Could not save department: ", 'fr': "Impossible d’enregistrer le service : "},
    "إضافة دور وظيفي": {'en': "Add role", 'fr': "Ajouter un rôle"},
    "اسم الدور": {'en': "Role name", 'fr': "Nom du rôle"},
    "تعذر حفظ الدور: ": {'en': "Could not save role: ", 'fr': "Impossible d’enregistrer le rôle : "},
    "إضافة مستخدم": {'en': "Add user", 'fr': "Ajouter un utilisateur"},
    "الاسم الكامل": {'en': "Full name", 'fr': "Nom complet"},
    "اسم الدخول": {'en': "Username", 'fr': "Nom d’utilisateur"},
    "كلمة المرور": {'en': "Password", 'fr': "Mot de passe"},
    "القسم": {'en': "Department", 'fr': "Service"},
    "بدون قسم": {'en': "No department", 'fr': "Aucun service"},
    "الدور الوظيفي": {'en': "Job role", 'fr': "Fonction"},
    "بدون دور": {'en': "No role", 'fr': "Aucun rôle"},
    "إنشاء المستخدم": {'en': "Create user", 'fr': "Créer l’utilisateur"},
    "تم إنشاء المستخدم. لم تُمنح له أي صلاحية تلقائياً.": {'en': "User created. No permissions were granted automatically.", 'fr': "Utilisateur créé. Aucune autorisation ne lui a été accordée automatiquement."},
    "تعذر إنشاء المستخدم: ": {'en': "Could not create user: ", 'fr': "Impossible de créer l’utilisateur : "},
    "حسب الدور": {'en': "Inherit role permissions", 'fr': "Selon le rôle"},
    "سماح": {'en': "Allow", 'fr': "Autoriser"},
    "منع": {'en': "Deny", 'fr': "Refuser"},
    "صلاحيات ": {'en': "Permissions: ", 'fr': "Autorisations : "},
    "إضافة دور": {'en': "Add role", 'fr': "Ajouter un rôle"},
    "تحديد صلاحيات الدور بشكل صريح": {'en': "Explicitly configure role permissions", 'fr': "Définir explicitement les autorisations du rôle"},
    "الدور نشط": {'en': "Role active", 'fr': "Rôle actif"},
    "تفعيل أو إيقاف هذه الصلاحية لهذا الدور": {'en': "Enable or disable this permission for this role", 'fr': "Activer ou désactiver cette autorisation pour ce rôle"},
    "تخصيص صلاحيات المستخدم": {'en': "Customize user permissions", 'fr': "Personnaliser les autorisations de l’utilisateur"},
    "حساب نشط": {'en': "Account active", 'fr': "Compte actif"},
    "اسم المؤسسة يظهر في الفواتير والسندات والتقارير.": {'en': "The organization name appears on invoices, vouchers, and reports.", 'fr': "Le nom de l’organisation apparaît sur les factures, reçus et rapports."},
    "اسم المؤسسة": {'en': "Organization name", 'fr': "Nom de l’organisation"},
    "تم حفظ اسم المؤسسة": {'en': "Organization name saved", 'fr': "Nom de l’organisation enregistré"},
    "تعذر الحفظ: ": {'en': "Could not save: ", 'fr': "Échec de l’enregistrement : "},
    "حفظ بيانات المؤسسة": {'en': "Save organization details", 'fr': "Enregistrer les informations de l’organisation"},
    "الإدارة والصلاحيات": {'en': "Administration & Permissions", 'fr': "Administration et autorisations"},
    "المستخدمون": {'en': "Users", 'fr': "Utilisateurs"},
    "الأقسام": {'en': "Departments", 'fr': "Services"},
    "الأدوار والصلاحيات": {'en': "Roles & Permissions", 'fr': "Rôles et autorisations"},
    "المؤسسة": {'en': "Organization", 'fr': "Organisation"},
    "إنشاء التوريد": {'en': "Create receipts", 'fr': "Créer les réceptions"},
    "إنشاء الصرف": {'en': "Create issues", 'fr': "Créer les sorties"},
    "اعتماد المستندات": {'en': "Approve documents", 'fr': "Approuver les documents"},
    "إدارة المرتجعات": {'en': "Manage returns", 'fr': "Gérer les retours"},
    "عرض الموردين وكشوفهم": {'en': "View suppliers and statements", 'fr': "Voir les fournisseurs et leurs relevés"},
    "تسجيل دفعات الموردين": {'en': "Record supplier payments", 'fr': "Enregistrer les paiements fournisseurs"},
    "عرض العملاء وكشوفهم": {'en': "View customers and statements", 'fr': "Voir les clients et leurs relevés"},
    "تسجيل دفعات العملاء": {'en': "Record customer payments", 'fr': "Enregistrer les paiements clients"},
    "الجرد": {'en': "Stocktaking", 'fr': "Inventaire"},
    "عرض التقارير": {'en': "View reports", 'fr': "Voir les rapports"},
    "إدارة المستخدمين": {'en': "Manage users", 'fr': "Gérer les utilisateurs"},
    "إدارة الأقسام": {'en': "Manage departments", 'fr': "Gérer les services"},
    "إدارة الأدوار والصلاحيات": {'en': "Manage roles and permissions", 'fr': "Gérer les rôles et autorisations"},
    "إعدادات المؤسسة": {'en': "Organization settings", 'fr': "Paramètres de l’organisation"},
    "الاطلاع على معلومات المنافسين السرية": {'en': "View confidential competitor information", 'fr': "Consulter les informations confidentielles sur les concurrents"},
    "التوريد": {'en': "Receiving", 'fr': "Réception"},
    "الصرف": {'en': "Issuing", 'fr': "Sortie"},
    "الاعتمادات": {'en': "Approvals", 'fr': "Approbations"},
    "المرتجعات": {'en': "Returns", 'fr': "Retours"},
    "الموردون": {'en': "Suppliers", 'fr': "Fournisseurs"},
    "العملاء": {'en': "Customers", 'fr': "Clients"},
    "المخزون": {'en': "Inventory", 'fr': "Stock"},
    "التقارير": {'en': "Reports", 'fr': "Rapports"},
    "الإدارة": {'en': "Administration", 'fr': "Administration"},
    "الإعدادات": {'en': "Settings", 'fr': "Paramètres"},
    "معلومات سرية": {'en': "Confidential information", 'fr': "Informations confidentielles"},
  };
  String tr(String value) => _translations[value]?[widget.language] ?? value;

  final db = WmsDatabase.instance;
  final company = TextEditingController();
  List<Map<String,Object?>> users = [];
  List<Map<String,Object?>> departments = [];
  List<Map<String,Object?>> roles = [];
  List<Map<String,Object?>> permissions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    company.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final values = await Future.wait([
      db.listUsers(activeOnly: false),
      db.listDepartments(activeOnly: false),
      db.listRoles(activeOnly: false),
      db.listPermissions(),
      db.companyName(),
    ]);
    if (!mounted) return;
    setState(() {
      users = values[0] as List<Map<String,Object?>>;
      departments = values[1] as List<Map<String,Object?>>;
      roles = values[2] as List<Map<String,Object?>>;
      permissions = values[3] as List<Map<String,Object?>>;
      company.text = values[4] as String;
      loading = false;
    });
  }

  void notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)));
  }

  Future<void> addDepartment() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: Text(tr('إضافة قسم')),
        content: TextField(controller: name, decoration:
          InputDecoration(labelText: tr('اسم القسم'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx,false),
            child: Text(tr('إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx,true),
            child: Text(tr('حفظ'))),
        ]));
    if (ok == true) {
      try { await db.saveDepartment(name: name.text); await load(); }
      catch (e) { notify('${tr('تعذر حفظ القسم: ')}$e'); }
    }
    name.dispose();
  }

  Future<void> addRole() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: Text(tr('إضافة دور وظيفي')),
        content: TextField(controller: name, decoration:
          InputDecoration(labelText: tr('اسم الدور'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx,false),
            child: Text(tr('إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(ctx,true),
            child: Text(tr('حفظ'))),
        ]));
    if (ok == true) {
      try { await db.saveRole(name: name.text); await load(); }
      catch (e) { notify('${tr('تعذر حفظ الدور: ')}$e'); }
    }
    name.dispose();
  }

  Future<void> addUser() async {
    final username = TextEditingController();
    final fullName = TextEditingController();
    final password = TextEditingController();
    int? departmentId;
    int? roleId;
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      StatefulBuilder(builder: (ctx,setLocal) => AlertDialog(
        title: Text(tr('إضافة مستخدم')),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: fullName, decoration:
              InputDecoration(labelText: tr('الاسم الكامل'))),
            TextField(controller: username, decoration:
              InputDecoration(labelText: tr('اسم الدخول'))),
            TextField(controller: password, obscureText: true, decoration:
              InputDecoration(labelText: tr('كلمة المرور'))),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: departmentId, decoration:
                InputDecoration(labelText: tr('القسم')),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(tr('بدون قسم'))),
                ...departments.where((d)=>d['is_active']==1).map((d)=>
                  DropdownMenuItem<int?>(value:d['id'] as int,
                    child:Text(d['name'].toString()))),
              ],
              onChanged:(v)=>setLocal(()=>departmentId=v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: roleId, decoration:
                InputDecoration(labelText: tr('الدور الوظيفي')),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(tr('بدون دور'))),
                ...roles.where((r)=>r['is_active']==1).map((r)=>
                  DropdownMenuItem<int?>(value:r['id'] as int,
                    child:Text(r['name'].toString()))),
              ],
              onChanged:(v)=>setLocal(()=>roleId=v),
            ),
          ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:Text(tr('إلغاء'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:Text(tr('إنشاء المستخدم'))),
        ],
      )));
    if (ok == true) {
      try {
        final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
        final hash = sha256.convert(utf8.encode('$salt:${password.text}')).toString();
        await db.createUser(username: username.text, fullName: fullName.text,
          passwordHash: hash, passwordSalt: salt,
          departmentId: departmentId, roleId: roleId);
        await load();
        notify(tr('تم إنشاء المستخدم. لم تُمنح له أي صلاحية تلقائياً.'));
      } catch (e) { notify('${tr('تعذر إنشاء المستخدم: ')}$e'); }
    }
    username.dispose(); fullName.dispose(); password.dispose();
  }

  Future<void> showUserOverrides(Map<String,Object?> user) async {
    final userId = user['id'] as int;
    final overrides = <String,bool?>{};
    for (final p in permissions) {
      final override = await db.userPermissionOverride(userId,p['permission_key'] as String);
      overrides[p['permission_key'] as String] = override;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setSheet)=>SafeArea(
        child:SizedBox(height:MediaQuery.of(ctx).size.height*.82,
          child:Column(children:[
            Padding(padding:const EdgeInsets.all(16),child:Text(
              'صلاحيات ${user['full_name']}',
              style:Theme.of(ctx).textTheme.titleLarge)),
            Expanded(child:ListView(children:permissions.map((p){
              final key=p['permission_key'] as String;
              return ListTile(
                title:Text(tr(p['label_ar'].toString())),
                subtitle:Text(tr(p['module'].toString())),
                trailing:DropdownButton<String>(
                  value: overrides[key]==null ? 'inherit' : (overrides[key]==true?'allow':'deny'),
                  items: [
                    DropdownMenuItem(value:'inherit',child:Text(tr('حسب الدور'))),
                    DropdownMenuItem(value:'allow',child:Text(tr('سماح'))),
                    DropdownMenuItem(value:'deny',child:Text(tr('منع'))),
                  ],
                  onChanged:(v) async {
                    if(v==null)return;
                    if(v=='inherit') {
                      await db.clearUserPermission(userId,key);
                      overrides.remove(key);
                    } else {
                      await db.setUserPermission(userId:userId,permissionKey:key,
                        allowed:v=='allow');
                      overrides[key]=v=='allow';
                    }
                    setSheet((){});
                  },
                ),
              );
            }).toList())),
          ])))));
  }

  Widget departmentsTab() => ListView(
    padding:const EdgeInsets.all(12),
    children:[
      Align(alignment:AlignmentDirectional.centerEnd,child:FilledButton.icon(
        onPressed:addDepartment,icon:const Icon(Icons.add),label:Text(tr('إضافة قسم')))),
      ...departments.map((d)=>Card(child:SwitchListTile(
        title:Text(d['name'].toString()),
        subtitle:Text(d['description']?.toString()??''),
        value:d['is_active']==1,
        onChanged:(v)async{await db.setDepartmentActive(d['id'] as int,v);await load();},
      ))),
    ],
  );

  Widget rolesTab() => ListView(
    padding:const EdgeInsets.all(12),
    children:[
      Align(alignment:AlignmentDirectional.centerEnd,child:FilledButton.icon(
        onPressed:addRole,icon:const Icon(Icons.add),label:Text(tr('إضافة دور')))),
      ...roles.map((r)=>Card(child:ExpansionTile(
        title:Text(r['name'].toString()),
        subtitle:Text(tr('تحديد صلاحيات الدور بشكل صريح')),
        children:[
          SwitchListTile(
            title:Text(tr('الدور نشط')),
            value:r['is_active']==1,
            onChanged:(v)async{await db.setRoleActive(r['id'] as int,v);await load();},
          ),
          ...permissions.map((p)=>FutureBuilder<bool>(
            future:db.roleHasPermission(r['id'] as int,p['permission_key'] as String),
            builder:(ctx,snapshot)=>SwitchListTile(
              dense:true,title:Text(p['label_ar'].toString()),
              subtitle:Text(tr('تفعيل أو إيقاف هذه الصلاحية لهذا الدور')),
              value:snapshot.data??false,
              onChanged:(v)async{
                await db.setRolePermission(roleId:r['id'] as int,
                  permissionKey:p['permission_key'] as String,allowed:v);
                setState((){});
              },
            ),
          )),
        ],
      ))),
    ],
  );

  Widget usersTab() => ListView(
    padding:const EdgeInsets.all(12),
    children:[
      Align(alignment:AlignmentDirectional.centerEnd,child:FilledButton.icon(
        onPressed:addUser,icon:const Icon(Icons.person_add),label:Text(tr('إضافة مستخدم')))),
      ...users.map((u)=>Card(child:ExpansionTile(
        title:Text(u['full_name'].toString()),
        subtitle:Text('${u['username']} · ${u['department_name']??tr('بدون قسم')} · ${u['role_name']??tr('بدون دور')}'),
        children:[
          ListTile(title:Text(tr('تخصيص صلاحيات المستخدم')),
            trailing:const Icon(Icons.tune),
            onTap:()=>showUserOverrides(u)),
          SwitchListTile(title:Text(tr('حساب نشط')),
            value:u['is_active']==1,
            onChanged:(v)async{await db.setUserActive(u['id'] as int,v);await load();}),
        ],
      ))),
    ],
  );

  Widget companyTab() => ListView(
    padding:const EdgeInsets.all(16),
    children:[
      Text(tr('اسم المؤسسة يظهر في الفواتير والسندات والتقارير.')),
      const SizedBox(height:12),
      TextField(controller:company,decoration:
        InputDecoration(labelText:tr('اسم المؤسسة'))),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()async{
        try{await db.saveCompanyName(company.text);notify(tr('تم حفظ اسم المؤسسة'));}
        catch(e){notify('${tr('تعذر الحفظ: ')}$e');}
      },icon:const Icon(Icons.save),label:Text(tr('حفظ بيانات المؤسسة'))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return DefaultTabController(length:4,child:Scaffold(
      appBar:AppBar(title:Text(tr('الإدارة والصلاحيات')),bottom:TabBar(
        isScrollable:true,tabs:[
          Tab(text:tr('المستخدمون'),icon:Icon(Icons.people)),
          Tab(text:tr('الأقسام'),icon:Icon(Icons.apartment)),
          Tab(text:tr('الأدوار والصلاحيات'),icon:Icon(Icons.admin_panel_settings)),
          Tab(text:tr('المؤسسة'),icon:Icon(Icons.business)),
        ])),
      body:TabBarView(children:[usersTab(),departmentsTab(),rolesTab(),companyTab()]),
    ));
  }
}
