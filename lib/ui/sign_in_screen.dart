import 'package:flutter/material.dart';

import '../quiz_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});
  final QuizController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final hasError = c.phase == Phase.authError && c.message.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Science Signal B')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Use a Firebase test account. Your identity decides where '
                'your score is stored.'),
            const SizedBox(height: 24),
            TextField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              onSubmitted: (_) => c.signIn(_email.text, _password.text),
            ),
            const SizedBox(height: 16),
            if (hasError)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c.message,
                          key: const Key('authError'),
                          style: TextStyle(color: Colors.red.shade900)),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              key: const Key('signInButton'),
              onPressed: c.signingIn ? null : () => c.signIn(_email.text, _password.text),
              icon: c.signingIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(c.signingIn ? 'Signing in...' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
