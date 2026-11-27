import 'package:sqflite/sqflite.dart';
import 'wms_database.dart';

extension WmsAccessControl on WmsDatabase {
  Future<String> companyName() async {
    final db = await database;
    final rows = await db.query('app_settings',
      columns: ['setting_value'], where: 'setting_key=?',
      whereArgs: ['company_name'], limit: 1);
    return rows.isEmpty ? '' : (rows.first['setting_value'] as String? ?? '');
  }

  Future<void> saveCompanyName(String name) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Company name is required');
    final db = await database;
    await db.insert('app_settings', {
      'setting_key': 'company_name', 'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> listDepartments({bool activeOnly = true}) async {
    final db = await database;
    return db.query('departments',
      where: activeOnly ? 'is_active=1' : null,
      orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveDepartment({int? id, required String name, String? description}) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Department name is required');
    final db = await database;
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      return db.insert('departments', {
        'name': value, 'description': description?.trim(), 'created_at': now,
      });
    }
    final changed = await db.update('departments', {
      'name': value, 'description': description?.trim(),
    }, where: 'id=?', whereArgs: [id]);
    if (changed != 1) throw StateError('Department not found');
    return id;
  }

  Future<void> setDepartmentActive(int id, bool active) async {
    final db = await database;
    await db.update('departments', {'is_active': active ? 1 : 0},
      where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> listRoles({bool activeOnly = true}) async {
    final db = await database;
    return db.query('roles',
      where: activeOnly ? 'is_active=1' : null,
      orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveRole({int? id, required String name, String? description}) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('Role name is required');
    final db = await database;
    final now = DateTime.now().toIso8601String();
    if (id == null) {
      return db.insert('roles', {
        'name': value, 'description': description?.trim(), 'created_at': now,
      });
    }
    final changed = await db.update('roles', {
      'name': value, 'description': description?.trim(),
    }, where: 'id=?', whereArgs: [id]);
    if (changed != 1) throw StateError('Role not found');
    return id;
  }

  Future<void> setRoleActive(int id, bool active) async {
    final db = await database;
    await db.update('roles', {'is_active': active ? 1 : 0},
      where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> listPermissions() async {
    final db = await database;
    return db.query('permissions', orderBy: 'module, permission_key');
  }

  Future<bool> roleHasPermission(int roleId, String permissionKey) async {
    final db = await database;
    final rows = await db.query('role_permissions',
      columns: ['is_allowed'],
      where: 'role_id=? AND permission_key=?',
      whereArgs: [roleId, permissionKey], limit: 1);
    return rows.isNotEmpty && rows.first['is_allowed'] == 1;
  }

  Future<void> setRolePermission({
    required int roleId, required String permissionKey, required bool allowed,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('role_permissions', {
      'role_id': roleId, 'permission_key': permissionKey,
      'is_allowed': allowed ? 1 : 0, 'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setUserPermission({
    required int userId, required String permissionKey,
    required bool allowed, int? grantedBy,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('user_permissions', {
      'user_id': userId, 'permission_key': permissionKey,
      'is_allowed': allowed ? 1 : 0, 'granted_by': grantedBy,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // A user-specific decision always overrides the role. No role name,
  // including Admin or Super Admin, bypasses an explicit permission check.
  Future<bool> userHasPermission(int userId, String permissionKey) async {
    final db = await database;
    final users = await db.query('users',
      columns: ['role_id', 'is_active'], where: 'id=?',
      whereArgs: [userId], limit: 1);
    if (users.isEmpty || users.first['is_active'] != 1) return false;
    final overrides = await db.query('user_permissions',
      columns: ['is_allowed'], where: 'user_id=? AND permission_key=?',
      whereArgs: [userId, permissionKey], limit: 1);
    if (overrides.isNotEmpty) return overrides.first['is_allowed'] == 1;
    final roleId = users.first['role_id'] as int?;
    if (roleId == null) return false;
    final grants = await db.query('role_permissions',
      columns: ['is_allowed'], where: 'role_id=? AND permission_key=?',
      whereArgs: [roleId, permissionKey], limit: 1);
    return grants.isNotEmpty && grants.first['is_allowed'] == 1;
  }


  Future<bool?> userPermissionOverride(int userId, String permissionKey) async {
    final db = await database;
    final rows = await db.query('user_permissions',
      columns: ['is_allowed'],
      where: 'user_id=? AND permission_key=?',
      whereArgs: [userId, permissionKey], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['is_allowed'] == 1;
  }

  Future<void> clearUserPermission(int userId, String permissionKey) async {
    final db = await database;
    await db.delete('user_permissions',
      where: 'user_id=? AND permission_key=?',
      whereArgs: [userId, permissionKey]);
  }

  Future<int> createUser({
    required String username, required String fullName,
    required String passwordHash, required String passwordSalt, int? departmentId, int? roleId,
  }) async {
    final login = username.trim();
    final name = fullName.trim();
    if (login.isEmpty || name.isEmpty || passwordHash.isEmpty) {
      throw ArgumentError('Username, full name and password hash are required');
    }
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('users', {
      'username': login, 'full_name': name, 'password_hash': passwordHash, 'password_salt': passwordSalt,
      'department_id': departmentId, 'role_id': roleId,
      'created_at': now, 'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listUsers({bool activeOnly = true}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT u.id,u.username,u.full_name,u.department_id,u.role_id,u.is_active,
        d.name AS department_name,r.name AS role_name
      FROM users u
      LEFT JOIN departments d ON d.id=u.department_id
      LEFT JOIN roles r ON r.id=u.role_id
      ${activeOnly ? 'WHERE u.is_active=1' : ''}
      ORDER BY u.full_name COLLATE NOCASE
    ''');
  }

  Future<void> updateUser({
    required int id, required String fullName,
    int? departmentId, int? roleId, String? passwordHash, String? passwordSalt,
  }) async {
    if (fullName.trim().isEmpty) throw ArgumentError('Full name is required');
    final values = <String, Object?>{
      'full_name': fullName.trim(), 'department_id': departmentId,
      'role_id': roleId, 'updated_at': DateTime.now().toIso8601String(),
    };
    if (passwordHash != null && passwordHash.isNotEmpty) {
      values['password_hash'] = passwordHash;
      values['password_salt'] = passwordSalt;
    }
    final db = await database;
    final changed = await db.update('users', values,
      where: 'id=?', whereArgs: [id]);
    if (changed != 1) throw StateError('User not found');
  }

  Future<void> setUserActive(int id, bool active) async {
    final db = await database;
    await db.update('users', {
      'is_active': active ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id=?', whereArgs: [id]);
  }
}
