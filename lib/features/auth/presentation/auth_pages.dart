import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_app/core/services/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthSession.instance.login(
      _username.text,
      _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) context.go('/');
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'تسجيل الدخول',
    subtitle: 'أدخل بيانات المستخدم للمتابعة إلى برنامج صفو',
    children: [
      _AuthField(
        controller: _username,
        label: 'اسم المستخدم',
        icon: Icons.person_outline,
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 14),
      _AuthField(
        controller: _password,
        label: 'كلمة المرور',
        icon: Icons.lock_outline,
        obscure: true,
        onSubmitted: (_) => _submit(),
      ),
      if (_error != null) ...[const SizedBox(height: 12), _AuthError(_error!)],
      const SizedBox(height: 22),
      _AuthButton(label: 'دخول', busy: _busy, onPressed: _submit),
    ],
  );
}

class InitialAdminSetupPage extends StatefulWidget {
  const InitialAdminSetupPage({super.key});

  @override
  State<InitialAdminSetupPage> createState() => _InitialAdminSetupPageState();
}

class _InitialAdminSetupPageState extends State<InitialAdminSetupPage> {
  final _displayName = TextEditingController(text: 'مدير النظام');
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_password.text != _confirm.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthSession.instance.createFirstAdmin(
      username: _username.text,
      displayName: _displayName.text,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) context.go('/login');
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'إنشاء حساب المدير',
    subtitle: 'هذه الخطوة مطلوبة مرة واحدة على هذا الجهاز',
    children: [
      _AuthField(
        controller: _displayName,
        label: 'الاسم الظاهر',
        icon: Icons.badge_outlined,
      ),
      const SizedBox(height: 12),
      _AuthField(
        controller: _username,
        label: 'اسم المستخدم',
        icon: Icons.person_outline,
      ),
      const SizedBox(height: 12),
      _AuthField(
        controller: _password,
        label: 'كلمة المرور (8 أحرف على الأقل)',
        icon: Icons.lock_outline,
        obscure: true,
      ),
      const SizedBox(height: 12),
      _AuthField(
        controller: _confirm,
        label: 'تأكيد كلمة المرور',
        icon: Icons.lock_reset_outlined,
        obscure: true,
        onSubmitted: (_) => _create(),
      ),
      if (_error != null) ...[const SizedBox(height: 12), _AuthError(_error!)],
      const SizedBox(height: 20),
      _AuthButton(
        label: 'إنشاء المدير والمتابعة',
        busy: _busy,
        onPressed: _create,
      ),
      const SizedBox(height: 10),
      const Text(
        'لا توجد كلمة مرور افتراضية. احفظ بيانات المدير في مكان آمن.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xFF67717A)),
      ),
    ],
  );
}

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'لا توجد صلاحية',
    subtitle: 'حسابك لا يملك صلاحية فتح هذه الصفحة.',
    children: [
      const Icon(
        Icons.no_accounts_outlined,
        size: 44,
        color: Color(0xFFCF4939),
      ),
      const SizedBox(height: 20),
      _AuthButton(label: 'العودة للرئيسية', onPressed: () => context.go('/')),
    ],
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/page_background.png', fit: BoxFit.cover),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/logo.png',
                      width: 74,
                      height: 74,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.store,
                        size: 64,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    textInputAction: obscure ? TextInputAction.done : TextInputAction.next,
    onSubmitted: onSubmitted,
    textAlign: TextAlign.right,
    style: const TextStyle(color: Color(0xFF202124), fontSize: 14),
    cursorColor: const Color(0xFF4285F4),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF5F6368)),
      floatingLabelStyle: const TextStyle(color: Color(0xFF1A73E8)),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF5F6368)),
      filled: true,
      fillColor: const Color(0xFFF7F8F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFD0D5D9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF4285F4), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
  );
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 44,
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4285F4),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      child: busy
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _AuthError extends StatelessWidget {
  const _AuthError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    color: const Color(0xFFFFE7E5),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
      textAlign: TextAlign.center,
    ),
  );
}
