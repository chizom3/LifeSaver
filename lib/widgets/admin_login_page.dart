import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_auth_service.dart';

class AdminLoginPage extends StatefulWidget {
  final AdminAuthService authService;
  final VoidCallback onSignedIn;

  const AdminLoginPage({
    super.key,
    required this.authService,
    required this.onSignedIn,
  });

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Sign In')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.admin_panel_settings, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Admin access required',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in with an approved Firebase admin account to review reports and manage hospital verification data.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Admin email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: _isSigningIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_isSigningIn ? 'Signing in...' : 'Sign in'),
              onPressed: _isSigningIn ? null : _signIn,
            ),
            const SizedBox(height: 12),
            const Text(
              'Admin users must have the Firebase admin custom claim. Normal users do not need to sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      await widget.authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Close the login page before the dashboard is pushed on top.
      Navigator.pop(context);
      widget.onSignedIn();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not sign in.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not sign in.')));
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }
}
