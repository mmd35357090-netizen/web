import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../widgets.dart';
import 'auth_screens.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      toast(context, 'Please enter your email and password');
      return;
    }
    setState(() => _busy = true);
    final r = await Api.login(email, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok && r.data is Map && r.data['auth_key'] != null) {
      await Api.saveToken(r.data['auth_key'].toString());
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } else if (r.data is Map && r.data['token'] != null) {
      toast(context, 'Please verify your account in the mobile app first.');
    } else {
      toast(context, r.message.isNotEmpty ? r.message : 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.forum_rounded, size: 52, color: color),
                    const SizedBox(height: 10),
                    Text(AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Log in to continue',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : const Text('Log in', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Forgot password?'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
