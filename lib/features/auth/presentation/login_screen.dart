import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/animated_logo_loader.dart';
import '../../../core/support/support_contact.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _errorMessage = withSupportContact(_authMessage(error)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter your email first.');
      return;
    }

    setState(() {
      _isResettingPassword = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      await _showPasswordResetSent(email);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found' || error.code == 'invalid-email') {
        await _showPasswordResetSent(email);
      } else {
        setState(
          () => _errorMessage = withSupportContact(
            'Could not send the password reset email.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = withSupportContact(
          'Could not send the password reset email.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _showPasswordResetSent(String email) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check your email'),
        content: Text(
          'If $email is registered for Field Service Platform, a secure password reset link has been sent. Open the email and follow the link to create a new password.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildBrandHeader(),
                  const SizedBox(height: 24),
                  _buildLoginPanel(),
                  const SizedBox(height: 20),
                  const Text(
                    'Integrated Service Delivery Platform',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 98,
          height: 98,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.engineering_outlined,
            size: 52,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Field Service Platform',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to manage jobs, site execution, materials, and billing readiness.',
          style: TextStyle(color: AppTheme.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter your email.';
                  }
                  if (!value.contains('@')) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password.';
                  }
                  if (value.length < 6) return 'Use at least 6 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isLoading ? null : _signIn,
                icon: _isLoading
                    ? const AnimatedLogoLoader(size: 24, compact: true)
                    : const Icon(Icons.login),
                label: Text(_isLoading ? 'Signing In' : 'Sign In'),
              ),
              TextButton(
                onPressed: _isLoading || _isResettingPassword
                    ? null
                    : _resetPassword,
                child: Text(
                  _isResettingPassword
                      ? 'Sending reset email...'
                      : 'Forgot password?',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
