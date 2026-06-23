import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/app_role.dart';
import '../../../core/support/support_contact.dart';
import '../../auth/domain/auth_repository.dart';
import 'widgets/form_scaffold.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({
    super.key,
    required this.authRepository,
    required this.onClose,
  });

  final AuthRepository authRepository;
  final VoidCallback onClose;

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _teamController = TextEditingController();
  final _passwordController = TextEditingController();
  AppRole _role = AppRole.technician;
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.text = _temporaryPassword();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _teamController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await widget.authRepository.createUser(
        name: _nameController.text,
        email: _emailController.text,
        temporaryPassword: _passwordController.text,
        role: _role,
        team: _teamController.text.isEmpty ? null : _teamController.text,
      );
      if (!mounted) return;
      await _showCreatedDialog();
      if (mounted) widget.onClose();
    } on FirebaseFunctionsException catch (error) {
      _showError(
        withSupportContact(error.message ?? 'Could not create the user.'),
      );
    } catch (_) {
      _showError(withSupportContact('Could not create the user. Try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const FormHeader(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Add User',
                        subtitle:
                            'Create an account with a temporary password. The user must replace it at first sign-in.',
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (!email.contains('@') ||
                                      !email.contains('.')) {
                                    return 'Enter a valid email.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<AppRole>(
                                initialValue: _role,
                                decoration: const InputDecoration(
                                  labelText: 'Role',
                                  prefixIcon: Icon(Icons.security_outlined),
                                ),
                                items: AppRole.values
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _role = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _teamController,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Team (optional)',
                                  prefixIcon: Icon(Icons.groups_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Temporary password',
                                  prefixIcon: const Icon(Icons.password),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) => (value?.length ?? 0) < 8
                                    ? 'Use at least 8 characters.'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          FormActionBar(
            primaryIcon: Icons.person_add_alt_1,
            primaryLabel: _saving ? 'Creating User' : 'Create User',
            onPrimary: _saving ? null : _submit,
            onCancel: _saving ? null : widget.onClose,
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }

  Future<void> _showCreatedDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('User created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_emailController.text.trim()),
            const SizedBox(height: 12),
            const Text('Temporary password:'),
            SelectableText(
              _passwordController.text,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text('The user must change it after signing in.'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _passwordController.text));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Password'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _temporaryPassword() {
    final value = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'Isdp#${value.substring(value.length - 8)}A1';
  }
}
