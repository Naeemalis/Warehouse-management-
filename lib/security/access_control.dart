import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../data/wms_database.dart';

/// An in-memory authenticated identity. Do not persist this object or its
/// credentials; a new login is required when the app process restarts.
class UserSession {
  const UserSession({
    required this.userId,
    required this.username,
    required this.displayName,
  });

  final int userId;
  final String username;
  final String displayName;
}

/// Local account and role-based access-control service.
///
/// Sensitive competitor permissions are deliberately absent from all seeded
/// roles. They can only be granted explicitly to an individual account.
class AccessControlService {
  AccessControlService({WmsDatabase? database})
      : _database = database ?? WmsDatabase.instance;

  final WmsDatabase _database;

  static const int passwordIterations = 210000;
  static const int minimumPasswordLength = 10;
  static const int maximumFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  static const Set<String> sensitivePermissionKeys = {
    'competitors.view',
    'competitors.edit',
    'competitors.export',
  };

  static final Pbkdf2 _passwordAlgorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: passwordIterations,
    bits: 256,
  );

  static bool isValidUsername(String value) {
    final normalized = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9][a-z0-9._-]{2,31}$').hasMatch(normalized);
  }

  static bool isValidPassword(String value) =>
      value.length >= minimumPasswordLength &&
      value.trim().isNotEmpty;

  static String _normalizeUsername(String value) =>
      value.trim().toLowerCase();

  static Future<Map<String, String>> _hashPassword(String password) async {
    if (!isValidPassword(password)) {
      throw ArgumentError('Password must contain at least 10 characters.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _passwordAlgorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return {
      'password_hash': base64UrlEncode(await key.extractBytes()),
      'password_salt': base64UrlEncode(salt),
    };
  }

  static Future<bool> _verifyPassword(
    String password,
    String encodedSalt,
    String expectedHash,
  ) async {
    final salt = base64Url.decode(encodedSalt);
    final key = await _passwordAlgorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final actual = await key.extractBytes();
    final expected = base64Url.decode(expectedHash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<bool> isFirstRun() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM app_users');
    return (rows.first['total'] as int) == 0;
  }

  /// Creates the first Super Admin only when the local database has no users.
  /// No default username/password is ever inserted automatically.
  Future<int> bootstrapFirstAdmin({
    required String username,
    required String displayName,
    required String password,
  }) async {
    if (!isValidUsername(username)) {
      throw ArgumentError('Username must be 3-32 characters: letters, digits, dot, underscore or hyphen.');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError('Display name is required.');
    }
    final credentials = await _hashPassword(password);
    final db = await _database.database;
    return db.transaction((txn) async {
      final count = await txn.rawQuery('SELECT COUNT(*) AS total FROM app_users');
      if ((count.first['total'] as int) != 0) {
        throw StateError('Initial administrator has already been created.');
      }
      final now = DateTime.now().toIso8601String();
      final userId = await txn.insert('app_users', {
        'username': _normalizeUsername(username),
        'display_name': displayName.trim(),
        ...credentials,
        'password_iterations': passwordIterations,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      final roles = await txn.query(
        'app_roles',
        columns: ['id'],
        where: 'role_key=?',
        whereArgs: ['super_admin'],
        limit: 1,
      );
      if (roles.isEmpty) throw StateError('Super Admin role is missing.');
      await txn.insert('user_roles', {
        'user_id': userId,
        'role_id': roles.first['id'],
        'assigned_by': userId,
        'created_at': now,
      });
      await txn.insert('audit_log', {
        'entity_type': 'user',
        'entity_id': userId,
        'action': 'bootstrap_super_admin',
        'actor_id': userId,
        'details': 'Initial local administrator created',
        'created_at': now,
      });
      return userId;
    });
  }

  Future<UserSession?> authenticate({
    required String username,
    required String password,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_users',
      where: 'username=? COLLATE NOCASE',
      whereArgs: [_normalizeUsername(username)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = rows.first;
    if ((user['is_active'] as int) != 1) return null;

    final now = DateTime.now();
    final lockedUntil = DateTime.tryParse(user['locked_until']?.toString() ?? '');
    if (lockedUntil != null && lockedUntil.isAfter(now)) return null;

    final valid = await _verifyPassword(
      password,
      user['password_salt'] as String,
      user['password_hash'] as String,
    );
    final userId = user['id'] as int;
    if (!valid) {
      final attempts = (user['failed_login_attempts'] as int) + 1;
      final lockUntil = attempts >= maximumFailedAttempts
          ? now.add(lockoutDuration).toIso8601String()
          : null;
      await db.update(
        'app_users',
        {
          'failed_login_attempts': attempts >= maximumFailedAttempts ? 0 : attempts,
          'locked_until': lockUntil,
          'updated_at': now.toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [userId],
      );
      await db.insert('audit_log', {
        'entity_type': 'user',
        'entity_id': userId,
        'action': 'login_failed',
        'actor_id': userId,
        'details': 'Invalid local credentials',
        'created_at': now.toIso8601String(),
      });
      return null;
    }

    await db.update(
      'app_users',
      {
        'failed_login_attempts': 0,
        'locked_until': null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [userId],
    );
    await db.insert('audit_log', {
      'entity_type': 'user',
      'entity_id': userId,
      'action': 'login_success',
      'actor_id': userId,
      'details': 'Local authentication succeeded',
      'created_at': now.toIso8601String(),
    });
    return UserSession(
      userId: userId,
      username: user['username'] as String,
      displayName: user['display_name'] as String,
    );
  }

  Future<bool> hasPermission(
    UserSession session,
    String permissionKey,
  ) async {
    final db = await _database.database;
    final active = await db.query(
      'app_users',
      columns: ['id'],
      where: 'id=? AND is_active=1',
      whereArgs: [session.userId],
      limit: 1,
    );
    if (active.isEmpty) return false;

    final permissionRows = await db.query(
      'app_permissions',
      columns: ['id'],
      where: 'permission_key=?',
      whereArgs: [permissionKey],
      limit: 1,
    );
    if (permissionRows.isEmpty) return false;
    final permissionId = permissionRows.first['id'] as int;

    // A direct user decision overrides all role-derived decisions.
    final direct = await db.query(
      'user_permissions',
      columns: ['is_allowed'],
      where: 'user_id=? AND permission_id=?',
      whereArgs: [session.userId, permissionId],
      limit: 1,
    );
    if (direct.isNotEmpty) return (direct.first['is_allowed'] as int) == 1;

    // Across multiple roles, an explicit role denial wins over any grant.
    final roleDecisions = await db.rawQuery('''
      SELECT rp.is_allowed
      FROM role_permissions rp
      JOIN user_roles ur ON ur.role_id=rp.role_id
      WHERE ur.user_id=? AND rp.permission_id=?
    ''', [session.userId, permissionId]);
    if (roleDecisions.isEmpty) return false;
    if (roleDecisions.any((row) => (row['is_allowed'] as int) == 0)) {
      return false;
    }
    return roleDecisions.any((row) => (row['is_allowed'] as int) == 1);
  }

  Future<void> setUserPermission({
    required UserSession actor,
    required int targetUserId,
    required String permissionKey,
    required bool allowed,
  }) async {
    if (!await hasPermission(actor, 'permissions.manage')) {
      throw StateError('Not authorized to manage permissions.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final permissions = await txn.query(
        'app_permissions',
        columns: ['id'],
        where: 'permission_key=?',
        whereArgs: [permissionKey],
        limit: 1,
      );
      if (permissions.isEmpty) throw ArgumentError('Unknown permission.');
      final targets = await txn.query(
        'app_users',
        columns: ['id'],
        where: 'id=? AND is_active=1',
        whereArgs: [targetUserId],
        limit: 1,
      );
      if (targets.isEmpty) throw StateError('Target user is not active.');
      final now = DateTime.now().toIso8601String();
      await txn.insert(
        'user_permissions',
        {
          'user_id': targetUserId,
          'permission_id': permissions.first['id'],
          'is_allowed': allowed ? 1 : 0,
          'assigned_by': actor.userId,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('audit_log', {
        'entity_type': 'user_permission',
        'entity_id': targetUserId,
        'action': allowed ? 'permission_granted' : 'permission_denied',
        'actor_id': actor.userId,
        'details': permissionKey,
        'created_at': now,
      });
    });
  }

  Future<void> revokeUserPermission({
    required UserSession actor,
    required int targetUserId,
    required String permissionKey,
  }) async {
    if (!await hasPermission(actor, 'permissions.manage')) {
      throw StateError('Not authorized to manage permissions.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final permissions = await txn.query(
        'app_permissions',
        columns: ['id'],
        where: 'permission_key=?',
        whereArgs: [permissionKey],
        limit: 1,
      );
      if (permissions.isEmpty) throw ArgumentError('Unknown permission.');
      await txn.delete(
        'user_permissions',
        where: 'user_id=? AND permission_id=?',
        whereArgs: [targetUserId, permissions.first['id']],
      );
      await txn.insert('audit_log', {
        'entity_type': 'user_permission',
        'entity_id': targetUserId,
        'action': 'permission_override_removed',
        'actor_id': actor.userId,
        'details': permissionKey,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> setUserActive({
    required UserSession actor,
    required int targetUserId,
    required bool active,
  }) async {
    if (!await hasPermission(actor, 'users.manage')) {
      throw StateError('Not authorized to manage users.');
    }
    if (actor.userId == targetUserId && !active) {
      throw StateError('You cannot disable your own active session.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final changed = await txn.update(
        'app_users',
        {
          'is_active': active ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [targetUserId],
      );
      if (changed != 1) throw StateError('User not found.');
      await txn.insert('audit_log', {
        'entity_type': 'user',
        'entity_id': targetUserId,
        'action': active ? 'user_activated' : 'user_disabled',
        'actor_id': actor.userId,
        'details': 'Account active state changed',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }
}
