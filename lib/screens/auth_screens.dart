import 'package:flutter/material.dart';
import '../api.dart';
import '../config.dart';
import '../widgets.dart';
import 'home_shell.dart';

Map<String, dynamic> _device() => {
      'device_type': '3',
      'device_token': '',
      'device_token_voip_ios': '',
      'device_model': 'web',
      'device_os_version': 'web',
      'device_app_release_version': '1.0.0',
      'login_ip': '',
      'login_location': '',
    };

Widget _card(BuildContext context, String title, List<Widget> children) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    ),
  );
}

InputDecoration _dec(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

Future<void> _enter(BuildContext context, String authKey) async {
  await Api.saveToken(authKey);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()), (r) => false);
}

// ------------------------------------------------------------ register
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    final name = _name.text.trim();
    final username = _username.text.trim().replaceAll(' ', '');
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || username.isEmpty || email.isEmpty || password.length < 6) {
      toast(context, 'Fill every field. Password needs at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    final r = await Api.post('users/register', {
      'username': username,
      'name': name,
      'email': email,
      'password': password,
      'role': '3',
      ..._device(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    final token = r.data is Map ? r.data['token']?.toString() : null;
    if (r.ok && token != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(token: token, email: email, forgot: false)));
    } else {
      toast(context, r.message.isEmpty ? 'Could not create the account' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _card(context, 'Create account', [
      Text('Join ${AppConfig.appName}',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      TextField(controller: _name, decoration: _dec('Full name', Icons.person_outline_rounded)),
      const SizedBox(height: 12),
      TextField(controller: _username, decoration: _dec('Username', Icons.alternate_email_rounded)),
      const SizedBox(height: 12),
      TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _dec('Email', Icons.mail_outline_rounded)),
      const SizedBox(height: 12),
      TextField(
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _go(),
          decoration: _dec('Password', Icons.lock_outline_rounded)),
      const SizedBox(height: 20),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : _go,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------ OTP (register + forgot password)
class OtpScreen extends StatefulWidget {
  final String token;
  final String email;
  final bool forgot;
  const OtpScreen({super.key, required this.token, required this.email, required this.forgot});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  bool _busy = false;
  late String _token = widget.token;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otp.text.trim();
    if (otp.length < 4) {
      toast(context, 'Enter the code we emailed you');
      return;
    }
    setState(() => _busy = true);
    if (widget.forgot) {
      final r = await Api.post('users/forgot-password-verify-otp', {'otp': otp, 'token': _token});
      if (!mounted) return;
      setState(() => _busy = false);
      final t = r.data is Map ? r.data['token']?.toString() : null;
      if (r.ok && t != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NewPasswordScreen(token: t)));
      } else {
        toast(context, r.message.isEmpty ? 'Wrong code' : r.message);
      }
    } else {
      final r = await Api.post('users/verify-registration-otp', {'otp': otp, 'token': _token, ..._device()});
      if (!mounted) return;
      setState(() => _busy = false);
      final key = r.data is Map ? r.data['auth_key']?.toString() : null;
      if (r.ok && key != null) {
        await _enter(context, key);
      } else {
        toast(context, r.message.isEmpty ? 'Wrong code' : r.message);
      }
    }
  }

  Future<void> _resend() async {
    final r = await Api.post('users/resend-otp', {'token': _token});
    if (mounted) toast(context, r.ok ? 'Code sent again' : (r.message.isEmpty ? 'Could not resend' : r.message));
  }

  @override
  Widget build(BuildContext context) {
    return _card(context, 'Verify', [
      Text('We sent a code to ${widget.email}',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 18),
      TextField(
        controller: _otp,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 8,
        onSubmitted: (_) => _verify(),
        style: const TextStyle(fontSize: 24, letterSpacing: 6),
        decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ),
      TextButton(onPressed: _resend, child: const Text('Send the code again')),
    ]);
  }
}

// ------------------------------------------------------------ forgot password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      toast(context, 'Enter your email');
      return;
    }
    setState(() => _busy = true);
    final r = await Api.post('users/forgot-password-request',
        {'verification_with': '1', 'email': email, 'country_code': '', 'phone': ''});
    if (!mounted) return;
    setState(() => _busy = false);
    final t = r.data is Map ? r.data['token']?.toString() : null;
    if (r.ok && t != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => OtpScreen(token: t, email: email, forgot: true)));
    } else {
      toast(context, r.message.isEmpty ? 'Could not send the code' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _card(context, 'Forgot password', [
      const Text("Enter your email and we'll send you a code.", textAlign: TextAlign.center),
      const SizedBox(height: 18),
      TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _go(),
          decoration: _dec('Email', Icons.mail_outline_rounded)),
      const SizedBox(height: 18),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : _go,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send code'),
        ),
      ),
    ]);
  }
}

class NewPasswordScreen extends StatefulWidget {
  final String token;
  const NewPasswordScreen({super.key, required this.token});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_pass.text.length < 6) {
      toast(context, 'Password needs at least 6 characters');
      return;
    }
    setState(() => _busy = true);
    final r = await Api.post('users/set-new-password', {'token': widget.token, 'password': _pass.text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      toast(context, 'Password changed. Please log in.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      toast(context, r.message.isEmpty ? 'Could not change the password' : r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _card(context, 'New password', [
      TextField(
          controller: _pass,
          obscureText: true,
          onSubmitted: (_) => _go(),
          decoration: _dec('New password', Icons.lock_outline_rounded)),
      const SizedBox(height: 18),
      SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : _go,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save password'),
        ),
      ),
    ]);
  }
}
