import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'data/access_control.dart';
import 'data/wms_database.dart';

typedef AuthenticatedHomeBuilder = Widget Function(
  Map<String, Object?> user,
  VoidCallback onLogout,
);

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.language,
    required this.onLanguage,
    required this.homeBuilder,
  });

  final String language;
  final ValueChanged<String> onLanguage;
  final AuthenticatedHomeBuilder homeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final WmsDatabase db = WmsDatabase.instance;
  Map<String, Object?>? user;
  bool loading = true;
  bool hasUsers = true;
  bool busy = false;
  String? error;
  final username = TextEditingController();
  final fullName = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  String tr(String ar, String en, String fr) =>
      widget.language == 'ar' ? ar : (widget.language == 'fr' ? fr : en);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final restored = await db.restoreUserSession();
      final anyUsers = await db.hasAnyUsers();
      if (!mounted) return;
      setState(() {
        user = restored;
        hasUsers = anyUsers;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final result = await db.authenticateUser(
        username: username.text,
        password: password.text,
      );
      if (result == null) {
        setState(() => error = tr(
          'اسم المستخدم أو كلمة المرور غير صحيحة، أو الحساب معطل.',
          'Invalid username/password or the account is disabled.',
          'Identifiant/mot de passe incorrect ou compte désactivé.',
        ));
      } else if (mounted) {
        setState(() => user = result);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createFirstAdmin() async {
    if (busy) return;
    if (fullName.text.trim().isEmpty || username.text.trim().isEmpty ||
        password.text.length < 8 || password.text != confirmPassword.text) {
      setState(() => error = tr(
        'أدخل الاسم واسم الدخول، واجعل كلمة المرور 8 أحرف على الأقل وتأكد من تطابقها.',
        'Enter a name and username, use at least 8 password characters, and confirm the same password.',
        'Saisissez le nom et l’identifiant, utilisez au moins 8 caractères et confirmez le même mot de passe.',
      ));
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      if (await db.hasAnyUsers()) {
        setState(() => hasUsers = true);
        return;
      }
      final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
      final hash = sha256.convert(utf8.encode('$salt:${password.text}')).toString();
      await db.createUser(
        username: username.text,
        fullName: fullName.text,
        passwordHash: hash,
        passwordSalt: salt,
      );
      final result = await db.authenticateUser(
        username: username.text,
        password: password.text,
      );
      if (result == null) throw StateError('Initial administrator account could not be authenticated');
      if (mounted) setState(() { user = result; hasUsers = true; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    await db.logoutUser();
    if (mounted) setState(() {
      user = null;
      hasUsers = true;
      password.clear();
      error = null;
    });
  }

  @override
  void dispose() {
    username.dispose();
    fullName.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activeUser = user;
    if (activeUser != null) return widget.homeBuilder(activeUser, _logout);

    final title = hasUsers
        ? tr('تسجيل الدخول إلى نعيم سوفت', 'Sign in to NaeemSoft', 'Connexion à NaeemSoft')
        : tr('إنشاء حساب المسؤول الأول', 'Create the first administrator account', 'Créer le premier compte administrateur');

    return Directionality(
      textDirection: widget.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text('NaeemSoft WMS'),
          actions: [
            PopupMenuButton<String>(
              onSelected: widget.onLanguage,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ar', child: Text('العربية')),
                PopupMenuItem(value: 'en', child: Text('English')),
                PopupMenuItem(value: 'fr', child: Text('Français')),
              ],
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.warehouse_outlined, size: 54),
                      const SizedBox(height: 16),
                      Text(title, textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 22),
                      if (!hasUsers) ...[
                        TextField(controller: fullName,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(labelText: tr('الاسم الكامل','Full name','Nom complet'))),
                      ],
                      TextField(controller: username,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(labelText: tr('اسم المستخدم','Username','Nom d’utilisateur'))),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true,
                        textInputAction: hasUsers ? TextInputAction.done : TextInputAction.next,
                        autofillHints: [hasUsers ? AutofillHints.password : AutofillHints.newPassword],
                        onSubmitted: (_) { if (hasUsers) _login(); },
                        decoration: InputDecoration(labelText: tr('كلمة المرور','Password','Mot de passe'))),
                      if (!hasUsers) ...[
                        const SizedBox(height: 12),
                        TextField(controller: confirmPassword, obscureText: true,
                          decoration: InputDecoration(labelText: tr('تأكيد كلمة المرور','Confirm password','Confirmer le mot de passe'))),
                        const SizedBox(height: 8),
                        Text(tr(
                          'سيُنشأ الحساب الأول دون صلاحيات سرية للمنافسين. تُمنح الصلاحيات لاحقاً بشكل صريح.',
                          'The first account receives no confidential competitor access. Permissions are assigned explicitly later.',
                          'Le premier compte ne reçoit aucun accès confidentiel aux concurrents. Les autorisations seront attribuées explicitement.',
                        ), style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: busy ? null : (hasUsers ? _login : _createFirstAdmin),
                        child: busy
                          ? const SizedBox(height: 18,width: 18,child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(hasUsers
                              ? tr('دخول','Sign in','Se connecter')
                              : tr('إنشاء الحساب','Create account','Créer le compte')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
