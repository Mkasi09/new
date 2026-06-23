import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/support/support_contact.dart';
import '../../auth/domain/auth_repository.dart';
import 'widgets/common.dart';

class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.role,
    this.userProfile,
    this.authRepository,
  });

  final AppRole role;
  final AppUserProfile? userProfile;
  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    final name = userProfile?.name.trim().isNotEmpty == true
        ? userProfile!.name.trim()
        : 'ISDP User';
    final email = userProfile?.email.trim() ?? '';
    final team = userProfile?.team?.trim();

    return AppScrollView(
      children: [
        _BrandAccountHeader(name: name, role: role, team: team),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Profile',
          children: [
            _InfoRow(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: email.isNotEmpty ? email : 'Not available',
            ),
            _InfoRow(
              icon: Icons.security_outlined,
              title: 'Access Level',
              subtitle: role.label,
            ),
            if (team?.isNotEmpty == true)
              _InfoRow(
                icon: Icons.groups_outlined,
                title: 'Team',
                subtitle: team!,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Settings',
          children: [
            _NavRow(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Change password and reset access',
              onTap: () => _open(
                context,
                _SecuritySettingsScreen(
                  email: email,
                  authRepository: authRepository,
                ),
              ),
            ),
            _NavRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Phone alerts for work updates',
              onTap: () => _open(
                context,
                _NotificationSettingsScreen(userId: userProfile?.uid),
              ),
            ),
            _NavRow(
              icon: Icons.support_agent_outlined,
              title: 'Support',
              subtitle: supportContactNumber,
              onTap: () => _open(context, const _SupportScreen()),
            ),
            _NavRow(
              icon: Icons.tune_outlined,
              title: 'App Settings',
              subtitle: 'Version, sync, and app information',
              onTap: () => _open(context, const _AppSettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: _NavRow(
            icon: Icons.logout,
            title: 'Sign Out',
            subtitle: 'Leave this device signed out',
            danger: true,
            onTap: authRepository == null
                ? null
                : () => _confirmSignOut(context),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await authRepository!.signOut();
  }
}

class _BrandAccountHeader extends StatelessWidget {
  const _BrandAccountHeader({
    required this.name,
    required this.role,
    required this.team,
  });

  final String name;
  final AppRole role;
  final String? team;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Image.asset('assets/logo1.png'),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BrandTitle(),
                      SizedBox(height: 4),
                      Text(
                        'Integrated Service Delivery Platform',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.primary,
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                            label: role.label,
                            color: AppTheme.primary,
                          ),
                          if (team?.isNotEmpty == true)
                            InfoChip(icon: Icons.groups_outlined, label: team!),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecuritySettingsScreen extends StatefulWidget {
  const _SecuritySettingsScreen({
    required this.email,
    required this.authRepository,
  });

  final String email;
  final AuthRepository? authRepository;

  @override
  State<_SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<_SecuritySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Security',
      icon: Icons.lock_outline,
      children: [
        _SectionCard(
          title: 'Change Password',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving || widget.authRepository == null
                            ? null
                            : _changePassword,
                        icon: Icon(
                          _saving ? Icons.hourglass_empty : Icons.save,
                        ),
                        label: Text(_saving ? 'Saving' : 'Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Reset Access',
          children: [
            _NavRow(
              icon: Icons.mark_email_read_outlined,
              title: 'Send Reset Email',
              subtitle: widget.email.isEmpty
                  ? 'Email is not available'
                  : 'Send link to ${widget.email}',
              onTap:
                  widget.email.isEmpty ||
                      widget.authRepository == null ||
                      _sendingReset
                  ? null
                  : _sendResetEmail,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.authRepository!.changePassword(_passwordController.text);
      if (!mounted) return;
      _passwordController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Sign in again.')),
      );
      await widget.authRepository!.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not change password. $supportContactMessage'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendResetEmail() async {
    setState(() => _sendingReset = true);
    try {
      await widget.authRepository!.sendPasswordResetEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to ${widget.email}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send password reset link. $supportContactMessage',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }
}

class _NotificationSettingsScreen extends StatefulWidget {
  const _NotificationSettingsScreen({required this.userId});

  final String? userId;

  @override
  State<_NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<_NotificationSettingsScreen> {
  NotificationRegistrationStatus? _status;
  bool _checking = false;
  bool _sendingTest = false;

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusText = status == null
        ? 'Tap check to register this phone'
        : status.enabled
        ? 'Ready on this phone'
        : _statusDetail(status);
    final tokenText = status?.token == null
        ? null
        : 'Token saved: ${status!.token!.substring(0, 12)}...';

    return _SettingsScaffold(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        _SectionCard(
          title: 'Device Status',
          children: [
            _InfoRow(
              icon: status?.enabled == true
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              title: 'This Phone',
              subtitle: tokenText == null
                  ? statusText
                  : '$statusText\n$tokenText',
            ),
            _NavRow(
              icon: Icons.refresh,
              title: _checking ? 'Checking...' : 'Check Notifications',
              subtitle: 'Request permission and save this phone token',
              onTap: _checking || widget.userId == null
                  ? null
                  : _registerThisPhone,
            ),
            _NavRow(
              icon: Icons.notification_add_outlined,
              title: _sendingTest ? 'Sending...' : 'Send Test Notification',
              subtitle: 'Send a real push notification to this phone',
              onTap: _sendingTest ? null : _sendTestNotification,
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Phone Alerts',
          children: [
            _InfoRow(
              icon: Icons.assignment_ind_outlined,
              title: 'Assignments',
              subtitle: 'Alerts when work is assigned or dispatched',
            ),
            _InfoRow(
              icon: Icons.done_all_outlined,
              title: 'Approvals',
              subtitle: 'Alerts when jobs are submitted or approved',
            ),
            _InfoRow(
              icon: Icons.report_problem_outlined,
              title: 'Issues',
              subtitle: 'Alerts when field issues are reported',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: 'Phone Setting',
          children: [
            _InfoRow(
              icon: Icons.phone_android_outlined,
              title: 'Permission',
              subtitle: 'Allow notifications in your phone settings',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _registerThisPhone() async {
    setState(() => _checking = true);
    final status = await NotificationService.registerCurrentDevice(
      widget.userId!,
      force: true,
    );
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.enabled
              ? 'Phone notifications are registered.'
              : 'Notifications are not ready. $supportContactMessage',
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    setState(() => _sendingTest = true);
    try {
      if (widget.userId != null) {
        final status = await NotificationService.registerCurrentDevice(
          widget.userId!,
          force: true,
        );
        if (mounted) setState(() => _status = status);
      }
      await NotificationService.sendTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent. Check this phone.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send test notification. $supportContactMessage',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  String _statusDetail(NotificationRegistrationStatus status) {
    return switch (status.permission.authorizationStatus) {
      AuthorizationStatus.denied => 'Permission denied in phone settings',
      AuthorizationStatus.notDetermined => 'Permission has not been allowed',
      AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
        status.tokenSaved ? 'Ready on this phone' : 'Token was not saved',
    };
  }
}

class _SupportScreen extends StatelessWidget {
  const _SupportScreen();

  @override
  Widget build(BuildContext context) {
    return const _SettingsScaffold(
      title: 'Support',
      icon: Icons.support_agent_outlined,
      children: [
        _SectionCard(
          title: 'Contact',
          children: [
            _InfoRow(
              icon: Icons.phone_outlined,
              title: 'Support Number',
              subtitle: supportContactNumber,
            ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              title: 'Support Hours',
              subtitle: 'Business hours for normal support',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: 'Help With',
          children: [
            _InfoRow(
              icon: Icons.login_outlined,
              title: 'Login and Passwords',
              subtitle: 'Account access and reset help',
            ),
            _InfoRow(
              icon: Icons.cloud_upload_outlined,
              title: 'Evidence Uploads',
              subtitle: 'Photo, sync, and submission issues',
            ),
            _InfoRow(
              icon: Icons.fact_check_outlined,
              title: 'Approvals',
              subtitle: 'Review, approval, and workflow support',
            ),
          ],
        ),
      ],
    );
  }
}

class _AppSettingsScreen extends StatelessWidget {
  const _AppSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'App Settings',
      icon: Icons.tune_outlined,
      children: [
        const _SectionCard(
          title: 'Application',
          children: [
            _InfoRow(
              icon: Icons.apps_outlined,
              title: 'App',
              subtitle: 'PHEPHA MV ISDP',
            ),
            _InfoRow(
              icon: Icons.new_releases_outlined,
              title: 'Version',
              subtitle: '1.0.0',
            ),
            _InfoRow(
              icon: Icons.cloud_done_outlined,
              title: 'Sync',
              subtitle: 'Firebase cloud sync enabled',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: _NavRow(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'View app information',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'PHEPHA MV ISDP',
              applicationVersion: '1.0.0',
              applicationIcon: Image.asset(
                'assets/logo1.png',
                width: 48,
                height: 48,
              ),
              children: const [
                Text(
                  'Integrated Service Delivery Platform for field service workflows.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(title)),
      body: AppScrollView(
        children: [
          Row(
            children: [
              IconPill(icon: icon, color: AppTheme.primary),
              const SizedBox(width: 12),
              SectionTitle(title),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppTheme.danger
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      enabled: onTap != null,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: danger ? color : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'PHEPHA MV '),
          TextSpan(
            text: 'ISDP',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
      style: const TextStyle(
        color: AppTheme.ink,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'IS';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
