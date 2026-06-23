import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

const _firebaseApiKey = 'AIzaSyD0pYM5_xXEaYhtRqzi4vpPAGhNDVEBKYA';
const _firebaseProjectId = 'magzmotron-5ae93';
const _supportContactNumber = '0791762956';
const _supportContactMessage = 'Contact $_supportContactNumber.';

void main() {
  runApp(const IsdpAdminApp());
}

class IsdpAdminApp extends StatelessWidget {
  const IsdpAdminApp({super.key, this.repository});

  final AdminRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PHEPHA MV ISDP Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.surface,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        useMaterial3: true,
      ),
      home: AdminAuthGate(repository: repository ?? RestAdminRepository()),
    );
  }
}

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key, required this.repository});

  final AdminRepository repository;

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  AuthSession? _session;

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return LoginPage(
        repository: widget.repository,
        onSignedIn: (value) => setState(() => _session = value),
      );
    }

    return AdminDesktopShell(
      repository: widget.repository,
      session: session,
      onSignOut: () => setState(() => _session = null),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.repository,
    required this.onSignedIn,
  });

  final AdminRepository repository;
  final ValueChanged<AuthSession> onSignedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF7F7F7)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const _BrandLogo(size: 104, showBackground: true),
                  const SizedBox(height: 18),
                  const _BrandName(fontSize: 28, suffix: ' Admin'),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to manage jobs, teams, acceptance, and billing readiness.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
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
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return 'Enter your email.';
                                if (!email.contains('@')) {
                                  return 'Enter a valid email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() => _obscure = !_obscure);
                                  },
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password.';
                                }
                                if (value.length < 6) {
                                  return 'Use at least 6 characters.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _signIn(),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _signIn,
                              icon: _isLoading
                                  ? const _AnimatedLogoLoader(
                                      size: 24,
                                      compact: true,
                                    )
                                  : const Icon(Icons.login),
                              label: Text(
                                _isLoading ? 'Signing in' : 'Sign in',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _InlineMessage(message: _error!, isError: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await widget.repository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      widget.onSignedIn(session);
    } catch (error) {
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class AdminDesktopShell extends StatefulWidget {
  const AdminDesktopShell({
    super.key,
    required this.repository,
    required this.session,
    required this.onSignOut,
  });

  final AdminRepository repository;
  final AuthSession session;
  final VoidCallback onSignOut;

  @override
  State<AdminDesktopShell> createState() => _AdminDesktopShellState();
}

class _AdminDesktopShellState extends State<AdminDesktopShell> {
  var _section = AdminSection.dashboard;
  var _orders = <WorkOrder>[];
  var _isLoading = true;
  var _isSyncing = false;
  String _search = '';
  String _status = 'All';
  WorkOrder? _selectedOrder;
  final List<_AdminNotification> _notifications = [];
  var _technicians = <AdminUserProfile>[];
  var _isFetching = false;
  var _refreshQueued = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadTechnicians();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _loadOrders());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: _section,
            userEmail: widget.session.email,
            onSelected: (section) => setState(() {
              _section = section;
              if (section != AdminSection.workOrders) _selectedOrder = null;
            }),
            onSignOut: widget.onSignOut,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _selectedOrder == null
                      ? _section.label
                      : 'Work order details',
                  isSyncing: _isSyncing,
                  onRefresh: _loadOrders,
                  onCreate: _showCreateJobDialog,
                  notificationCount: _notifications
                      .where((item) => !item.read)
                      .length,
                  onNotifications: _showNotifications,
                  onBack: _selectedOrder == null
                      ? null
                      : () => setState(() => _selectedOrder = null),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: _AnimatedLogoLoader(
                            size: 126,
                            label: 'Loading company data...',
                          ),
                        )
                      : _buildSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    return switch (_section) {
      AdminSection.dashboard => DashboardView(
        orders: _orders,
        onOpen: _openOrder,
        onCreate: _showCreateJobDialog,
        onViewOrders: _showOrders,
      ),
      AdminSection.workOrders =>
        _selectedOrder == null
            ? WorkOrdersView(
                orders: _filteredOrders(),
                search: _search,
                status: _status,
                onSearchChanged: (value) => setState(() => _search = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onOpen: _openOrder,
              )
            : OrderDetailView(
                order: _selectedOrder!,
                onBack: () => setState(() => _selectedOrder = null),
                onAction: _performAction,
                onAssign: () => _openAssign(_selectedOrder!),
                onShowQr: () => _showQrDialog(_selectedOrder!),
                onDelete: () => _confirmDeleteOrder(_selectedOrder!),
              ),
      AdminSection.teams => TeamsView(
        orders: _orders,
        onAssign: _openAssign,
        onOpen: _openOrder,
      ),
      AdminSection.acceptance => AcceptanceView(
        orders: _orders,
        onApprove: (order) => _performAction(order, OrderAction.approve),
        onOpen: _openOrder,
      ),
      AdminSection.analytics => AnalyticsView(orders: _orders),
    };
  }

  List<WorkOrder> _filteredOrders() {
    final query = _search.toLowerCase();
    return _orders.where((order) {
      final matchesStatus = switch (_status) {
        'All' => true,
        'Open' => order.status != 'Approved',
        'Due soon' => order.isOpenDueSoon,
        _ => order.status == _status,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return [
        order.id,
        order.site,
        order.address,
        order.scope,
        order.status,
        order.sla,
        order.supervisor ?? '',
        order.technicianLabel ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  void _openOrder(WorkOrder order) {
    setState(() {
      _section = AdminSection.workOrders;
      _selectedOrder = order;
    });
  }

  void _showOrders(String? status) {
    setState(() {
      _section = AdminSection.workOrders;
      _selectedOrder = null;
      _status = status ?? 'All';
    });
  }

  Future<void> _loadOrders() async {
    if (_isFetching) {
      _refreshQueued = true;
      return;
    }

    _isFetching = true;
    setState(() {
      _isSyncing = true;
      if (_orders.isEmpty) _isLoading = true;
    });
    try {
      final orders = await widget.repository.fetchWorkOrders(widget.session);
      if (!mounted) return;
      final updates = _orderUpdates(_orders, orders);
      setState(() {
        _orders = orders;
        _notifications.insertAll(0, updates);
        if (_notifications.length > 30) {
          _notifications.removeRange(30, _notifications.length);
        }
        _selectedOrder = _selectedOrder == null
            ? null
            : _findOrder(_selectedOrder!.id, orders);
      });
    } catch (error) {
      // Keep the last successful view visible when a background refresh fails.
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(_loadOrders());
      }
    }
  }

  Future<void> _loadTechnicians() async {
    try {
      final technicians = await widget.repository.fetchTechnicians(
        widget.session,
      );
      if (!mounted) return;
      setState(() => _technicians = technicians);
    } catch (_) {
      if (!mounted) return;
      setState(() => _technicians = const []);
    }
  }

  List<_AdminNotification> _orderUpdates(
    List<WorkOrder> previous,
    List<WorkOrder> current,
  ) {
    if (previous.isEmpty) return const [];
    final before = {for (final order in previous) order.id: order};
    final updates = <_AdminNotification>[];
    for (final order in current) {
      final old = before[order.id];
      if (old == null) {
        updates.add(
          _AdminNotification(
            orderId: order.id,
            title: 'New work order',
            message: '${order.site} was added to the operational queue.',
            createdAt: DateTime.now(),
            type: _AdminNotificationType.assignment,
          ),
        );
      } else if (old.issueReport != order.issueReport &&
          order.issueReport?.trim().isNotEmpty == true) {
        updates.add(
          _AdminNotification(
            orderId: order.id,
            title: 'Technician issue reported',
            message: '${order.site}: ${order.issueReport!.trim()}',
            createdAt: DateTime.now(),
            type: _AdminNotificationType.issue,
          ),
        );
      } else if (old.status != order.status) {
        updates.add(_adminStatusNotification(order));
      } else if (old.customerSignature != order.customerSignature &&
          order.customerSignature?.isNotEmpty == true) {
        updates.add(
          _AdminNotification(
            orderId: order.id,
            title: 'Customer sign-off received',
            message: '${order.site} has a completed customer signature.',
            createdAt: DateTime.now(),
            type: _AdminNotificationType.success,
          ),
        );
      }
    }
    return updates;
  }

  Future<void> _showNotifications() async {
    final unreadNotifications = _notifications
        .where((item) => !item.read)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
          title: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Activity Centre'),
                    SizedBox(height: 3),
                    Text(
                      'Unread operational updates and required actions',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadNotifications.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final item in _notifications) {
                        item.read = true;
                      }
                    });
                    setDialogState(() {});
                  },
                  child: const Text('Mark all read'),
                ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            height: 520,
            child: unreadNotifications.isEmpty
                ? const _AdminNotificationEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: unreadNotifications.length,
                    itemBuilder: (context, index) {
                      final item = unreadNotifications[index];
                      return _AdminNotificationCard(
                        notification: item,
                        onTap: () {
                          setState(() => item.read = true);
                          Navigator.pop(dialogContext);
                          final order = _findOrder(item.orderId, _orders);
                          if (order != null) _openOrder(order);
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  _AdminNotification _adminStatusNotification(WorkOrder order) {
    final type = switch (order.status) {
      'Submitted' => _AdminNotificationType.action,
      'Approved' => _AdminNotificationType.success,
      'On Site' || 'Dispatched' => _AdminNotificationType.progress,
      _ => _AdminNotificationType.info,
    };
    final title = switch (order.status) {
      'Submitted' => 'Approval required',
      'Approved' => 'Job approved',
      'On Site' => 'Technician arrived on site',
      'Dispatched' => 'Technician dispatched',
      _ => 'Job status updated',
    };
    return _AdminNotification(
      orderId: order.id,
      title: title,
      message: '${order.site} is now ${order.status.toLowerCase()}.',
      createdAt: DateTime.now(),
      type: type,
    );
  }

  Future<void> _showCreateJobDialog() async {
    final created = await showDialog<WorkOrder>(
      context: context,
      builder: (context) => const CreateJobDialog(),
    );
    if (created == null) return;

    await _runMutation(
      () => widget.repository.createWorkOrder(widget.session, created),
      success: null,
    );
  }

  Future<void> _showQrDialog(WorkOrder order) {
    return showDialog<void>(
      context: context,
      builder: (context) => JobQrDialog(order: order),
    );
  }

  Future<void> _confirmDeleteOrder(WorkOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text(
          'Delete ${order.id} for ${order.site}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      () => widget.repository.deleteWorkOrder(widget.session, order),
      success: '${order.id} deleted.',
    );
    if (!mounted) return;
    setState(() {
      _orders = _orders.where((candidate) => candidate.id != order.id).toList();
      if (_selectedOrder?.id == order.id) _selectedOrder = null;
    });
  }

  Future<void> _openAssign(WorkOrder order) async {
    final technicians = await showDialog<List<String>>(
      context: context,
      builder: (context) =>
          AssignTechnicianDialog(order: order, technicians: _technicians),
    );
    if (technicians == null) return;
    final names = technicians.map(displayPersonName).toSet().toList()..sort();
    await _performAction(
      order.copyWith(assignedTo: names.join(', '), assignedTechnicians: names),
      OrderAction.assign,
    );
  }

  Future<void> _performAction(WorkOrder order, OrderAction action) async {
    switch (action) {
      case OrderAction.accept:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(status: 'Accepted by Supervisor'),
            action: 'accepted by admin',
          ),
          success: '${order.id} accepted.',
        );
      case OrderAction.assign:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(status: 'Dispatched'),
            action: 'assigned to ${order.technicianLabel ?? order.assignedTo}',
          ),
          success: '${order.id} dispatched.',
        );
      case OrderAction.markOnsite:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(
              status: 'On Site',
              arrivedAt: DateTime.now(),
              arrivalVerified: true,
            ),
            action: 'arrival verified',
          ),
          success: '${order.id} marked on site.',
        );
      case OrderAction.markSubmitted:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(
              status: 'Submitted',
              sla: 'Ready for approval',
              submittedAt: DateTime.now(),
              evidenceUploaded: true,
            ),
            action: 'submitted for review',
          ),
          success: '${order.id} submitted.',
        );
      case OrderAction.review:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(reviewed: true, reviewedAt: DateTime.now()),
            action: 'reviewed by admin',
          ),
          success: '${order.id} reviewed.',
        );
      case OrderAction.approve:
        await _runMutation(
          () => widget.repository.updateWorkOrder(
            widget.session,
            order.copyWith(status: 'Approved', sla: 'Approved'),
            action: 'approved for billing',
          ),
          success: '${order.id} approved for billing.',
        );
    }
  }

  Future<void> _runMutation(
    Future<void> Function() mutation, {
    required String? success,
  }) async {
    setState(() {
      _isSyncing = true;
    });
    try {
      await mutation();
      await _loadOrders();
      if (!mounted) return;
      if (success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That action could not be completed. Nothing changed. $_supportContactMessage',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.orders,
    required this.onOpen,
    required this.onCreate,
    required this.onViewOrders,
  });

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onOpen;
  final VoidCallback onCreate;
  final ValueChanged<String?> onViewOrders;

  @override
  Widget build(BuildContext context) {
    final open = orders.where((job) => job.status != 'Approved').length;
    final dueSoon = orders.where((job) => job.isOpenDueSoon).length;
    final submitted = orders.where((job) => job.status == 'Submitted').length;
    final billingReady = orders.where((job) => job.status == 'Approved').length;

    return _Page(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              icon: Icons.assignment_late_outlined,
              label: 'Open jobs',
              value: '$open',
              detail: '${orders.length} total jobs',
              color: AppColors.primary,
              onTap: () => onViewOrders('Open'),
            ),
            _MetricCard(
              icon: Icons.timer_outlined,
              label: 'Due soon',
              value: '$dueSoon',
              detail: 'Due within 12 hours',
              color: AppColors.warning,
              onTap: () => onViewOrders('Due soon'),
            ),
            _MetricCard(
              icon: Icons.rule_folder_outlined,
              label: 'Pending approval',
              value: '$submitted',
              detail: 'Submitted field packs',
              color: AppColors.danger,
              onTap: () => onViewOrders('Submitted'),
            ),
            _MetricCard(
              icon: Icons.payments_outlined,
              label: 'Billing ready',
              value: '$billingReady',
              detail: 'Approved jobs',
              color: AppColors.success,
              onTap: () => onViewOrders('Approved'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Operational Queue',
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => onViewOrders(null),
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('View all'),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New job'),
              ),
            ],
          ),
          child: orders.isEmpty
              ? const _EmptyState(message: 'No jobs found in Firestore yet.')
              : Column(
                  children: orders
                      .take(8)
                      .map((order) => _OrderRow(order: order, onOpen: onOpen))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class WorkOrdersView extends StatelessWidget {
  const WorkOrdersView({
    super.key,
    required this.orders,
    required this.search,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onOpen,
  });

  final List<WorkOrder> orders;
  final String search;
  final String status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _JobSearchField(
                    value: search,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search jobs',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items:
                        const [
                              'All',
                              'Open',
                              'Due soon',
                              'Assigned to Supervisor',
                              'Accepted by Supervisor',
                              'Dispatched',
                              'On Site',
                              'Submitted',
                              'Approved',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${orders.length} ${orders.length == 1 ? 'job' : 'jobs'} found',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (search.isNotEmpty || status != 'All')
              TextButton.icon(
                onPressed: () {
                  onSearchChanged('');
                  onStatusChanged('All');
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const _EmptyState(message: 'No jobs match the current filters.')
        else
          ...orders.map((order) => _OrderCard(order: order, onOpen: onOpen)),
      ],
    );
  }
}

class _JobSearchField extends StatefulWidget {
  const _JobSearchField({
    required this.value,
    required this.onChanged,
    required this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;

  @override
  State<_JobSearchField> createState() => _JobSearchFieldState();
}

class _JobSearchFieldState extends State<_JobSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _JobSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration.copyWith(
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
      ),
      onChanged: (value) {
        widget.onChanged(value);
        setState(() {});
      },
    );
  }
}

class OrderDetailView extends StatelessWidget {
  const OrderDetailView({
    super.key,
    required this.order,
    required this.onBack,
    required this.onAction,
    required this.onAssign,
    required this.onShowQr,
    required this.onDelete,
  });

  final WorkOrder order;
  final VoidCallback onBack;
  final void Function(WorkOrder order, OrderAction action) onAction;
  final VoidCallback onAssign;
  final VoidCallback onShowQr;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to jobs'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.id,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StatusPill(label: order.status, color: _statusColor(order.status)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Job Details',
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _InfoTile('Site', order.site, Icons.location_on_outlined),
              _InfoTile('Address', order.address, Icons.map_outlined),
              _InfoTile('Scope', order.scope, Icons.build_outlined),
              _InfoTile('SLA', order.sla, Icons.schedule_outlined),
              _InfoTile('Site code', order.siteCode, Icons.qr_code_2),
              _InfoTile('Priority', order.priority.label, Icons.flag_outlined),
              _InfoTile(
                'Supervisor',
                order.supervisor ?? 'Unassigned',
                Icons.supervisor_account_outlined,
              ),
              _InfoTile(
                'Technician',
                order.technicianLabel ?? 'Unassigned',
                Icons.engineering_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _WorkDurationPanel(order: order),
        const SizedBox(height: 16),
        _CompletionReportPanel(order: order),
        const SizedBox(height: 16),
        _QrPreviewCard(order: order, onShowQr: onShowQr),
        const SizedBox(height: 16),
        _JobActionBar(order: order, onAction: onAction, onAssign: onAssign),
        const SizedBox(height: 16),
        _EvidenceGallery(order: order),
      ],
    );
  }
}

class _WorkDurationPanel extends StatelessWidget {
  const _WorkDurationPanel({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final arrivedAt = order.arrivedAt;
    final submittedAt = order.submittedAt;
    final hasStarted = arrivedAt != null;
    final isComplete = arrivedAt != null && submittedAt != null;
    final duration = arrivedAt == null
        ? null
        : (submittedAt ?? DateTime.now()).difference(arrivedAt);
    final color = isComplete
        ? AppColors.success
        : hasStarted
        ? AppColors.primary
        : AppColors.muted;

    return _Panel(
      title: 'Time Worked',
      trailing: _StatusPill(
        label: isComplete
            ? 'Completed'
            : hasStarted
            ? 'In progress'
            : 'Not started',
        color: color,
      ),
      child: Row(
        children: [
          _IconPill(icon: Icons.timer_outlined, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duration == null
                      ? 'Waiting for site arrival'
                      : '${isComplete ? 'Worked' : 'Working'} ${_formatWorkDuration(duration)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  arrivedAt == null
                      ? 'Time starts when the technician scans the site QR code.'
                      : submittedAt == null
                      ? 'Started ${_dateTimeLabel(arrivedAt)}. Time is still being counted.'
                      : 'From ${_dateTimeLabel(arrivedAt)} to ${_dateTimeLabel(submittedAt)}.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionReportPanel extends StatelessWidget {
  const _CompletionReportPanel({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final notes = order.technicianNotes?.trim();
    final issue = order.issueReport?.trim();
    final strokes = _decodeSignatureStrokes(order.customerSignature);
    final hasDetails =
        notes?.isNotEmpty == true ||
        issue?.isNotEmpty == true ||
        order.customerName?.trim().isNotEmpty == true ||
        strokes.isNotEmpty;

    return _Panel(
      title: 'Completion Report',
      child: hasDetails
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReportField(
                  icon: Icons.edit_note_outlined,
                  label: 'Technician notes',
                  value: notes?.isNotEmpty == true
                      ? notes!
                      : 'No work notes were recorded.',
                ),
                const SizedBox(height: 12),
                _ReportField(
                  icon: issue?.isNotEmpty == true
                      ? Icons.report_problem_outlined
                      : Icons.check_circle_outline,
                  label: 'Issue report',
                  value: issue?.isNotEmpty == true
                      ? issue!
                      : 'No unresolved issues reported.',
                  color: issue?.isNotEmpty == true
                      ? AppColors.warning
                      : AppColors.success,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ReportField(
                        icon: Icons.person_outline,
                        label: 'Customer sign-off',
                        value: order.customerName?.trim().isNotEmpty == true
                            ? order.customerName!.trim()
                            : 'Customer name not recorded.',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: strokes.isEmpty
                            ? const Center(
                                child: Text(
                                  'Signature not recorded',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              )
                            : CustomPaint(
                                painter: _AdminSignaturePainter(strokes),
                                child: const SizedBox.expand(),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : const _EmptyState(
              message:
                  'The technician has not completed the service report yet.',
            ),
    );
  }
}

class _ReportField extends StatelessWidget {
  const _ReportField({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconPill(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminSignaturePainter extends CustomPainter {
  _AdminSignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AdminSignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}

List<List<Offset>> _decodeSignatureStrokes(String? value) {
  if (value == null || value.isEmpty) return const [];
  try {
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .whereType<List<dynamic>>()
        .map(
          (stroke) => stroke
              .whereType<List<dynamic>>()
              .where((point) => point.length >= 2)
              .map(
                (point) => Offset(
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ),
              )
              .toList(),
        )
        .where((stroke) => stroke.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

class _JobActionBar extends StatelessWidget {
  const _JobActionBar({
    required this.order,
    required this.onAction,
    required this.onAssign,
  });

  final WorkOrder order;
  final void Function(WorkOrder order, OrderAction action) onAction;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final evidenceReady = const [
      'before',
      'after',
    ].every(order.evidenceSlots.contains);
    final canApprove = order.status == 'Submitted' && evidenceReady;
    final options = _availableOptions(order);

    return _Panel(
      title: 'Job Actions',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (options.isNotEmpty)
            PopupMenuButton<_JobOption>(
              tooltip: 'More job actions',
              onSelected: (option) => _runOption(context, option),
              itemBuilder: (context) => options
                  .map(
                    (option) => PopupMenuItem(
                      value: option,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(option.icon),
                        title: Text(option.label),
                        subtitle: Text(option.detail),
                      ),
                    ),
                  )
                  .toList(),
              child: const _OutlinedButtonWithIcon(
                icon: Icons.more_horiz,
                label: 'Options',
              ),
            ),
          if (options.isNotEmpty) const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: canApprove
                ? () => _confirmAction(
                    context,
                    title: 'Approve this job?',
                    message:
                        'This marks the job as approved and ready for billing.',
                    confirmLabel: 'Approve job',
                    action: () => onAction(order, OrderAction.approve),
                  )
                : null,
            icon: Icon(
              order.status == 'Approved'
                  ? Icons.check_circle_outline
                  : Icons.verified_outlined,
            ),
            label: Text(
              order.status == 'Approved' ? 'Approved' : 'Approve job',
            ),
          ),
        ],
      ),
      child: Text(
        order.status == 'Approved'
            ? 'This job is complete and approved for billing.'
            : canApprove
            ? 'Evidence is complete. Review the photos before approval.'
            : 'Available actions are based on the current job status.',
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }

  List<_JobOption> _availableOptions(WorkOrder order) {
    return switch (order.status) {
      'Assigned to Supervisor' => const [
        _JobOption(
          'Accept job',
          'Confirm the supervisor assignment.',
          Icons.verified_outlined,
          OrderAction.accept,
        ),
      ],
      'Accepted by Supervisor' => const [
        _JobOption(
          'Assign technician',
          'Select and dispatch a field technician.',
          Icons.person_add_alt,
          OrderAction.assign,
        ),
      ],
      'Dispatched' => const [
        _JobOption(
          'Mark on site',
          'Confirm that the technician reached the site.',
          Icons.location_on_outlined,
          OrderAction.markOnsite,
        ),
      ],
      'On Site' => const [
        _JobOption(
          'Submit evidence pack',
          'Move the completed field pack to admin review.',
          Icons.upload_file_outlined,
          OrderAction.markSubmitted,
        ),
      ],
      'Submitted' when !order.reviewed => const [
        _JobOption(
          'Mark as reviewed',
          'Record that the evidence has been checked.',
          Icons.fact_check_outlined,
          OrderAction.review,
        ),
      ],
      _ => const [],
    };
  }

  void _runOption(BuildContext context, _JobOption option) {
    if (option.action == OrderAction.assign) {
      onAssign();
      return;
    }
    _confirmAction(
      context,
      title: '${option.label}?',
      message: option.detail,
      confirmLabel: option.label,
      action: () => onAction(order, option.action),
    );
  }
}

class _JobOption {
  const _JobOption(this.label, this.detail, this.icon, this.action);

  final String label;
  final String detail;
  final IconData icon;
  final OrderAction action;
}

class _OutlinedButtonWithIcon extends StatelessWidget {
  const _OutlinedButtonWithIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

Future<void> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed == true) action();
}

class _EvidenceGallery extends StatelessWidget {
  const _EvidenceGallery({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Evidence Photos',
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _EvidencePhotoCard(
            title: 'Before work',
            detail: 'Site condition before work started',
            photoData: order.evidencePhotos['before'],
            complete: order.evidenceSlots.contains('before'),
          ),
          _EvidencePhotoCard(
            title: 'After work',
            detail: 'Completed work at the site',
            photoData: order.evidencePhotos['after'],
            complete: order.evidenceSlots.contains('after'),
          ),
        ],
      ),
    );
  }
}

class _EvidencePhotoCard extends StatelessWidget {
  const _EvidencePhotoCard({
    required this.title,
    required this.detail,
    required this.photoData,
    required this.complete,
  });

  final String title;
  final String detail;
  final String? photoData;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeEvidencePhoto(photoData);
    final photoUrl = _evidencePhotoUrl(photoData);
    return SizedBox(
      width: 320,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: bytes == null && photoUrl == null
              ? null
              : () => _openEvidencePhoto(
                  context,
                  title,
                  bytes: bytes,
                  photoUrl: photoUrl,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 180,
                child: bytes == null && photoUrl == null
                    ? ColoredBox(
                        color: AppColors.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                complete
                                    ? Icons.image_outlined
                                    : Icons.add_photo_alternate_outlined,
                                size: 38,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                complete
                                    ? 'Preview unavailable'
                                    : 'Photo not uploaded',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (bytes != null)
                            Image.memory(bytes, fit: BoxFit.cover)
                          else
                            Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                    color: AppColors.surface,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                            ),
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: _PhotoExpandBadge(),
                          ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoExpandBadge extends StatelessWidget {
  const _PhotoExpandBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(7),
        child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
      ),
    );
  }
}

void _openEvidencePhoto(
  BuildContext context,
  String title, {
  Uint8List? bytes,
  String? photoUrl,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.contain)
                : Image.network(photoUrl!, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

String? _evidencePhotoUrl(String? photoData) {
  if (photoData == null || photoData.isEmpty) return null;
  final uri = Uri.tryParse(photoData);
  if (uri == null || !uri.hasScheme) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return photoData;
}

Uint8List? _decodeEvidencePhoto(String? photoData) {
  if (photoData == null || photoData.isEmpty) return null;
  try {
    final comma = photoData.indexOf(',');
    return base64Decode(
      comma == -1 ? photoData : photoData.substring(comma + 1),
    );
  } catch (_) {
    return null;
  }
}

class JobQrDialog extends StatefulWidget {
  const JobQrDialog({super.key, required this.order});

  final WorkOrder order;

  @override
  State<JobQrDialog> createState() => _JobQrDialogState();
}

class _JobQrDialogState extends State<JobQrDialog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final payload = widget.order.qrPayload;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Site QR Code')),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 280,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: payload,
                    size: 238,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.order.siteCode,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.order.site,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.order.address,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  _QrDetail(label: 'Work order', value: widget.order.id),
                  _QrDetail(label: 'Site code', value: widget.order.siteCode),
                  _QrDetail(label: 'Status', value: widget.order.status),
                  const SizedBox(height: 16),
                  const Text(
                    'The technician scans this code to identify the job and confirm the correct site.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _copy,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy details'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Save PDF'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(_busy ? 'Preparing' : 'Send'),
        ),
      ],
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${widget.order.id}\n${widget.order.site}\n${widget.order.siteCode}\n${widget.order.qrPayload}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('QR job details copied.')));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final file = await _saveQrPdfAs(widget.order);
      if (file == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QR PDF saved to ${file.path}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final recipient = await showDialog<String>(
      context: context,
      builder: (context) => const _SendQrDialog(),
    );
    if (recipient == null) return;
    setState(() => _busy = true);
    try {
      final file = await _writeQrPdfAttachment(widget.order);
      final subject = 'Site QR - ${widget.order.id}';
      final body =
          'Hello,\n\nPlease find the site QR details below.\n\n'
          'Work order: ${widget.order.id}\n'
          'Site: ${widget.order.site}\n'
          'Address: ${widget.order.address}\n'
          'Site code: ${widget.order.siteCode}\n\n'
          'The site QR PDF is attached.';
      await _openOutlookDraftWithAttachment(
        recipient: recipient,
        subject: subject,
        body: body,
        attachmentPath: file.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email opened with the QR PDF attached.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SendQrDialog extends StatefulWidget {
  const _SendQrDialog();

  @override
  State<_SendQrDialog> createState() => _SendQrDialogState();
}

class _SendQrDialogState extends State<_SendQrDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send QR by email'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Recipient email',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            const Text(
              'This opens an Outlook draft with the generated QR PDF already attached.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || !value.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.pop(context, value);
  }
}

class _QrPreviewCard extends StatelessWidget {
  const _QrPreviewCard({required this.order, required this.onShowQr});

  final WorkOrder order;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 118,
            height: 118,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(data: order.qrPayload),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site QR Code',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.siteCode} - ready to view, save, or send.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Open QR'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrDetail extends StatelessWidget {
  const _QrDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class TeamsView extends StatelessWidget {
  const TeamsView({
    super.key,
    required this.orders,
    required this.onAssign,
    required this.onOpen,
  });

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onAssign;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    final assignable = orders
        .where(
          (order) =>
              order.status == 'Accepted by Supervisor' ||
              order.status == 'Assigned to Supervisor' ||
              order.technicianLabel == null,
        )
        .toList();

    return _Page(
      children: [
        _Panel(
          title: 'Technician Dispatch',
          child: assignable.isEmpty
              ? const _EmptyState(message: 'No jobs are waiting for dispatch.')
              : Column(
                  children: assignable
                      .map(
                        (order) => _DispatchRow(
                          order: order,
                          onOpen: () => onOpen(order),
                          onAssign: () => onAssign(order),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Available Technicians',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: demoTechnicians
                .map(
                  (person) => _PersonCard(
                    name: person.name,
                    email: person.email,
                    team: person.team,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class AcceptanceView extends StatelessWidget {
  const AcceptanceView({
    super.key,
    required this.orders,
    required this.onApprove,
    required this.onOpen,
  });

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onApprove;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    final submitted = orders.where((job) => job.status == 'Submitted').toList();
    final approved = orders.where((job) => job.status == 'Approved').length;

    return _Page(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GateCard(
              title: 'Site QR verified',
              detail:
                  '${orders.where((job) => job.arrivalVerified).length} jobs verified',
              complete: orders.any((job) => job.arrivalVerified),
            ),
            _GateCard(
              title: 'Material consumed/returned',
              detail: 'Static reconciliation ready for workflow extension',
              complete: false,
            ),
            _GateCard(
              title: 'Admin approval',
              detail: '$approved jobs approved for billing',
              complete: approved > 0,
            ),
            _GateCard(
              title: 'Invoice support pack',
              detail: '${submitted.length} packs need approval',
              complete: submitted.isEmpty && approved > 0,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Approval Queue',
          child: submitted.isEmpty
              ? const _EmptyState(
                  message: 'No submitted jobs awaiting approval.',
                )
              : Column(
                  children: submitted
                      .map(
                        (order) => _ApprovalRow(
                          order: order,
                          onOpen: () => onOpen(order),
                          onApprove: () => onApprove(order),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key, required this.orders});

  final List<WorkOrder> orders;

  @override
  Widget build(BuildContext context) {
    final rows = _personRows();
    return _Page(
      children: [
        _Panel(
          title: 'Company Analytics',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                icon: Icons.work_outline,
                label: 'Total jobs',
                value: '${orders.length}',
                detail: 'All Firestore work orders',
                color: AppColors.primary,
              ),
              _MetricCard(
                icon: Icons.pending_actions_outlined,
                label: 'Open',
                value:
                    '${orders.where((job) => job.status != 'Approved').length}',
                detail: 'Not yet billing ready',
                color: AppColors.warning,
              ),
              _MetricCard(
                icon: Icons.timer_outlined,
                label: 'Urgent',
                value: '${orders.where((job) => job.isOpenDueSoon).length}',
                detail: 'Due within 12 hours',
                color: AppColors.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Per Person',
          child: rows.isEmpty
              ? const _EmptyState(message: 'No jobs available for analytics.')
              : Column(
                  children: rows
                      .map((row) => _PersonAnalyticsRow(row: row))
                      .toList(),
                ),
        ),
      ],
    );
  }

  List<PersonAnalytics> _personRows() {
    final grouped = <String, List<WorkOrder>>{};
    for (final job in orders) {
      final person =
          job.technicianLabel ??
          job.supervisor ??
          job.createdBy ??
          'Unassigned';
      grouped.putIfAbsent(person, () => []).add(job);
    }
    final rows = grouped.entries.map((entry) {
      final jobs = entry.value;
      return PersonAnalytics(
        entry.key,
        total: jobs.length,
        open: jobs.where((job) => job.status != 'Approved').length,
        dispatched: jobs.where((job) => job.status == 'Dispatched').length,
        onSite: jobs.where((job) => job.status == 'On Site').length,
        submitted: jobs.where((job) => job.status == 'Submitted').length,
        approved: jobs.where((job) => job.status == 'Approved').length,
        urgent: jobs.where((job) => job.isOpenDueSoon).length,
      );
    }).toList();
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }
}

class CreateJobDialog extends StatefulWidget {
  const CreateJobDialog({super.key});

  @override
  State<CreateJobDialog> createState() => _CreateJobDialogState();
}

class _CreateJobDialogState extends State<CreateJobDialog> {
  final _site = TextEditingController();
  final _address = TextEditingController();
  final _scope = TextEditingController();
  late DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  Priority _priority = Priority.high;

  @override
  void dispose() {
    _site.dispose();
    _address.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Job'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _site,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Site name',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scope,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Work scope',
                  prefixIcon: Icon(Icons.build_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_dateLabel(_dueAt)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(_timeLabel(_dueAt)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Priority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: Priority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_task),
          label: const Text('Create job'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (picked == null) return;
    setState(() {
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _submit() {
    final site = _site.text.trim();
    final address = _address.text.trim();
    final scope = _scope.text.trim();
    if (site.isEmpty || address.isEmpty || scope.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site name, address, and work scope are required.'),
        ),
      );
      return;
    }
    if (!_dueAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date and time must be in the future.'),
        ),
      );
      return;
    }
    final nextNumber = DateTime.now().millisecondsSinceEpoch % 100000;
    Navigator.pop(
      context,
      WorkOrder(
        id: 'JOB-CMT-ESW-$nextNumber',
        site: site,
        address: address,
        scope: scope,
        sla: 'Due by ${_dateLabel(_dueAt)} at ${_timeLabel(_dueAt)}',
        siteCode: 'SITE-$nextNumber',
        status: 'Assigned to Supervisor',
        priority: _priority,
        dueAt: _dueAt,
        supervisor: demoSupervisors.first.name,
      ),
    );
  }
}

class AssignTechnicianDialog extends StatefulWidget {
  const AssignTechnicianDialog({
    super.key,
    required this.order,
    required this.technicians,
  });

  final WorkOrder order;
  final List<AdminUserProfile> technicians;

  @override
  State<AssignTechnicianDialog> createState() => _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState extends State<AssignTechnicianDialog> {
  late final TextEditingController _searchController;
  late final Set<String> _selectedNames;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedNames = {...widget.order.technicianNames};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.technicians
        : widget.technicians.where((technician) {
            return [
              technician.name,
              technician.email,
              technician.team ?? '',
            ].any((value) => value.toLowerCase().contains(query));
          }).toList();

    return AlertDialog(
      title: const Text('Assign Technicians'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search technicians',
                hintText: 'Name or email',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedNames.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedNames
                    .map(
                      (name) => InputChip(
                        avatar: const Icon(Icons.person),
                        label: Text(name),
                        onDeleted: () =>
                            setState(() => _selectedNames.remove(name)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: widget.technicians.isEmpty
                  ? const _EmptyTechnicianDirectory()
                  : filtered.isEmpty
                  ? const _EmptyTechnicianSearchResult()
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _technicianTile(filtered[index]),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final allowedNames = widget.technicians
                .map((technician) => technician.name)
                .toSet();
            final names = _selectedNames.where(allowedNames.contains).toList()
              ..sort();
            if (names.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select an existing technician.')),
              );
              return;
            }
            Navigator.pop(context, names);
          },
          icon: const Icon(Icons.person_add_alt),
          label: Text(
            _selectedNames.length == 1
                ? 'Assign job'
                : 'Assign ${_selectedNames.length}',
          ),
        ),
      ],
    );
  }

  Widget _technicianTile(AdminUserProfile technician) {
    final selected = _selectedNames.contains(technician.name);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: (_) => setState(() {
        if (selected) {
          _selectedNames.remove(technician.name);
        } else {
          _selectedNames.add(technician.name);
        }
      }),
      secondary: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          technician.name.isEmpty ? '?' : technician.name[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        technician.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        technician.team?.isNotEmpty == true
            ? technician.team!
            : technician.email,
      ),
    );
  }
}

class _EmptyTechnicianDirectory extends StatelessWidget {
  const _EmptyTechnicianDirectory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'No technicians are available. Add technician users first.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class _EmptyTechnicianSearchResult extends StatelessWidget {
  const _EmptyTechnicianSearchResult();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'No technicians match this search.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}

abstract class AdminRepository {
  Future<AuthSession> signIn({required String email, required String password});
  Future<List<WorkOrder>> fetchWorkOrders(AuthSession session);
  Future<List<AdminUserProfile>> fetchTechnicians(AuthSession session);
  Future<void> createWorkOrder(AuthSession session, WorkOrder order);
  Future<void> updateWorkOrder(
    AuthSession session,
    WorkOrder order, {
    required String action,
  });
  Future<void> deleteWorkOrder(AuthSession session, WorkOrder order);
}

class RestAdminRepository implements AdminRepository {
  RestAdminRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final uri = Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/accounts:signInWithPassword',
      {'key': _firebaseApiKey},
    );
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final body = _decode(response);
    if (response.statusCode >= 400) throw ApiException.fromBody(body);
    return AuthSession(
      idToken: body['idToken'] as String,
      email: body['email'] as String? ?? email,
      uid: body['localId'] as String? ?? 'admin',
    );
  }

  @override
  Future<List<WorkOrder>> fetchWorkOrders(AuthSession session) async {
    final orders = <WorkOrder>[];
    String? pageToken;
    do {
      final query = <String, dynamic>{'pageSize': '100'};
      if (pageToken != null) query['pageToken'] = pageToken;
      final uri = _documentsUri('/work_orders', query: query);
      final response = await _client.get(uri, headers: _headers(session));
      final body = _decode(response);
      if (response.statusCode >= 400) throw ApiException.fromBody(body);

      final documents = (body['documents'] as List<dynamic>? ?? const []);
      orders.addAll(
        documents.whereType<Map<String, dynamic>>().map(
          WorkOrder.fromFirestoreDocument,
        ),
      );
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    return orders;
  }

  @override
  Future<List<AdminUserProfile>> fetchTechnicians(AuthSession session) async {
    final users = <AdminUserProfile>[];
    String? pageToken;
    do {
      final query = <String, dynamic>{'pageSize': '100'};
      if (pageToken != null) query['pageToken'] = pageToken;
      final uri = _documentsUri('/users', query: query);
      final response = await _client.get(uri, headers: _headers(session));
      final body = _decode(response);
      if (response.statusCode >= 400) throw ApiException.fromBody(body);

      final documents = (body['documents'] as List<dynamic>? ?? const []);
      users.addAll(
        documents
            .whereType<Map<String, dynamic>>()
            .map(AdminUserProfile.fromFirestoreDocument)
            .where((user) => user.role == 'technician'),
      );
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  @override
  Future<void> createWorkOrder(AuthSession session, WorkOrder order) async {
    final now = DateTime.now();
    final created = order.copyWith(createdBy: session.uid);
    final fields = created.toFirestoreFields(
      updatedAt: now,
      createdAt: now,
      historyAction: 'created by admin',
      historyUserId: session.uid,
    );
    final uri = _documentsUri('/work_orders/${order.id}');
    final response = await _client.patch(
      uri,
      headers: _headers(session),
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
  }

  @override
  Future<void> updateWorkOrder(
    AuthSession session,
    WorkOrder order, {
    required String action,
  }) async {
    final fields = order.toFirestoreFields(
      updatedAt: DateTime.now(),
      historyAction: action,
      historyUserId: session.uid,
    );
    final mask = fields.keys.map((key) => 'updateMask.fieldPaths').toList();
    final values = fields.keys.toList();
    final query = <String, dynamic>{};
    for (var i = 0; i < mask.length; i++) {
      query.putIfAbsent(mask[i], () => <String>[]).add(values[i]);
    }
    final uri = _documentsUri('/work_orders/${order.id}', query: query);
    final response = await _client.patch(
      uri,
      headers: _headers(session),
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
  }

  @override
  Future<void> deleteWorkOrder(AuthSession session, WorkOrder order) async {
    final uri = _documentsUri('/work_orders/${order.id}');
    final response = await _client.delete(uri, headers: _headers(session));
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
  }

  Uri _documentsUri(String path, {Map<String, dynamic>? query}) {
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_firebaseProjectId/databases/(default)/documents$path',
      query,
    );
  }

  Map<String, String> _headers(AuthSession session) => {
    'authorization': 'Bearer ${session.idToken}',
    'content-type': 'application/json',
  };
}

class AuthSession {
  const AuthSession({
    required this.idToken,
    required this.email,
    required this.uid,
  });

  final String idToken;
  final String email;
  final String uid;
}

class AdminUserProfile {
  const AdminUserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.team,
  });

  final String uid;
  final String email;
  final String name;
  final String role;
  final String? team;

  factory AdminUserProfile.fromFirestoreDocument(
    Map<String, dynamic> document,
  ) {
    final name = document['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = document['fields'] as Map<String, dynamic>? ?? const {};
    final email = _fieldString(fields['email'])?.trim() ?? '';
    final storedName = _fieldString(fields['name'])?.trim();
    return AdminUserProfile(
      uid: id,
      email: email,
      name: storedName?.isNotEmpty == true
          ? storedName!
          : displayPersonName(email),
      role: (_fieldString(fields['role']) ?? 'technician').toLowerCase(),
      team: _fieldString(fields['team'])?.trim(),
    );
  }
}

enum _AdminNotificationType {
  assignment,
  action,
  issue,
  progress,
  success,
  info,
}

class _AdminNotification {
  _AdminNotification({
    required this.orderId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
  });

  final String orderId;
  final String title;
  final String message;
  final DateTime createdAt;
  final _AdminNotificationType type;
  bool read = false;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  factory ApiException.fromBody(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(error['message'] as String? ?? 'Request failed.');
    }
    return const ApiException('Request failed.');
  }

  @override
  String toString() => message;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.site,
    required this.address,
    required this.scope,
    required this.sla,
    required this.siteCode,
    required this.status,
    required this.priority,
    this.dueAt,
    this.arrivedAt,
    this.submittedAt,
    this.arrivalVerified = false,
    this.evidenceUploaded = false,
    this.evidenceSlots = const [],
    this.evidencePhotos = const {},
    this.technicianNotes,
    this.issueReport,
    this.customerName,
    this.customerSignature,
    this.reviewed = false,
    this.reviewedAt,
    this.supervisor,
    this.assignedTo,
    this.assignedTechnicians = const [],
    this.createdBy,
  });

  final String id;
  final String site;
  final String address;
  final String scope;
  final String sla;
  final String siteCode;
  final String status;
  final Priority priority;
  final DateTime? dueAt;
  final DateTime? arrivedAt;
  final DateTime? submittedAt;
  final bool arrivalVerified;
  final bool evidenceUploaded;
  final List<String> evidenceSlots;
  final Map<String, String> evidencePhotos;
  final String? technicianNotes;
  final String? issueReport;
  final String? customerName;
  final String? customerSignature;
  final bool reviewed;
  final DateTime? reviewedAt;
  final String? supervisor;
  final String? assignedTo;
  final List<String> assignedTechnicians;
  final String? createdBy;

  bool get isDueSoon {
    final due = dueAt;
    if (due == null) return false;
    final hours = due.difference(DateTime.now()).inHours;
    return hours >= 0 && hours <= 12;
  }

  bool get isOpenDueSoon => status != 'Approved' && isDueSoon;

  String get qrPayload => siteCode;

  WorkOrder copyWith({
    String? status,
    String? sla,
    DateTime? arrivedAt,
    DateTime? submittedAt,
    bool? arrivalVerified,
    bool? evidenceUploaded,
    bool? reviewed,
    DateTime? reviewedAt,
    String? assignedTo,
    List<String>? assignedTechnicians,
    String? createdBy,
  }) {
    return WorkOrder(
      id: id,
      site: site,
      address: address,
      scope: scope,
      sla: sla ?? this.sla,
      siteCode: siteCode,
      status: status ?? this.status,
      priority: priority,
      dueAt: dueAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      arrivalVerified: arrivalVerified ?? this.arrivalVerified,
      evidenceUploaded: evidenceUploaded ?? this.evidenceUploaded,
      evidenceSlots: evidenceSlots,
      evidencePhotos: evidencePhotos,
      technicianNotes: technicianNotes,
      issueReport: issueReport,
      customerName: customerName,
      customerSignature: customerSignature,
      reviewed: reviewed ?? this.reviewed,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      supervisor: supervisor,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedTechnicians: assignedTechnicians ?? this.assignedTechnicians,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  List<String> get technicianNames {
    if (assignedTechnicians.isNotEmpty) {
      return assignedTechnicians.map(displayPersonName).toList();
    }
    final assigned = assignedTo?.trim();
    if (assigned == null || assigned.isEmpty) return const [];
    return assigned
        .split(RegExp(r'[,;]'))
        .map(displayPersonName)
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String? get technicianLabel {
    final names = technicianNames;
    if (names.isEmpty) return null;
    return names.join(', ');
  }

  factory WorkOrder.fromFirestoreDocument(Map<String, dynamic> document) {
    final name = document['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = document['fields'] as Map<String, dynamic>? ?? const {};
    return WorkOrder(
      id: id,
      site: _fieldString(fields['site']) ?? 'Unknown site',
      address: _fieldString(fields['address']) ?? 'Address pending',
      scope: _fieldString(fields['scope']) ?? 'No scope captured',
      sla: _fieldString(fields['sla']) ?? 'Due in 24 hours',
      siteCode: _fieldString(fields['siteCode']) ?? 'SITE-PENDING',
      status: _fieldString(fields['status']) ?? 'New',
      priority: Priority.fromString(_fieldString(fields['priority'])),
      dueAt: _fieldDate(fields['dueAt']),
      arrivedAt: _fieldDate(fields['arrivedAt']),
      submittedAt: _fieldDate(fields['submittedAt']),
      arrivalVerified: _fieldBool(fields['arrivalVerified']) ?? false,
      evidenceUploaded: _fieldBool(fields['evidenceUploaded']) ?? false,
      evidenceSlots: _fieldStringList(fields['evidenceSlots']),
      evidencePhotos: _fieldStringMap(fields['evidencePhotos']),
      technicianNotes: _fieldString(fields['technicianNotes']),
      issueReport: _fieldString(fields['issueReport']),
      customerName: _fieldString(fields['customerName']),
      customerSignature: _fieldString(fields['customerSignature']),
      reviewed: _fieldBool(fields['reviewed']) ?? false,
      reviewedAt: _fieldDate(fields['reviewedAt']),
      supervisor: _fieldString(fields['supervisor']),
      assignedTo: _fieldString(fields['assignedTo']),
      assignedTechnicians: _fieldStringList(
        fields['assignedTechnicians'],
      ).map(displayPersonName).where((name) => name.isNotEmpty).toList(),
      createdBy: _fieldString(fields['createdBy']),
    );
  }

  Map<String, Object?> toFirestoreFields({
    DateTime? createdAt,
    DateTime? updatedAt,
    String? historyAction,
    String? historyUserId,
  }) {
    final fields = <String, Object?>{
      'site': _stringField(site),
      'address': _stringField(address),
      'scope': _stringField(scope),
      'sla': _stringField(sla),
      'siteCode': _stringField(siteCode),
      'status': _stringField(status),
      'priority': _stringField(priority.name),
      'arrivalVerified': _boolField(arrivalVerified),
      'evidenceUploaded': _boolField(evidenceUploaded),
      'evidenceSlots': _arrayField(evidenceSlots.map(_stringField).toList()),
      'evidencePhotos': _mapField(evidencePhotos),
      'assignedTechnicians': _arrayField(
        assignedTechnicians.map(_stringField).toList(),
      ),
      'reviewed': _boolField(reviewed),
    };
    void addDate(String key, DateTime? value) {
      if (value != null) fields[key] = _timestampField(value);
    }

    void addString(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        fields[key] = _stringField(value);
      }
    }

    addDate('dueAt', dueAt);
    addDate('arrivedAt', arrivedAt);
    addDate('submittedAt', submittedAt);
    addDate('reviewedAt', reviewedAt);
    addDate('createdAt', createdAt);
    addDate('updatedAt', updatedAt);
    addString('supervisor', supervisor);
    addString('assignedTo', assignedTo);
    addString('createdBy', createdBy);
    addString('technicianNotes', technicianNotes);
    addString('issueReport', issueReport);
    addString('customerName', customerName);
    addString('customerSignature', customerSignature);
    if (historyAction != null) {
      fields['lastHistoryAction'] = _stringField(historyAction);
      fields['lastHistoryUserId'] = _stringField(historyUserId ?? 'admin');
      fields['lastHistoryAt'] = _timestampField(DateTime.now());
    }
    return fields;
  }
}

enum Priority {
  critical('Critical'),
  high('High'),
  low('Low');

  const Priority(this.label);
  final String label;

  static Priority fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'critical' => Priority.critical,
      'low' => Priority.low,
      _ => Priority.high,
    };
  }
}

enum AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  workOrders('Work orders', Icons.assignment_outlined),
  teams('Field teams', Icons.people_alt_outlined),
  acceptance('Acceptance', Icons.fact_check_outlined),
  analytics('Analytics', Icons.query_stats_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum OrderAction { accept, assign, markOnsite, markSubmitted, review, approve }

class DemoPerson {
  const DemoPerson({
    required this.name,
    required this.email,
    required this.team,
  });

  final String name;
  final String email;
  final String team;
}

class PersonAnalytics {
  const PersonAnalytics(
    this.name, {
    required this.total,
    required this.open,
    required this.dispatched,
    required this.onSite,
    required this.submitted,
    required this.approved,
    required this.urgent,
  });

  final String name;
  final int total;
  final int open;
  final int dispatched;
  final int onSite;
  final int submitted;
  final int approved;
  final int urgent;
}

const demoSupervisors = [
  DemoPerson(
    name: 'Mandla Dlamini',
    email: 'mandla@commit.co.sz',
    team: 'North Region',
  ),
];

const demoTechnicians = [
  DemoPerson(
    name: 'Sibusiso M.',
    email: 'sibusiso@commit.co.sz',
    team: 'Field Team A',
  ),
  DemoPerson(
    name: 'Thabo M.',
    email: 'thabo.tech@commit.co.sz',
    team: 'Field Team B',
  ),
  DemoPerson(
    name: 'Lindiwe S.',
    email: 'lindiwe.tech@commit.co.sz',
    team: 'Field Team C',
  ),
];

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.userEmail,
    required this.onSelected,
    required this.onSignOut,
  });

  final AdminSection selected;
  final String userEmail;
  final ValueChanged<AdminSection> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(AdminSection.dashboard),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const _BrandLogo(size: 52, showBackground: true),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BrandName(fontSize: 17),
                          Text(
                            'Admin Console',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (final section in AdminSection.values)
            _NavItem(
              icon: section.icon,
              label: section.label,
              selected: section == selected,
              onTap: () => onSelected(section),
            ),
          const Spacer(),
          Text(userEmail, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        minLeadingWidth: 20,
        leading: Icon(
          icon,
          color: selected ? AppColors.primary : AppColors.muted,
          size: 21,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.ink,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isSyncing,
    required this.onRefresh,
    required this.onCreate,
    required this.notificationCount,
    required this.onNotifications,
    this.onBack,
  });

  final String title;
  final bool isSyncing;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton.filledTonal(
              onPressed: onBack,
              tooltip: 'Back to work orders',
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filledTonal(
            onPressed: isSyncing ? null : onRefresh,
            tooltip: 'Refresh Firestore data',
            icon: isSyncing
                ? const _AnimatedLogoLoader(size: 24, compact: true)
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onNotifications,
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: notificationCount > 0,
              label: Text(notificationCount > 9 ? '9+' : '$notificationCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('New work order'),
          ),
        ],
      ),
    );
  }
}

class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({
    required this.notification,
    required this.onTap,
  });

  final _AdminNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, category) = switch (notification.type) {
      _AdminNotificationType.assignment => (
        Icons.assignment_add,
        const Color(0xFF3867B7),
        'Assignment',
      ),
      _AdminNotificationType.action => (
        Icons.pending_actions_outlined,
        AppColors.warning,
        'Action required',
      ),
      _AdminNotificationType.issue => (
        Icons.report_problem_outlined,
        AppColors.danger,
        'Attention',
      ),
      _AdminNotificationType.progress => (
        Icons.route_outlined,
        AppColors.primary,
        'Progress',
      ),
      _AdminNotificationType.success => (
        Icons.check_circle_outline,
        AppColors.success,
        'Completed',
      ),
      _AdminNotificationType.info => (
        Icons.info_outline,
        AppColors.muted,
        'Update',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: notification.read
            ? Colors.white
            : color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notification.read
              ? AppColors.border
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        contentPadding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.read
                      ? FontWeight.w700
                      : FontWeight.w900,
                ),
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              const SizedBox(height: 7),
              Wrap(
                spacing: 10,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    notification.orderId,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _relativeNotificationTime(notification.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AdminNotificationEmptyState extends StatelessWidget {
  const _AdminNotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 56,
            color: AppColors.muted,
          ),
          SizedBox(height: 14),
          Text(
            'Operations are up to date',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'There are no unread operational notifications.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

String _relativeNotificationTime(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'Now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return _dateLabel(value);
}

class _Page extends StatelessWidget {
  const _Page({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
      children: children,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      height: 146,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _IconPill(icon: icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        detail,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onOpen});

  final WorkOrder order;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: () => onOpen(order),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _IconPill(
                  icon: Icons.assignment_outlined,
                  color: _statusColor(order.status),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.id} - ${order.site}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.address} | ${order.scope}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: order.priority.label,
                  color: _priorityColor(order.priority),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: order.status,
                  color: _statusColor(order.status),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onOpen});

  final WorkOrder order;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => onOpen(order),
      mouseCursor: SystemMouseCursors.click,
      title: Text(
        '${order.id} - ${order.site}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(order.scope, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(label: order.status, color: _statusColor(order.status)),
          IconButton(
            onPressed: () => onOpen(order),
            tooltip: 'Open job',
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({
    required this.order,
    required this.onOpen,
    required this.onAssign,
  });

  final WorkOrder order;
  final VoidCallback onOpen;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      mouseCursor: SystemMouseCursors.click,
      leading: _IconPill(
        icon: Icons.engineering_outlined,
        color: AppColors.primary,
      ),
      title: Text(
        '${order.id} - ${order.site}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        'Current technician: ${order.technicianLabel ?? 'Unassigned'}',
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Assign'),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({
    required this.order,
    required this.onOpen,
    required this.onApprove,
  });

  final WorkOrder order;
  final VoidCallback onOpen;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      mouseCursor: SystemMouseCursors.click,
      leading: _IconPill(
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
      ),
      title: Text(
        '${order.id} - ${order.site}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(order.sla),
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          FilledButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$label copied.')));
        },
        mouseCursor: SystemMouseCursors.click,
        leading: _IconPill(icon: icon, color: AppColors.primary),
        title: Text(label, style: const TextStyle(color: AppColors.muted)),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.title,
    required this.detail,
    required this.complete,
  });

  final String title;
  final String detail;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppColors.success : AppColors.warning;
    return SizedBox(
      width: 310,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconPill(
                icon: complete ? Icons.check_circle : Icons.pending_actions,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.email,
    required this.team,
  });

  final String name;
  final String email;
  final String team;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: ListTile(
        leading: _IconPill(
          icon: Icons.person_outline,
          color: AppColors.primary,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$team\n$email'),
      ),
    );
  }
}

class _PersonAnalyticsRow extends StatelessWidget {
  const _PersonAnalyticsRow({required this.row});

  final PersonAnalytics row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _IconPill(icon: Icons.person_outline, color: AppColors.primary),
      title: Text(
        row.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _SmallChip('${row.open} open'),
          _SmallChip('${row.dispatched} dispatched'),
          _SmallChip('${row.onSite} on site'),
          _SmallChip('${row.submitted} submitted'),
          _SmallChip('${row.approved} approved'),
          _SmallChip('${row.urgent} urgent'),
        ],
      ),
      trailing: _StatusPill(
        label: '${row.total} jobs',
        color: AppColors.primary,
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: const BorderSide(color: AppColors.border),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

class _AnimatedLogoLoader extends StatefulWidget {
  const _AnimatedLogoLoader({
    this.size = 120,
    this.label,
    this.compact = false,
  });

  final double size;
  final String? label;
  final bool compact;

  @override
  State<_AnimatedLogoLoader> createState() => _AnimatedLogoLoaderState();
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size, this.showBackground = false});

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final padding = size * (showBackground ? 0.12 : 0.04);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: showBackground ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: showBackground
            ? Border.all(color: const Color(0xFFD6D6D6), width: 1.2)
            : null,
        boxShadow: showBackground
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Image.asset(
        'assets/logo1.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'PHEPHA MV ISDP logo',
      ),
    );
  }
}

class _BrandName extends StatelessWidget {
  const _BrandName({required this.fontSize, this.suffix = ''});

  final double fontSize;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'PHEPHA MV '),
          const TextSpan(
            text: 'ISDP',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: suffix),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AnimatedLogoLoaderState extends State<_AnimatedLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * 6.283185307179586;
        final scale = 0.96 + math.sin(phase) * 0.04;
        final lift = math.sin(phase) * (widget.compact ? 1.5 : 5);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, lift),
              child: Transform.scale(
                scale: scale,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: phase,
                        child: Container(
                          width: widget.size * 0.82,
                          height: widget.size * 0.82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: widget.compact ? 1.5 : 3,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(widget.size * 0.12),
                        child: Image.asset(
                          'assets/logo1.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.label != null) ...[
              SizedBox(height: widget.compact ? 3 : 12),
              Text(
                widget.label!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class AppColors {
  static const primary = Color(0xFFD32F2F);
  static const success = Color(0xFF21845A);
  static const warning = Color(0xFFB36B00);
  static const danger = Color(0xFFB71C1C);
  static const ink = Color(0xFF212121);
  static const muted = Color(0xFF6B6B6B);
  static const surface = Color(0xFFF7F7F7);
  static const border = Color(0xFFE2E2E2);
}

Map<String, dynamic> _decode(http.Response response) {
  if (response.body.isEmpty) return {};
  return jsonDecode(response.body) as Map<String, dynamic>;
}

String _friendlyError(Object error) {
  final raw = error is ApiException ? error.message : error.toString();
  if (raw.contains('INVALID_LOGIN_CREDENTIALS') ||
      raw.contains('EMAIL_NOT_FOUND') ||
      raw.contains('INVALID_PASSWORD')) {
    return 'Email or password is incorrect. $_supportContactMessage';
  }
  if (raw.contains('PERMISSION_DENIED')) {
    return 'Your account does not have access to this area. $_supportContactMessage';
  }
  return 'This could not be completed right now. Please try again. $_supportContactMessage';
}

String displayPersonName(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return '';
  if (!raw.contains('@')) return raw;
  final localPart = raw.split('@').first.trim();
  if (localPart.isEmpty) return raw;
  return localPart
      .split(RegExp(r'[._-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

WorkOrder? _findOrder(String id, List<WorkOrder> orders) {
  for (final order in orders) {
    if (order.id == id) return order;
  }
  return null;
}

String _dateLabel(DateTime value) {
  return '${value.year}-${_two(value.month)}-${_two(value.day)}';
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${_dateLabel(value)} at $hour:${_two(value.minute)} $period';
}

String _formatWorkDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final days = safe.inDays;
  final hours = safe.inHours.remainder(24);
  final minutes = safe.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h ${minutes}m';
  if (safe.inHours > 0) return '${safe.inHours}h ${minutes}m';
  return '${safe.inMinutes}m';
}

String _timeLabel(DateTime value) {
  return '${_two(value.hour)}:${_two(value.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

Color _priorityColor(Priority priority) {
  return switch (priority) {
    Priority.critical => AppColors.danger,
    Priority.high => AppColors.warning,
    Priority.low => AppColors.success,
  };
}

Color _statusColor(String status) {
  final lower = status.toLowerCase();
  if (lower.contains('approved')) return AppColors.success;
  if (lower.contains('submitted')) return AppColors.warning;
  if (lower.contains('site')) return AppColors.primary;
  if (lower.contains('dispatch')) return const Color(0xFF3867B7);
  if (lower.contains('assigned')) return const Color(0xFF6750A4);
  return AppColors.primary;
}

String? _fieldString(Object? field) {
  if (field is! Map<String, dynamic>) return null;
  return field['stringValue'] as String?;
}

bool? _fieldBool(Object? field) {
  if (field is! Map<String, dynamic>) return null;
  return field['booleanValue'] as bool?;
}

DateTime? _fieldDate(Object? field) {
  if (field is! Map<String, dynamic>) return null;
  final value =
      field['timestampValue'] as String? ?? field['stringValue'] as String?;
  if (value == null) return null;
  return DateTime.tryParse(value)?.toLocal();
}

List<String> _fieldStringList(Object? field) {
  if (field is! Map<String, dynamic>) return const [];
  final values =
      (field['arrayValue'] as Map<String, dynamic>?)?['values']
          as List<dynamic>?;
  if (values == null) return const [];
  return values.map(_fieldString).whereType<String>().toList();
}

Map<String, String> _fieldStringMap(Object? field) {
  if (field is! Map<String, dynamic>) return const {};
  final fields =
      (field['mapValue'] as Map<String, dynamic>?)?['fields']
          as Map<String, dynamic>?;
  if (fields == null) return const {};
  final values = <String, String>{};
  for (final entry in fields.entries) {
    final value = _fieldString(entry.value);
    if (value != null) values[entry.key] = value;
  }
  return values;
}

Map<String, Object> _stringField(String value) => {'stringValue': value};
Map<String, Object> _boolField(bool value) => {'booleanValue': value};
Map<String, Object> _timestampField(DateTime value) => {
  'timestampValue': value.toUtc().toIso8601String(),
};
Map<String, Object> _arrayField(List<Map<String, Object>> values) => {
  'arrayValue': {'values': values},
};
Map<String, Object> _mapField(Map<String, String> values) => {
  'mapValue': {
    'fields': values.map((key, value) => MapEntry(key, _stringField(value))),
  },
};

Future<File?> _saveQrPdfAs(WorkOrder order) async {
  final path = await _pickQrPdfSavePath('${_safeQrFileId(order)}_site_qr.pdf');
  if (path == null) return null;
  final file = File(path);
  await file.writeAsBytes(await _buildQrPdfBytes(order), flush: true);
  return file;
}

Future<String?> _pickQrPdfSavePath(String suggestedName) async {
  final script =
      '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Title = 'Save site QR PDF'
\$dialog.Filter = 'PDF documents (*.pdf)|*.pdf'
\$dialog.DefaultExt = 'pdf'
\$dialog.AddExtension = \$true
\$dialog.OverwritePrompt = \$true
\$dialog.FileName = ${_powerShellLiteral(suggestedName)}
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$dialog.FileName
}
''';
  final encoded = base64Encode(_utf16LeBytes(script));
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-STA',
    '-EncodedCommand',
    encoded,
  ]).timeout(const Duration(minutes: 2));

  if (result.exitCode != 0) {
    final detail = result.stderr.toString().trim();
    throw ApiException(
      detail.isEmpty
          ? 'The save dialog could not be opened.'
          : 'The save dialog could not be opened: $detail',
    );
  }

  final path = result.stdout.toString().trim();
  if (path.isEmpty) return null;
  return path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
}

Future<File> _writeQrPdfAttachment(WorkOrder order) async {
  final temp = Directory.systemTemp;
  final file = File(
    '${temp.path}${Platform.pathSeparator}${_safeQrFileId(order)}_site_qr.pdf',
  );
  await file.writeAsBytes(await _buildQrPdfBytes(order), flush: true);
  return file;
}

String _safeQrFileId(WorkOrder order) {
  return order.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

Future<List<int>> _buildQrPdfBytes(WorkOrder order) async {
  final logoBytes = (await rootBundle.load(
    'assets/logo1.png',
  )).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final document = pw.Document();
  document.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(42),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: 76, height: 54, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 16),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PHEPHA MV ISDP',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text('Site identification QR'),
                ],
              ),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text('Work order: ${order.id}'),
          pw.Text('Site: ${order.site}'),
          pw.Text('Address: ${order.address}'),
          pw.Text('Site code: ${order.siteCode}'),
          pw.SizedBox(height: 28),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: order.qrPayload,
              width: 280,
              height: 280,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              order.siteCode,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Scan this QR at the site to identify the work order and verify the location.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );

  return document.save();
}

Future<void> _openOutlookDraftWithAttachment({
  required String recipient,
  required String subject,
  required String body,
  required String attachmentPath,
}) async {
  final script =
      '''
\$ErrorActionPreference = 'Stop'
\$outlook = New-Object -ComObject Outlook.Application
\$mail = \$outlook.CreateItem(0)
\$mail.To = ${_powerShellLiteral(recipient)}
\$mail.Subject = ${_powerShellLiteral(subject)}
\$mail.Body = ${_powerShellLiteral(body)}
[void]\$mail.Attachments.Add(${_powerShellLiteral(attachmentPath)})
if (\$mail.Attachments.Count -lt 1) {
  throw 'Outlook did not attach the QR PDF.'
}
\$mail.Display()
Write-Output 'ATTACHED'
''';
  final encoded = base64Encode(_utf16LeBytes(script));
  final result = await Process.run('powershell.exe', [
    '-NoProfile',
    '-STA',
    '-EncodedCommand',
    encoded,
  ]).timeout(const Duration(seconds: 30));

  if (result.exitCode != 0 || !result.stdout.toString().contains('ATTACHED')) {
    final detail = result.stderr.toString().trim();
    throw ApiException(
      detail.isEmpty
          ? 'Outlook could not create an email with the PDF attached. Make sure classic Outlook is installed and configured.'
          : 'Outlook could not attach the PDF: $detail',
    );
  }
}

String _powerShellLiteral(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

List<int> _utf16LeBytes(String value) {
  return value.codeUnits
      .expand((unit) => [unit & 0xff, (unit >> 8) & 0xff])
      .toList();
}
