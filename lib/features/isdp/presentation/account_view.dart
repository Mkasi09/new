import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        _AccountHeader(name: name, email: email, role: role, team: team),
        const SizedBox(height: 14),
        _SettingsGrid(
          items: [
            _SettingsItem(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Password and account access',
              color: AppTheme.primary,
              onTap: () => _open(
                context,
                _SecuritySettingsScreen(
                  email: email,
                  authRepository: authRepository,
                ),
              ),
            ),
            _SettingsItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Phone alerts and permissions',
              color: AppTheme.warning,
              onTap: () => _open(
                context,
                _NotificationSettingsScreen(userId: userProfile?.uid),
              ),
            ),
            _SettingsItem(
              icon: Icons.support_agent_outlined,
              title: 'Support',
              subtitle: supportContactNumber,
              color: AppTheme.secondary,
              onTap: () => _open(context, const _SupportScreen()),
            ),
            _SettingsItem(
              icon: Icons.tune_outlined,
              title: 'App Settings',
              subtitle: 'Version and sync status',
              color: AppTheme.success,
              onTap: () => _open(context, const _AppSettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Profile Details',
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
        const SizedBox(height: 14),
        _DangerActionCard(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Leave this device signed out',
          onTap: authRepository == null ? null : () => _confirmSignOut(context),
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

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.team,
  });

  final String name;
  final String email;
  final AppRole role;
  final String? team;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandTitle(),
                      const SizedBox(height: 6),
                      Text(
                        email.isEmpty ? 'Signed in user' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
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

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.items});

  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(width: tileWidth, height: 128, child: item),
          ],
        );
      },
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconPill(icon: icon, color: color),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppTheme.muted),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;

    return _SettingsScaffold(
      title: 'Security',
      icon: Icons.lock_outline,
      subtitle: 'Protect account access and manage password recovery.',
      children: [
        _SecurityStatusCard(email: widget.email),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Change Password',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose a password that is hard to guess and unique to this account.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.password_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscureCurrent
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Enter your current password.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscureNew,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscureNew
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Use at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _PasswordChecklist(password: password),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureNew,
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
                        label: Text(_saving ? 'Saving' : 'Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ResetAccessCard(
          email: widget.email,
          sending: _sendingReset,
          enabled:
              widget.email.isNotEmpty &&
              widget.authRepository != null &&
              !_sendingReset,
          onSend: _sendResetEmail,
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.authRepository!.changePasswordWithCurrentPassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _passwordController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Sign in again.')),
      );
      await widget.authRepository!.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'wrong-password' ||
        'invalid-credential' => 'Current password is incorrect.',
        'requires-recent-login' => 'Sign in again, then update your password.',
        _ => 'Could not change password. $supportContactMessage',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const IconPill(
              icon: Icons.verified_user_outlined,
              color: AppTheme.success,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Protected',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isEmpty
                        ? 'Password changes apply to this signed-in account.'
                        : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const StatusChip(label: 'Active', color: AppTheme.success),
          ],
        ),
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final checks = [
      _PasswordCheck('8+ characters', password.length >= 8),
      _PasswordCheck('Upper and lower case', _hasMixedCase(password)),
      _PasswordCheck('Number or symbol', RegExp(r'[\d\W_]').hasMatch(password)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final check in checks)
          _PasswordRequirementChip(label: check.label, met: check.met),
      ],
    );
  }

  static bool _hasMixedCase(String value) {
    return RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value);
  }
}

class _PasswordCheck {
  const _PasswordCheck(this.label, this.met);

  final String label;
  final bool met;
}

class _PasswordRequirementChip extends StatelessWidget {
  const _PasswordRequirementChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppTheme.success : AppTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: met ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: met ? 0.20 : 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetAccessCard extends StatelessWidget {
  const _ResetAccessCard({
    required this.email,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  final String email;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final subtitle = email.isEmpty
        ? 'No email address is available for this account.'
        : 'Send a secure reset link to $email.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const IconPill(
              icon: Icons.mark_email_read_outlined,
              color: AppTheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password Reset',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: enabled ? onSend : null,
              icon: Icon(sending ? Icons.hourglass_empty : Icons.send_outlined),
              label: Text(sending ? 'Sending' : 'Send Link'),
            ),
          ],
        ),
      ),
    );
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
  String? _lastError;
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final statusText = status == null
        ? 'Tap check to register this phone'
        : status.enabled
        ? 'Ready on this phone'
        : _statusDetail(status);

    return _SettingsScaffold(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      subtitle: 'Register this phone for job updates and approval alerts.',
      children: [
        _SectionCard(
          title: 'Device Status',
          children: [
            _InfoRow(
              icon: status?.enabled == true
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              title: 'This Phone',
              subtitle: statusText,
              color: status?.enabled == true ? AppTheme.success : null,
            ),
            if (_lastError != null)
              _InfoRow(
                icon: Icons.error_outline,
                title: 'Last Error',
                subtitle: _lastError!,
              ),
            _NavRow(
              icon: Icons.refresh,
              title: _checking ? 'Checking...' : 'Check Notifications',
              subtitle: 'Allow alerts on this device',
              onTap: _checking || widget.userId == null
                  ? null
                  : _registerThisPhone,
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
      _lastError = status.error == null
          ? null
          : 'Notifications could not be registered. $supportContactMessage';
      _checking = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.enabled
              ? 'Phone notifications are registered with ${status.provider?.toUpperCase() ?? 'push services'}.'
              : 'Notifications are not ready. $supportContactMessage',
        ),
      ),
    );
  }

  String _statusDetail(NotificationRegistrationStatus status) {
    return switch (status.permission.authorizationStatus) {
      AuthorizationStatus.denied => 'Permission denied in phone settings',
      AuthorizationStatus.notDetermined => 'Permission has not been allowed',
      AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
        status.tokenSaved
            ? 'Ready on this phone (${status.provider?.toUpperCase() ?? 'push'})'
            : 'Token was not saved',
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
      subtitle: 'Get help with account access, submissions, and approvals.',
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
      subtitle: 'Application details and cloud sync information.',
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
              subtitle: 'Cloud sync enabled',
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
    required this.subtitle,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(title)),
      body: AppScrollView(
        children: [
          _SettingsHeader(icon: icon, title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconPill(icon: icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(title),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IconPill(icon: icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IconPill(icon: icon, color: color),
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

class _DangerActionCard extends StatelessWidget {
  const _DangerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: _NavRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        danger: true,
        onTap: onTap,
      ),
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
