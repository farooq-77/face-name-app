import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/primary_button.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      _message('Enter a valid email and a password of at least 6 characters.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_register) {
        await _auth.registerEmail(_email.text, _password.text, _name.text);
      } else {
        await _auth.signInEmail(_email.text, _password.text);
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? e.code);
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      _message('Enter your email first.');
      return;
    }
    try {
      await _auth.sendPasswordReset(_email.text);
      _message('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? e.code);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_register ? 'Create account' : 'Email login')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_register) ...[
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _register ? 'Create account' : 'Sign in',
            loading: _loading,
            onPressed: _submit,
          ),
          if (!_register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _reset,
                child: const Text('Forgot password?'),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() => _register = !_register),
            child: Text(
              _register
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ),
    );
  }
}
