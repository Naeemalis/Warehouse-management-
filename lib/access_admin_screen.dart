import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'data/access_control.dart';
import 'data/wms_database.dart';

class AccessAdminScreen extends StatefulWidget {
  const AccessAdminScreen({super.key});

  @override
  State<AccessAdminScreen> createState() => _AccessAdminScreenState();
}

class _AccessAdminScreenState extends State<AccessAdminScreen>
    with SingleTickerProviderStateMixin {
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
      AlertDialog(title: const Text('إضافة قسم'),
        content: TextField(controller: name, decoration:
          const InputDecoration(labelText: 'اسم القسم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx,false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx,true),
            child: const Text('حفظ')),
        ]));
    if (ok == true) {
      try { await db.saveDepartment(name: name.text); await load(); }
      catch (e) { notify('تعذر حفظ القسم: $e'); }
    }
    name.dispose();
  }

  Future<void> addRole() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(title: const Text('إضافة دور وظيفي'),
        content: TextField(controller: name, decoration:
          const InputDecoration(labelText: 'اسم الدور')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx,false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx,true),
            child: const Text('حفظ')),
        ]));
    if (ok == true) {
      try { await db.saveRole(name: name.text); await load(); }
      catch (e) { notify('تعذر حفظ الدور: $e'); }
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
        title: const Text('إضافة مستخدم'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: fullName, decoration:
              const InputDecoration(labelText: 'الاسم الكامل')),
            TextField(controller: username, decoration:
              const InputDecoration(labelText: 'اسم الدخول')),
            TextField(controller: password, obscureText: true, decoration:
              const InputDecoration(labelText: 'كلمة المرور')),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: departmentId, decoration:
                const InputDecoration(labelText: 'القسم'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('بدون قسم')),
                ...departments.where((d)=>d['is_active']==1).map((d)=>
                  DropdownMenuItem<int?>(value:d['id'] as int,
                    child:Text(d['name'].toString()))),
              ],
              onChanged:(v)=>setLocal(()=>departmentId=v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: roleId, decoration:
                const InputDecoration(labelText: 'الدور الوظيفي'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('بدون دور')),
                ...roles.where((r)=>r['is_active']==1).map((r)=>
                  DropdownMenuItem<int?>(value:r['id'] as int,
                    child:Text(r['name'].toString()))),
              ],
              onChanged:(v)=>setLocal(()=>roleId=v),
            ),
          ])),
        actions: [
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('إنشاء المستخدم')),
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
        notify('تم إنشاء المستخدم. لم تُمنح له أي صلاحية تلقائياً.');
      } catch (e) { notify('تعذر إنشاء المستخدم: $e'); }
    }
    username.dispose(); fullName.dispose(); password.dispose();
  }

  Future<void> showUserOverrides(Map<String,Object?> user) async {
    final userId = user['id'] as int;
    final overrides = <String,int>{};
    for (final p in permissions) {
      final allowed = await db.userHasPermission(userId,p['permission_key'] as String);
      overrides[p['permission_key'] as String] = allowed ? 1 : 0;
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
                title:Text(p['label_ar'].toString()),
                subtitle:Text(p['module'].toString()),
                trailing:DropdownButton<String>(
                  value: overrides.containsKey(key) ? (overrides[key]==1?'allow':'deny') : 'inherit',
                  items:const [
                    DropdownMenuItem(value:'inherit',child:Text('حسب الدور')),
                    DropdownMenuItem(value:'allow',child:Text('سماح')),
                    DropdownMenuItem(value:'deny',child:Text('منع')),
                  ],
                  onChanged:(v) async {
                    if(v==null)return;
                    if(v=='inherit') {
                      await db.clearUserPermission(userId,key);
                      overrides.remove(key);
                    } else {
                      await db.setUserPermission(userId:userId,permissionKey:key,
                        allowed:v=='allow');
                      overrides[key]=v=='allow'?1:0;
                    }
                    setSheet((){});
                  },
                ),
              );
            }).toList())),
          ]))));
  }

  Widget departmentsTab() => ListView(
    padding:const EdgeInsets.all(12),
    children:[
      Align(alignment:AlignmentDirectional.centerEnd,child:FilledButton.icon(
        onPressed:addDepartment,icon:const Icon(Icons.add),label:const Text('إضافة قسم'))),
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
        onPressed:addRole,icon:const Icon(Icons.add),label:const Text('إضافة دور'))),
      ...roles.map((r)=>Card(child:ExpansionTile(
        title:Text(r['name'].toString()),
        subtitle:Text('تحديد صلاحيات الدور بشكل صريح'),
        children:[
          SwitchListTile(
            title:const Text('الدور نشط'),
            value:r['is_active']==1,
            onChanged:(v)async{await db.setRoleActive(r['id'] as int,v);await load();},
          ),
          ...permissions.map((p)=>FutureBuilder<bool>(
            future:db.roleHasPermission(r['id'] as int,p['permission_key'] as String),
            builder:(ctx,snapshot)=>SwitchListTile(
              dense:true,title:Text(p['label_ar'].toString()),
              subtitle:Text(p['permission_key'].toString()),
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
        onPressed:addUser,icon:const Icon(Icons.person_add),label:const Text('إضافة مستخدم'))),
      ...users.map((u)=>Card(child:ExpansionTile(
        title:Text(u['full_name'].toString()),
        subtitle:Text('${u['username']} · ${u['department_name']??'بدون قسم'} · ${u['role_name']??'بدون دور'}'),
        children:[
          ListTile(title:const Text('تخصيص صلاحيات المستخدم'),
            trailing:const Icon(Icons.tune),
            onTap:()=>showUserOverrides(u)),
          SwitchListTile(title:const Text('حساب نشط'),
            value:u['is_active']==1,
            onChanged:(v)async{await db.setUserActive(u['id'] as int,v);await load();}),
        ],
      ))),
    ],
  );

  Widget companyTab() => ListView(
    padding:const EdgeInsets.all(16),
    children:[
      const Text('اسم المؤسسة يظهر في الفواتير والسندات والتقارير.'),
      const SizedBox(height:12),
      TextField(controller:company,decoration:
        const InputDecoration(labelText:'اسم المؤسسة')),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()async{
        try{await db.saveCompanyName(company.text);notify('تم حفظ اسم المؤسسة');}
        catch(e){notify('تعذر الحفظ: $e');}
      },icon:const Icon(Icons.save),label:const Text('حفظ بيانات المؤسسة')),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return DefaultTabController(length:4,child:Scaffold(
      appBar:AppBar(title:const Text('الإدارة والصلاحيات'),bottom:const TabBar(
        isScrollable:true,tabs:[
          Tab(text:'المستخدمون',icon:Icon(Icons.people)),
          Tab(text:'الأقسام',icon:Icon(Icons.apartment)),
          Tab(text:'الأدوار والصلاحيات',icon:Icon(Icons.admin_panel_settings)),
          Tab(text:'المؤسسة',icon:Icon(Icons.business)),
        ])),
      body:TabBarView(children:[usersTab(),departmentsTab(),rolesTab(),companyTab()]),
    ));
  }
}
