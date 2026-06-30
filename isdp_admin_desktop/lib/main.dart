import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
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
  var _invoices = <Invoice>[];
  var _isLoading = true;
  var _isSyncing = false;
  String _search = '';
  String _status = 'All';
  WorkOrder? _selectedOrder;
  WorkOrder? _selectedChatOrder;
  final List<_AdminNotification> _notifications = [];
  var _technicians = <AdminUserProfile>[];
  var _isFetching = false;
  var _isFetchingInvoices = false;
  var _refreshQueued = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadInvoices();
    _loadTechnicians();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadOrders();
      _loadInvoices();
    });
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
              if (section != AdminSection.jobChats) _selectedChatOrder = null;
            }),
            onSignOut: widget.onSignOut,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: _selectedOrder == null
                      ? _selectedChatOrder == null
                            ? _section.label
                            : 'Job chat'
                      : 'Work order details',
                  isSyncing: _isSyncing,
                  onRefresh: _refreshAll,
                  onCreate: _showCreateJobDialog,
                  notificationCount: _notifications
                      .where((item) => !item.read)
                      .length,
                  onNotifications: _showNotifications,
                  onBack: _selectedOrder == null
                      ? _selectedChatOrder == null
                            ? null
                            : () => setState(() => _selectedChatOrder = null)
                      : () => setState(() => _selectedOrder = null),
                  backLabel: _selectedOrder == null
                      ? _selectedChatOrder == null
                            ? null
                            : 'Back to Job chats'
                      : 'Back to Work orders',
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
                onAction: _performAction,
                onAssign: () => _openAssign(_selectedOrder!),
                onShowQr: () => _showQrDialog(_selectedOrder!),
                onDelete: () => _confirmDeleteOrder(_selectedOrder!),
              ),
      AdminSection.jobChats =>
        _selectedChatOrder == null
            ? JobChatsView(
                orders: _orders,
                repository: widget.repository,
                session: widget.session,
                onOpen: _openJobChat,
              )
            : JobChatView(
                order: _selectedChatOrder!,
                repository: widget.repository,
                session: widget.session,
              ),
      AdminSection.teams => TeamsView(
        orders: _orders,
        technicians: _technicians,
        onAssign: _openAssign,
        onOpen: _openOrder,
        onViewProfile: _showTechnicianProfile,
        onChangeTeam: _changeTechnicianTeam,
      ),
      AdminSection.acceptance => AcceptanceView(
        orders: _orders,
        onApprove: (order) => _performAction(order, OrderAction.approve),
        onOpen: _openOrder,
      ),
      AdminSection.billing => BillingView(
        orders: _orders,
        invoices: _invoices,
        session: widget.session,
        onSave: _saveInvoice,
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

  void _openJobChat(WorkOrder order) {
    setState(() {
      _section = AdminSection.jobChats;
      _selectedChatOrder = order;
      _selectedOrder = null;
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

  void _refreshAll() {
    unawaited(_loadOrders());
    unawaited(_loadInvoices());
  }

  Future<void> _loadInvoices() async {
    if (_isFetchingInvoices) return;
    _isFetchingInvoices = true;
    try {
      final invoices = await widget.repository.fetchInvoices(widget.session);
      if (mounted) setState(() => _invoices = invoices);
    } catch (_) {
      // Keep the last successful billing view visible during refresh failures.
    } finally {
      _isFetchingInvoices = false;
    }
  }

  Future<void> _saveInvoice(Invoice invoice) async {
    await widget.repository.saveInvoice(widget.session, invoice);
    if (!mounted) return;
    setState(() {
      final index = _invoices.indexWhere((item) => item.id == invoice.id);
      if (index == -1) {
        _invoices = [invoice, ..._invoices];
      } else {
        _invoices = [..._invoices]..[index] = invoice;
      }
    });
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

  Future<void> _showTechnicianProfile(AdminUserProfile technician) {
    return showDialog<void>(
      context: context,
      builder: (context) => TechnicianProfileDialog(technician: technician),
    );
  }

  Future<void> _changeTechnicianTeam(AdminUserProfile technician) async {
    final teams =
        _technicians
            .map((person) => person.team?.trim() ?? '')
            .where((team) => team.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final team = await showDialog<String>(
      context: context,
      builder: (context) =>
          TechnicianTeamDialog(technician: technician, teams: teams),
    );
    if (team == null) return;

    setState(() => _isSyncing = true);
    try {
      await widget.repository.updateTechnicianTeam(
        widget.session,
        technician,
        team: team,
      );
      if (!mounted) return;
      setState(() {
        _technicians = _technicians
            .map(
              (person) => person.uid == technician.uid
                  ? person.copyWith(team: team)
                  : person,
            )
            .toList();
      });
      await _loadTechnicians();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${technician.name} assigned to $team.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
              ? const _EmptyState(message: 'No jobs found yet.')
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

class JobChatsView extends StatelessWidget {
  const JobChatsView({
    super.key,
    required this.orders,
    required this.repository,
    required this.session,
    required this.onOpen,
  });

  final List<WorkOrder> orders;
  final AdminRepository repository;
  final AuthSession session;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    final activeOrders =
        orders.where((order) => order.status != 'Approved').toList()
          ..sort(_compareChatActivity);

    return _Page(
      children: [
        _Panel(
          title: 'Job Chats',
          trailing: _DesktopUnreadTotalBadge(
            repository: repository,
            session: session,
            orders: activeOrders,
          ),
          child: activeOrders.isEmpty
              ? const _EmptyState(message: 'No active jobs available for chat.')
              : Column(
                  children: [
                    for (final order in activeOrders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _JobChatRow(
                          order: order,
                          repository: repository,
                          session: session,
                          onOpen: onOpen,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _JobChatRow extends StatelessWidget {
  const _JobChatRow({
    required this.order,
    required this.repository,
    required this.session,
    required this.onOpen,
  });

  final WorkOrder order;
  final AdminRepository repository;
  final AuthSession session;
  final ValueChanged<WorkOrder> onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _IconPill(
              icon: Icons.forum_outlined,
              color: _statusColor(order.status),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.id} - ${order.site}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _chatDetail(order),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _DesktopUnreadJobBadge(
              repository: repository,
              session: session,
              order: order,
            ),
            const SizedBox(width: 12),
            _StatusPill(label: order.status, color: _statusColor(order.status)),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => onOpen(order),
              icon: const Icon(Icons.chat_bubble_outline),
              label: _DesktopUnreadOpenChatLabel(
                repository: repository,
                session: session,
                order: order,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopUnreadTotalBadge extends StatelessWidget {
  const _DesktopUnreadTotalBadge({
    required this.repository,
    required this.session,
    required this.orders,
  });

  final AdminRepository repository;
  final AuthSession session;
  final List<WorkOrder> orders;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: Future.wait(
        orders.map(
          (order) => repository.fetchUnreadJobMessageCount(session, order.id),
        ),
      ).then((counts) => counts.fold<int>(0, (total, value) => total + value)),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Unread',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            _DesktopUnreadCountBadge(count: count),
          ],
        );
      },
    );
  }
}

class _DesktopUnreadJobBadge extends StatelessWidget {
  const _DesktopUnreadJobBadge({
    required this.repository,
    required this.session,
    required this.order,
  });

  final AdminRepository repository;
  final AuthSession session;
  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: repository.fetchUnreadJobMessageCount(session, order.id),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return _DesktopUnreadCountBadge(count: count);
      },
    );
  }
}

class _DesktopUnreadOpenChatLabel extends StatelessWidget {
  const _DesktopUnreadOpenChatLabel({
    required this.repository,
    required this.session,
    required this.order,
  });

  final AdminRepository repository;
  final AuthSession session;
  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: repository.fetchUnreadJobMessageCount(session, order.id),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const Text('Open chat');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Open chat'),
            const SizedBox(width: 8),
            _DesktopUnreadCountBadge(count: count),
          ],
        );
      },
    );
  }
}

class _DesktopUnreadCountBadge extends StatelessWidget {
  const _DesktopUnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

int _compareChatActivity(WorkOrder a, WorkOrder b) {
  final aTime = a.lastMessageAt;
  final bTime = b.lastMessageAt;
  if (aTime != null && bTime != null) return bTime.compareTo(aTime);
  if (aTime != null) return -1;
  if (bTime != null) return 1;
  return a.site.toLowerCase().compareTo(b.site.toLowerCase());
}

String _chatDetail(WorkOrder order) {
  final message = order.lastMessage?.trim();
  if (message?.isNotEmpty == true) {
    final sender = order.lastMessageBy?.trim();
    return sender?.isNotEmpty == true ? '$sender: $message' : message!;
  }
  return order.scope;
}

class JobChatView extends StatefulWidget {
  const JobChatView({
    super.key,
    required this.order,
    required this.repository,
    required this.session,
  });

  final WorkOrder order;
  final AdminRepository repository;
  final AuthSession session;

  @override
  State<JobChatView> createState() => _JobChatViewState();
}

class _JobChatViewState extends State<JobChatView> {
  final _messageController = TextEditingController();
  late Future<List<JobChatMessage>> _messagesFuture;
  Timer? _messagePoller;
  bool _refreshInProgress = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.repository.markJobChatRead(widget.session, widget.order.id),
    );
    _messagesFuture = _loadMessages();
    _messagePoller = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshMessages()),
    );
  }

  @override
  void didUpdateWidget(covariant JobChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      unawaited(
        widget.repository.markJobChatRead(widget.session, widget.order.id),
      );
      _messagesFuture = _loadMessages();
    }
  }

  @override
  void dispose() {
    _messagePoller?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.order.id} - ${widget.order.site}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _StatusPill(
              label: widget.order.status,
              color: _statusColor(widget.order.status),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Conversation',
          trailing: IconButton(
            tooltip: 'Refresh messages',
            onPressed: _refreshMessages,
            icon: const Icon(Icons.refresh),
          ),
          child: FutureBuilder<List<JobChatMessage>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const _EmptyState(
                  message: 'Could not load messages. $_supportContactMessage',
                );
              }
              final messages = snapshot.data ?? const [];
              if (messages.isEmpty) {
                return const _EmptyState(
                  message: 'No messages yet. Start the job conversation.',
                );
              }
              return Column(
                children: [
                  for (final message in messages)
                    _DesktopMessageBubble(
                      message: message,
                      mine: message.senderId == widget.session.uid,
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Send Message',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message this job',
                    prefixIcon: Icon(Icons.chat_outlined),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _sending ? null : _sendMessage,
                icon: Icon(_sending ? Icons.hourglass_empty : Icons.send),
                label: Text(_sending ? 'Sending' : 'Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<JobChatMessage>> _loadMessages() {
    return widget.repository.fetchJobMessages(widget.session, widget.order.id);
  }

  Future<void> _refreshMessages() async {
    if (!mounted || _refreshInProgress) return;
    _refreshInProgress = true;
    final nextMessages = _loadMessages();
    setState(() => _messagesFuture = nextMessages);
    try {
      await nextMessages;
      if (mounted) {
        unawaited(
          widget.repository.markJobChatRead(widget.session, widget.order.id),
        );
      }
    } catch (_) {
      // The FutureBuilder keeps the error state visible until the next poll.
    } finally {
      _refreshInProgress = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendJobMessage(
        widget.session,
        workOrderId: widget.order.id,
        message: text,
      );
      _messageController.clear();
      await _refreshMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message. $_supportContactMessage'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _DesktopMessageBubble extends StatelessWidget {
  const _DesktopMessageBubble({required this.message, required this.mine});

  final JobChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppColors.primary : const Color(0xFFF1F4F8);
    final textColor = mine ? Colors.white : AppColors.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.senderName.isEmpty
                        ? 'ISDP User'
                        : message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _dateTimeLabel(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(message.message, style: TextStyle(color: textColor)),
            const SizedBox(height: 6),
            Text(
              message.senderRole,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
    required this.onAction,
    required this.onAssign,
    required this.onShowQr,
    required this.onDelete,
  });

  final WorkOrder order;
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
    required this.technicians,
    required this.onAssign,
    required this.onOpen,
    required this.onViewProfile,
    required this.onChangeTeam,
  });

  final List<WorkOrder> orders;
  final List<AdminUserProfile> technicians;
  final ValueChanged<WorkOrder> onAssign;
  final ValueChanged<WorkOrder> onOpen;
  final ValueChanged<AdminUserProfile> onViewProfile;
  final ValueChanged<AdminUserProfile> onChangeTeam;

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
          child: technicians.isEmpty
              ? const _EmptyState(
                  message:
                      'No technicians are available. Add technician users first.',
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: technicians
                      .map(
                        (person) => _PersonCard(
                          person: person,
                          onViewProfile: () => onViewProfile(person),
                          onChangeTeam: () => onChangeTeam(person),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class TechnicianProfileDialog extends StatelessWidget {
  const TechnicianProfileDialog({super.key, required this.technician});

  final AdminUserProfile technician;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Technician Profile'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                technician.initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              technician.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              technician.email,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            _ProfileLine(label: 'Role', value: technician.role),
            _ProfileLine(label: 'Team', value: technician.teamLabel),
            _ProfileLine(label: 'User ID', value: technician.uid),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class TechnicianTeamDialog extends StatefulWidget {
  const TechnicianTeamDialog({
    super.key,
    required this.technician,
    required this.teams,
  });

  final AdminUserProfile technician;
  final List<String> teams;

  @override
  State<TechnicianTeamDialog> createState() => _TechnicianTeamDialogState();
}

class _TechnicianTeamDialogState extends State<TechnicianTeamDialog> {
  static const _newTeamValue = '__new_team__';

  late final TextEditingController _teamController;
  late String _selectedTeam;

  @override
  void initState() {
    super.initState();
    final currentTeam = widget.technician.team?.trim();
    _selectedTeam = currentTeam != null && widget.teams.contains(currentTeam)
        ? currentTeam
        : widget.teams.isNotEmpty
        ? widget.teams.first
        : _newTeamValue;
    _teamController = TextEditingController(
      text:
          currentTeam != null &&
              currentTeam.isNotEmpty &&
              !widget.teams.contains(currentTeam)
          ? currentTeam
          : '',
    );
  }

  @override
  void dispose() {
    _teamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign to Team'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedTeam,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Team',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              items: [
                for (final team in widget.teams)
                  DropdownMenuItem(value: team, child: Text(team)),
                const DropdownMenuItem(
                  value: _newTeamValue,
                  child: Text('New team'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedTeam = value);
              },
            ),
            if (_selectedTeam == _newTeamValue) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _teamController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'New team name',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                onSubmitted: (_) => _save(context),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => _save(context),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Save team'),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    final team = _selectedTeam == _newTeamValue
        ? _teamController.text.trim()
        : _selectedTeam.trim();
    if (team.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a team name.')));
      return;
    }
    Navigator.pop(context, team);
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

class BillingView extends StatefulWidget {
  const BillingView({
    super.key,
    required this.orders,
    required this.invoices,
    required this.session,
    required this.onSave,
    required this.onOpen,
  });

  final List<WorkOrder> orders;
  final List<Invoice> invoices;
  final AuthSession session;
  final Future<void> Function(Invoice invoice) onSave;
  final ValueChanged<WorkOrder> onOpen;

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  String _query = '';
  String _filter = 'All';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final invoices = _filteredInvoices();
    final outstanding = widget.invoices
        .where(
          (invoice) =>
              invoice.status == InvoiceStatus.issued && !invoice.isOverdue,
        )
        .fold<double>(0, (sum, invoice) => sum + invoice.total);
    final overdue = widget.invoices
        .where((invoice) => invoice.isOverdue)
        .toList();
    final overdueTotal = overdue.fold<double>(
      0,
      (sum, invoice) => sum + invoice.total,
    );
    final paidTotal = widget.invoices
        .where((invoice) => invoice.status == InvoiceStatus.paid)
        .fold<double>(0, (sum, invoice) => sum + invoice.total);
    final availableOrders = widget.orders.where((order) {
      if (order.status != 'Approved') return false;
      return !widget.invoices.any(
        (invoice) =>
            invoice.workOrderId == order.id &&
            invoice.status != InvoiceStatus.voided,
      );
    }).toList();

    return _Page(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              icon: Icons.edit_note_outlined,
              label: 'Drafts',
              value:
                  '${widget.invoices.where((invoice) => invoice.status == InvoiceStatus.draft).length}',
              detail: 'Waiting to be issued',
              color: AppColors.primary,
              onTap: () => setState(() => _filter = 'Draft'),
            ),
            _MetricCard(
              icon: Icons.schedule_outlined,
              label: 'Outstanding',
              value: _billingMoney(outstanding),
              detail: 'Issued and not due',
              color: AppColors.warning,
              onTap: () => setState(() => _filter = 'Issued'),
            ),
            _MetricCard(
              icon: Icons.error_outline,
              label: 'Overdue',
              value: _billingMoney(overdueTotal),
              detail: '${overdue.length} overdue invoices',
              color: AppColors.danger,
              onTap: () => setState(() => _filter = 'Overdue'),
            ),
            _MetricCard(
              icon: Icons.paid_outlined,
              label: 'Paid',
              value: _billingMoney(paidTotal),
              detail: 'Recorded receipts',
              color: AppColors.success,
              onTap: () => setState(() => _filter = 'Paid'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _Panel(
          title: 'Invoice Process',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InvoiceStep(
                number: '1',
                title: 'Draft',
                detail: 'Confirm customer, lines, tax, and due date',
              ),
              _InvoiceStep(
                number: '2',
                title: 'Issue',
                detail: 'Lock the invoice and send the PDF',
              ),
              _InvoiceStep(
                number: '3',
                title: 'Track',
                detail: 'Monitor outstanding and overdue invoices',
              ),
              _InvoiceStep(
                number: '4',
                title: 'Close',
                detail: 'Record payment or void the invoice',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Ready for Invoicing',
          trailing: const _StatusPill(
            label: 'Editable rates',
            color: AppColors.primary,
          ),
          child: availableOrders.isEmpty
              ? const _EmptyState(
                  message:
                      'Every approved work order already has an active invoice.',
                )
              : Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Start here: create a draft invoice from an approved job. Standard Rand rates are prefilled and can be edited before saving.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final order in availableOrders)
                      _BillableJobRow(
                        order: order,
                        onOpen: () => widget.onOpen(order),
                        onCreate: _saving ? null : () => _createInvoice(order),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Invoices',
          trailing: Text(
            '${invoices.length} ${invoices.length == 1 ? 'invoice' : 'invoices'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search invoice, job, or customer',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _filter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All invoices'),
                        ),
                        DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'Issued',
                          child: Text('Issued'),
                        ),
                        DropdownMenuItem(
                          value: 'Overdue',
                          child: Text('Overdue'),
                        ),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'Void', child: Text('Void')),
                      ],
                      onChanged: (value) => setState(() => _filter = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (invoices.isEmpty)
                const _EmptyState(
                  message:
                      'No invoices match this view. Create a draft from a billing-ready job below.',
                )
              else
                for (final invoice in invoices)
                  _InvoiceRow(
                    invoice: invoice,
                    busy: _saving,
                    onEdit: invoice.status == InvoiceStatus.draft
                        ? () => _editInvoice(invoice)
                        : null,
                    onIssue: invoice.status == InvoiceStatus.draft
                        ? () => _updateStatus(invoice, InvoiceStatus.issued)
                        : null,
                    onPaid:
                        invoice.status == InvoiceStatus.issued ||
                            invoice.isOverdue
                        ? () => _updateStatus(invoice, InvoiceStatus.paid)
                        : null,
                    onVoid:
                        invoice.status != InvoiceStatus.paid &&
                            invoice.status != InvoiceStatus.voided
                        ? () => _voidInvoice(invoice)
                        : null,
                    onPdf: () => _savePdf(invoice),
                    onEmail:
                        invoice.status == InvoiceStatus.issued ||
                            invoice.isOverdue
                        ? () => _emailInvoice(invoice)
                        : null,
                    onOpenJob: () => _openInvoiceJob(invoice),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  List<Invoice> _filteredInvoices() {
    final query = _query.trim().toLowerCase();
    return widget.invoices.where((invoice) {
      final matchesStatus = switch (_filter) {
        'Draft' => invoice.status == InvoiceStatus.draft,
        'Issued' =>
          invoice.status == InvoiceStatus.issued && !invoice.isOverdue,
        'Overdue' => invoice.isOverdue,
        'Paid' => invoice.status == InvoiceStatus.paid,
        'Void' => invoice.status == InvoiceStatus.voided,
        _ => true,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return [
        invoice.number,
        invoice.workOrderId,
        invoice.customerName,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _createInvoice(WorkOrder order) async {
    final now = DateTime.now();
    final serial = now.millisecondsSinceEpoch.toString().substring(6);
    final draft = Invoice(
      id: 'invoice-$serial',
      number: 'INV-${now.year}-$serial',
      workOrderId: order.id,
      customerName: order.customerName?.trim().isNotEmpty == true
          ? order.customerName!.trim()
          : order.site,
      customerEmail: '',
      customerAddress: order.address,
      items: [
        InvoiceLineItem(
          description: order.scope,
          quantity: 1,
          unitPrice: _standardBillingRate(order),
        ),
      ],
      taxRate: _standardBillingTaxRate,
      status: InvoiceStatus.draft,
      createdAt: now,
      dueAt: now.add(const Duration(days: 30)),
      createdBy: widget.session.uid,
    );
    await _showEditor(draft);
  }

  Future<void> _editInvoice(Invoice invoice) => _showEditor(invoice);

  Future<void> _showEditor(Invoice invoice) async {
    final result = await showDialog<Invoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => InvoiceEditorDialog(invoice: invoice),
    );
    if (result == null) return;
    await _persist(result, '${result.number} saved as a draft.');
  }

  Future<void> _updateStatus(Invoice invoice, InvoiceStatus status) async {
    if (status == InvoiceStatus.issued &&
        (invoice.customerEmail.trim().isEmpty ||
            invoice.items.isEmpty ||
            invoice.total <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the customer email, line items, and total before issuing.',
          ),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final updated = invoice.copyWith(
      status: status,
      issuedAt: status == InvoiceStatus.issued ? now : null,
      paidAt: status == InvoiceStatus.paid ? now : null,
      updatedAt: now,
    );
    final message = switch (status) {
      InvoiceStatus.issued => '${invoice.number} issued.',
      InvoiceStatus.paid => '${invoice.number} marked as paid.',
      _ => '${invoice.number} updated.',
    };
    await _persist(updated, message);
  }

  Future<void> _voidInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void invoice?'),
        content: Text(
          '${invoice.number} will remain in the audit history but will no longer be collectible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void invoice'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final now = DateTime.now();
    await _persist(
      invoice.copyWith(
        status: InvoiceStatus.voided,
        voidedAt: now,
        updatedAt: now,
      ),
      '${invoice.number} voided.',
    );
  }

  Future<void> _persist(Invoice invoice, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(invoice);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_invoiceSaveErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePdf(Invoice invoice) async {
    final order = _orderFor(invoice);
    if (order == null) return;
    try {
      final file = await _saveInvoicePdfAs(invoice, order);
      if (!mounted || file == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice saved to ${file.path}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The invoice PDF could not be saved. $_supportContactMessage',
          ),
        ),
      );
    }
  }

  Future<void> _emailInvoice(Invoice invoice) async {
    final order = _orderFor(invoice);
    if (order == null) return;
    if (invoice.customerEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a customer email before sending.')),
      );
      return;
    }
    try {
      final attachment = await _writeInvoicePdfAttachment(invoice, order);
      await _openOutlookDraftWithAttachment(
        recipient: invoice.customerEmail,
        subject: 'Invoice ${invoice.number} - PHEPHA MV ISDP',
        body:
            'Dear ${invoice.customerName},\r\n\r\n'
            'Please find attached invoice ${invoice.number} for ${_billingMoney(invoice.total)}. '
            'Payment is due by ${_dateLabel(invoice.dueAt)}.\r\n\r\n'
            'Please use ${invoice.number} as the payment reference.\r\n\r\n'
            'Regards,\r\nPHEPHA MV ISDP',
        attachmentPath: attachment.path,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice email draft opened in Outlook.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The invoice email could not be opened. $_supportContactMessage',
          ),
        ),
      );
    }
  }

  void _openInvoiceJob(Invoice invoice) {
    final order = _orderFor(invoice);
    if (order != null) widget.onOpen(order);
  }

  WorkOrder? _orderFor(Invoice invoice) {
    for (final order in widget.orders) {
      if (order.id == invoice.workOrderId) return order;
    }
    return null;
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
                detail: 'All work orders',
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
        status: 'New',
        priority: _priority,
        dueAt: _dueAt,
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
  Future<List<Invoice>> fetchInvoices(AuthSession session);
  Future<void> saveInvoice(AuthSession session, Invoice invoice);
  Future<List<AdminUserProfile>> fetchTechnicians(AuthSession session);
  Future<void> updateTechnicianTeam(
    AuthSession session,
    AdminUserProfile technician, {
    required String team,
  });
  Future<void> createWorkOrder(AuthSession session, WorkOrder order);
  Future<void> updateWorkOrder(
    AuthSession session,
    WorkOrder order, {
    required String action,
  });
  Future<void> deleteWorkOrder(AuthSession session, WorkOrder order);
  Future<int> fetchUnreadJobMessageCount(
    AuthSession session,
    String workOrderId,
  );
  Future<void> markJobChatRead(AuthSession session, String workOrderId);
  Future<List<JobChatMessage>> fetchJobMessages(
    AuthSession session,
    String workOrderId,
  );
  Future<void> sendJobMessage(
    AuthSession session, {
    required String workOrderId,
    required String message,
  });
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
  Future<List<Invoice>> fetchInvoices(AuthSession session) async {
    final invoices = <Invoice>[];
    String? pageToken;
    do {
      final query = <String, dynamic>{'pageSize': '100'};
      if (pageToken != null) query['pageToken'] = pageToken;
      final uri = _documentsUri('/invoices', query: query);
      final response = await _client.get(uri, headers: _headers(session));
      final body = _decode(response);
      if (response.statusCode >= 400) throw ApiException.fromBody(body);
      final documents = body['documents'] as List<dynamic>? ?? const [];
      invoices.addAll(
        documents.whereType<Map<String, dynamic>>().map(Invoice.fromDocument),
      );
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invoices;
  }

  @override
  Future<void> saveInvoice(AuthSession session, Invoice invoice) async {
    final uri = _documentsUri('/invoices/${invoice.id}');
    final response = await _client.patch(
      uri,
      headers: _headers(session),
      body: jsonEncode({'fields': invoice.toFields()}),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ApiException(
        'Invoice saving is not enabled for this admin account yet. Deploy the latest access rules and confirm this user has the admin role.',
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
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
  Future<void> updateTechnicianTeam(
    AuthSession session,
    AdminUserProfile technician, {
    required String team,
  }) async {
    final uri = _documentsUri(
      '/users/${technician.uid}',
      query: const {'updateMask.fieldPaths': 'team'},
    );
    final response = await _client.patch(
      uri,
      headers: _headers(session),
      body: jsonEncode({
        'fields': {'team': _stringField(team.trim())},
      }),
    );
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
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

  @override
  Future<int> fetchUnreadJobMessageCount(
    AuthSession session,
    String workOrderId,
  ) async {
    final readAt = await _fetchJobChatReadAt(session, workOrderId);
    final messages = await fetchJobMessages(session, workOrderId);
    return messages
        .where(
          (message) =>
              message.senderId != session.uid &&
              (readAt == null || message.createdAt.isAfter(readAt)),
        )
        .length;
  }

  @override
  Future<void> markJobChatRead(AuthSession session, String workOrderId) async {
    final uri = _documentsUri(
      '/work_orders/$workOrderId/chat_reads/${session.uid}',
    );
    final response = await _client.patch(
      uri,
      headers: _headers(session),
      body: jsonEncode({
        'fields': {
          'userId': _stringField(session.uid),
          'readAt': _timestampField(DateTime.now()),
        },
      }),
    );
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }
  }

  Future<DateTime?> _fetchJobChatReadAt(
    AuthSession session,
    String workOrderId,
  ) async {
    final uri = _documentsUri(
      '/work_orders/$workOrderId/chat_reads/${session.uid}',
    );
    final response = await _client.get(uri, headers: _headers(session));
    if (response.statusCode == 404) return null;
    final body = _decode(response);
    if (response.statusCode >= 400) throw ApiException.fromBody(body);
    final fields = body['fields'] as Map<String, dynamic>? ?? const {};
    return _fieldDate(fields['readAt']);
  }

  @override
  Future<List<JobChatMessage>> fetchJobMessages(
    AuthSession session,
    String workOrderId,
  ) async {
    final uri = _documentsUri(
      '/work_orders/$workOrderId/messages',
      query: const {'pageSize': '100'},
    );
    final response = await _client.get(uri, headers: _headers(session));
    final body = _decode(response);
    if (response.statusCode >= 400) throw ApiException.fromBody(body);

    final documents = (body['documents'] as List<dynamic>? ?? const []);
    final messages =
        documents
            .whereType<Map<String, dynamic>>()
            .map(JobChatMessage.fromFirestoreDocument)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  @override
  Future<void> sendJobMessage(
    AuthSession session, {
    required String workOrderId,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final uri = _documentsUri('/work_orders/$workOrderId/messages');
    final now = DateTime.now();
    final response = await _client.post(
      uri,
      headers: _headers(session),
      body: jsonEncode({
        'fields': {
          'workOrderId': _stringField(workOrderId),
          'senderId': _stringField(session.uid),
          'senderName': _stringField(displayPersonName(session.email)),
          'senderRole': _stringField('Admin'),
          'message': _stringField(trimmed),
          'createdAt': _timestampField(now),
        },
      }),
    );
    if (response.statusCode >= 400) {
      throw ApiException.fromBody(_decode(response));
    }

    final updateUri = _documentsUri(
      '/work_orders/$workOrderId',
      query: {
        'updateMask.fieldPaths': [
          'lastMessage',
          'lastMessageAt',
          'lastMessageBy',
        ],
      },
    );
    final updateResponse = await _client.patch(
      updateUri,
      headers: _headers(session),
      body: jsonEncode({
        'fields': {
          'lastMessage': _stringField(trimmed),
          'lastMessageAt': _timestampField(now),
          'lastMessageBy': _stringField(displayPersonName(session.email)),
        },
      }),
    );
    if (updateResponse.statusCode >= 400) {
      throw ApiException.fromBody(_decode(updateResponse));
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

  String get teamLabel => team?.isNotEmpty == true ? team! : 'Unassigned team';

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  AdminUserProfile copyWith({String? team}) {
    return AdminUserProfile(
      uid: uid,
      email: email,
      name: name,
      role: role,
      team: team ?? this.team,
    );
  }

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

enum InvoiceStatus {
  draft('Draft'),
  issued('Issued'),
  paid('Paid'),
  voided('Void');

  const InvoiceStatus(this.label);
  final String label;

  static InvoiceStatus fromString(String? value) {
    return InvoiceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InvoiceStatus.draft,
    );
  }
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  double get total => quantity * unitPrice;

  Map<String, Object> toFieldValue() => {
    'mapValue': {
      'fields': {
        'description': _stringField(description),
        'quantity': _doubleField(quantity),
        'unitPrice': _doubleField(unitPrice),
      },
    },
  };

  factory InvoiceLineItem.fromFieldValue(Object? value) {
    final mapValue = value is Map<String, dynamic>
        ? value['mapValue'] as Map<String, dynamic>?
        : null;
    final fields = mapValue?['fields'] as Map<String, dynamic>? ?? const {};
    return InvoiceLineItem(
      description: _fieldString(fields['description']) ?? 'Service',
      quantity: _fieldDouble(fields['quantity']) ?? 1,
      unitPrice: _fieldDouble(fields['unitPrice']) ?? 0,
    );
  }
}

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.workOrderId,
    required this.customerName,
    required this.customerEmail,
    required this.customerAddress,
    required this.items,
    required this.taxRate,
    required this.status,
    required this.createdAt,
    required this.dueAt,
    required this.createdBy,
    this.notes = '',
    this.issuedAt,
    this.paidAt,
    this.voidedAt,
    this.updatedAt,
  });

  final String id;
  final String number;
  final String workOrderId;
  final String customerName;
  final String customerEmail;
  final String customerAddress;
  final List<InvoiceLineItem> items;
  final double taxRate;
  final InvoiceStatus status;
  final DateTime createdAt;
  final DateTime dueAt;
  final String createdBy;
  final String notes;
  final DateTime? issuedAt;
  final DateTime? paidAt;
  final DateTime? voidedAt;
  final DateTime? updatedAt;

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get taxAmount => subtotal * taxRate;
  double get total => subtotal + taxAmount;
  bool get isOverdue =>
      status == InvoiceStatus.issued && dueAt.isBefore(DateTime.now());
  String get displayStatus => isOverdue ? 'Overdue' : status.label;

  Invoice copyWith({
    String? number,
    String? customerName,
    String? customerEmail,
    String? customerAddress,
    List<InvoiceLineItem>? items,
    double? taxRate,
    InvoiceStatus? status,
    DateTime? dueAt,
    String? notes,
    DateTime? issuedAt,
    DateTime? paidAt,
    DateTime? voidedAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id,
      number: number ?? this.number,
      workOrderId: workOrderId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      taxRate: taxRate ?? this.taxRate,
      status: status ?? this.status,
      createdAt: createdAt,
      dueAt: dueAt ?? this.dueAt,
      createdBy: createdBy,
      notes: notes ?? this.notes,
      issuedAt: issuedAt ?? this.issuedAt,
      paidAt: paidAt ?? this.paidAt,
      voidedAt: voidedAt ?? this.voidedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object> toFields() {
    final fields = <String, Object>{
      'number': _stringField(number),
      'workOrderId': _stringField(workOrderId),
      'customerName': _stringField(customerName),
      'customerEmail': _stringField(customerEmail),
      'customerAddress': _stringField(customerAddress),
      'items': _arrayField(items.map((item) => item.toFieldValue()).toList()),
      'taxRate': _doubleField(taxRate),
      'subtotal': _doubleField(subtotal),
      'taxAmount': _doubleField(taxAmount),
      'total': _doubleField(total),
      'status': _stringField(status.name),
      'createdAt': _timestampField(createdAt),
      'dueAt': _timestampField(dueAt),
      'createdBy': _stringField(createdBy),
      'notes': _stringField(notes),
      'updatedAt': _timestampField(updatedAt ?? DateTime.now()),
    };
    if (issuedAt != null) fields['issuedAt'] = _timestampField(issuedAt!);
    if (paidAt != null) fields['paidAt'] = _timestampField(paidAt!);
    if (voidedAt != null) fields['voidedAt'] = _timestampField(voidedAt!);
    return fields;
  }

  factory Invoice.fromDocument(Map<String, dynamic> document) {
    final name = document['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = document['fields'] as Map<String, dynamic>? ?? const {};
    final array = fields['items'] is Map<String, dynamic>
        ? (fields['items'] as Map<String, dynamic>)['arrayValue']
              as Map<String, dynamic>?
        : null;
    final values = array?['values'] as List<dynamic>? ?? const [];
    return Invoice(
      id: id,
      number: _fieldString(fields['number']) ?? id,
      workOrderId: _fieldString(fields['workOrderId']) ?? '',
      customerName: _fieldString(fields['customerName']) ?? 'Customer',
      customerEmail: _fieldString(fields['customerEmail']) ?? '',
      customerAddress: _fieldString(fields['customerAddress']) ?? '',
      items: values.map(InvoiceLineItem.fromFieldValue).toList(),
      taxRate: _fieldDouble(fields['taxRate']) ?? _standardBillingTaxRate,
      status: InvoiceStatus.fromString(_fieldString(fields['status'])),
      createdAt: _fieldDate(fields['createdAt']) ?? DateTime.now(),
      dueAt:
          _fieldDate(fields['dueAt']) ??
          DateTime.now().add(const Duration(days: 30)),
      createdBy: _fieldString(fields['createdBy']) ?? 'admin',
      notes: _fieldString(fields['notes']) ?? '',
      issuedAt: _fieldDate(fields['issuedAt']),
      paidAt: _fieldDate(fields['paidAt']),
      voidedAt: _fieldDate(fields['voidedAt']),
      updatedAt: _fieldDate(fields['updatedAt']),
    );
  }
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
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageBy,
    this.chatMessageCount = 0,
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
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageBy;
  final int chatMessageCount;

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
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageBy,
    int? chatMessageCount,
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
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      chatMessageCount: chatMessageCount ?? this.chatMessageCount,
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
      lastMessage: _fieldString(fields['lastMessage']),
      lastMessageAt: _fieldDate(fields['lastMessageAt']),
      lastMessageBy: displayPersonName(_fieldString(fields['lastMessageBy'])),
      chatMessageCount: _fieldInt(fields['chatMessageCount']) ?? 0,
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

class JobChatMessage {
  const JobChatMessage({
    required this.id,
    required this.workOrderId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String workOrderId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  factory JobChatMessage.fromFirestoreDocument(Map<String, dynamic> document) {
    final name = document['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = document['fields'] as Map<String, dynamic>? ?? const {};
    return JobChatMessage(
      id: id,
      workOrderId: _fieldString(fields['workOrderId']) ?? '',
      senderId: _fieldString(fields['senderId']) ?? '',
      senderName: displayPersonName(_fieldString(fields['senderName'])),
      senderRole: _fieldString(fields['senderRole']) ?? 'User',
      message: _fieldString(fields['message']) ?? '',
      createdAt: _fieldDate(fields['createdAt']) ?? DateTime.now(),
    );
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
  jobChats('Job chats', Icons.forum_outlined),
  teams('Field teams', Icons.people_alt_outlined),
  acceptance('Acceptance', Icons.fact_check_outlined),
  billing('Billing & Invoices', Icons.receipt_long_outlined),
  analytics('Analytics', Icons.query_stats_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;

  String get subtitle {
    return switch (this) {
      AdminSection.dashboard => 'Overview and alerts',
      AdminSection.workOrders => 'Create and manage jobs',
      AdminSection.jobChats => 'Live site conversations',
      AdminSection.teams => 'Assign field technicians',
      AdminSection.acceptance => 'Review submitted work',
      AdminSection.billing => 'Draft, issue, and track',
      AdminSection.analytics => 'Performance reports',
    };
  }
}

enum OrderAction { accept, assign, markOnsite, markSubmitted, review, approve }

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
              subtitle: section.subtitle,
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
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
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
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
    this.backLabel,
  });

  final String title;
  final bool isSyncing;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback? onBack;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
      child: Row(
        children: [
          if (onBack != null) ...[
            FilledButton.tonalIcon(
              onPressed: onBack,
              label: Text(backLabel ?? 'Back'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filledTonal(
            onPressed: isSyncing ? null : onRefresh,
            tooltip: 'Refresh data',
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
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

class _InvoiceStep extends StatelessWidget {
  const _InvoiceStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: Text(number),
          ),
          const SizedBox(width: 10),
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
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _InvoiceMenuAction { edit, issue, paid, pdf, email, voidInvoice }

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.busy,
    required this.onEdit,
    required this.onIssue,
    required this.onPaid,
    required this.onVoid,
    required this.onPdf,
    required this.onEmail,
    required this.onOpenJob,
  });

  final Invoice invoice;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onIssue;
  final VoidCallback? onPaid;
  final VoidCallback? onVoid;
  final VoidCallback onPdf;
  final VoidCallback? onEmail;
  final VoidCallback onOpenJob;

  @override
  Widget build(BuildContext context) {
    final color = switch (invoice.displayStatus) {
      'Paid' => AppColors.success,
      'Overdue' => AppColors.danger,
      'Issued' => AppColors.warning,
      'Void' => AppColors.muted,
      _ => AppColors.primary,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: onOpenJob,
      leading: _IconPill(icon: Icons.receipt_long_outlined, color: color),
      title: Text(
        '${invoice.number} - ${invoice.customerName}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${invoice.workOrderId} | Due ${_dateLabel(invoice.dueAt)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _billingMoney(invoice.total),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 10),
          _StatusPill(label: invoice.displayStatus, color: color),
          const SizedBox(width: 4),
          PopupMenuButton<_InvoiceMenuAction>(
            enabled: !busy,
            tooltip: 'Invoice actions',
            onSelected: (action) {
              switch (action) {
                case _InvoiceMenuAction.edit:
                  onEdit?.call();
                case _InvoiceMenuAction.issue:
                  onIssue?.call();
                case _InvoiceMenuAction.paid:
                  onPaid?.call();
                case _InvoiceMenuAction.pdf:
                  onPdf();
                case _InvoiceMenuAction.email:
                  onEmail?.call();
                case _InvoiceMenuAction.voidInvoice:
                  onVoid?.call();
              }
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                const PopupMenuItem(
                  value: _InvoiceMenuAction.edit,
                  child: Text('Edit draft'),
                ),
              if (onIssue != null)
                const PopupMenuItem(
                  value: _InvoiceMenuAction.issue,
                  child: Text('Issue invoice'),
                ),
              if (onPaid != null)
                const PopupMenuItem(
                  value: _InvoiceMenuAction.paid,
                  child: Text('Mark as paid'),
                ),
              const PopupMenuItem(
                value: _InvoiceMenuAction.pdf,
                child: Text('Save PDF'),
              ),
              if (onEmail != null)
                const PopupMenuItem(
                  value: _InvoiceMenuAction.email,
                  child: Text('Email invoice'),
                ),
              if (onVoid != null)
                const PopupMenuItem(
                  value: _InvoiceMenuAction.voidInvoice,
                  child: Text('Void invoice'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillableJobRow extends StatelessWidget {
  const _BillableJobRow({
    required this.order,
    required this.onOpen,
    required this.onCreate,
  });

  final WorkOrder order;
  final VoidCallback onOpen;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      onTap: onOpen,
      leading: _IconPill(
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      title: Text(
        '${order.id} - ${order.site}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(order.scope, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'From ${_billingMoney(_standardBillingRate(order))}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create draft'),
          ),
        ],
      ),
    );
  }
}

class InvoiceEditorDialog extends StatefulWidget {
  const InvoiceEditorDialog({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoiceEditorDialog> createState() => _InvoiceEditorDialogState();
}

class _InvoiceEditorDialogState extends State<InvoiceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _customer;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _taxRate;
  late final TextEditingController _notes;
  late DateTime _dueAt;
  late final List<_InvoiceItemControllers> _items;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _number = TextEditingController(text: invoice.number);
    _customer = TextEditingController(text: invoice.customerName);
    _email = TextEditingController(text: invoice.customerEmail);
    _address = TextEditingController(text: invoice.customerAddress);
    _taxRate = TextEditingController(
      text: (invoice.taxRate * 100).toStringAsFixed(0),
    );
    _notes = TextEditingController(text: invoice.notes);
    _dueAt = invoice.dueAt;
    _items = invoice.items.map(_InvoiceItemControllers.fromItem).toList();
    if (_items.isEmpty) _items.add(_InvoiceItemControllers.empty());
  }

  @override
  void dispose() {
    _number.dispose();
    _customer.dispose();
    _email.dispose();
    _address.dispose();
    _taxRate.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _parsedItems().fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final taxRate = (double.tryParse(_taxRate.text) ?? 0) / 100;
    final tax = subtotal * taxRate;
    return AlertDialog(
      title: Text('Invoice draft - ${widget.invoice.workOrderId}'),
      content: SizedBox(
        width: 860,
        height: 610,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _requiredField(_number, 'Invoice number')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Payment due date',
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(_dateLabel(_dueAt)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _requiredField(_customer, 'Customer name')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Customer email',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Customer email is required.';
                          }
                          if (!text.contains('@')) {
                            return 'Enter a valid email.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _requiredField(_address, 'Billing address', maxLines: 2),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Line Items',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _items.add(_InvoiceItemControllers.empty()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add line'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _items.length; index++)
                  _itemRow(index),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Payment terms or notes',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _taxRate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Tax rate (%)',
                              suffixText: '%',
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final rate = double.tryParse(value ?? '');
                              if (rate == null || rate < 0 || rate > 100) {
                                return 'Enter a rate from 0 to 100.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _InvoiceTotalLine(
                            'Subtotal',
                            _billingMoney(subtotal),
                          ),
                          _InvoiceTotalLine('Tax', _billingMoney(tax)),
                          _InvoiceTotalLine(
                            'Total',
                            _billingMoney(subtotal + tax),
                            strong: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save draft'),
        ),
      ],
    );
  }

  Widget _requiredField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label is required.' : null,
    );
  }

  Widget _itemRow(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _requiredField(item.description, 'Description')),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: TextFormField(
              controller: item.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity'),
              onChanged: (_) => setState(() {}),
              validator: _positiveNumberValidator,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: TextFormField(
              controller: item.unitPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Unit price',
                prefixText: 'R ',
              ),
              onChanged: (_) => setState(() {}),
              validator: _positiveNumberValidator,
            ),
          ),
          IconButton(
            tooltip: 'Remove line',
            onPressed: _items.length == 1
                ? null
                : () => setState(() {
                    _items.removeAt(index).dispose();
                  }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  String? _positiveNumberValidator(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || number <= 0 ? 'Enter a value above zero.' : null;
  }

  List<InvoiceLineItem> _parsedItems() {
    return _items
        .map(
          (item) => InvoiceLineItem(
            description: item.description.text.trim(),
            quantity: double.tryParse(item.quantity.text) ?? 0,
            unitPrice: double.tryParse(item.unitPrice.text) ?? 0,
          ),
        )
        .toList();
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) setState(() => _dueAt = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.invoice.copyWith(
        number: _number.text.trim(),
        customerName: _customer.text.trim(),
        customerEmail: _email.text.trim(),
        customerAddress: _address.text.trim(),
        items: _parsedItems(),
        taxRate: (double.parse(_taxRate.text) / 100),
        dueAt: _dueAt,
        notes: _notes.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _InvoiceItemControllers {
  _InvoiceItemControllers({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  factory _InvoiceItemControllers.fromItem(InvoiceLineItem item) {
    return _InvoiceItemControllers(
      description: TextEditingController(text: item.description),
      quantity: TextEditingController(text: item.quantity.toString()),
      unitPrice: TextEditingController(text: item.unitPrice.toStringAsFixed(2)),
    );
  }

  factory _InvoiceItemControllers.empty() {
    return _InvoiceItemControllers(
      description: TextEditingController(),
      quantity: TextEditingController(text: '1'),
      unitPrice: TextEditingController(text: '0.00'),
    );
  }

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _InvoiceTotalLine extends StatelessWidget {
  const _InvoiceTotalLine(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 17 : null,
            ),
          ),
        ],
      ),
    );
  }
}

const double _standardBillingTaxRate = 0.15;

double _standardBillingRate(WorkOrder order) {
  return switch (order.priority) {
    Priority.critical => 2500,
    Priority.high => 1800,
    Priority.low => 1200,
  };
}

String _billingMoney(num value) => 'R ${value.toStringAsFixed(2)}';

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
    required this.person,
    required this.onViewProfile,
    required this.onChangeTeam,
  });

  final AdminUserProfile person;
  final VoidCallback onViewProfile;
  final VoidCallback onChangeTeam;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: ListTile(
        leading: _IconPill(
          icon: Icons.person_outline,
          color: AppColors.primary,
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${person.teamLabel}\n${person.email}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'View profile',
              onPressed: onViewProfile,
              icon: const Icon(Icons.badge_outlined),
            ),
            IconButton(
              tooltip: 'Assign to team',
              onPressed: onChangeTeam,
              icon: const Icon(Icons.groups_outlined),
            ),
          ],
        ),
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

String _invoiceSaveErrorMessage(Object error) {
  final raw = error is ApiException ? error.message.trim() : '';
  if (raw.isNotEmpty &&
      !raw.contains('PERMISSION_DENIED') &&
      !raw.contains('INVALID_ARGUMENT')) {
    return raw;
  }
  return 'The invoice could not be saved. Confirm this admin account has invoice access, then try again. $_supportContactMessage';
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

int? _fieldInt(Object? field) {
  if (field is! Map<String, dynamic>) return null;
  final integerValue = field['integerValue'];
  if (integerValue is int) return integerValue;
  if (integerValue is String) return int.tryParse(integerValue);
  final doubleValue = field['doubleValue'];
  if (doubleValue is num) return doubleValue.toInt();
  return null;
}

double? _fieldDouble(Object? field) {
  if (field is! Map<String, dynamic>) return null;
  final doubleValue = field['doubleValue'];
  if (doubleValue is num) return doubleValue.toDouble();
  if (doubleValue is String) return double.tryParse(doubleValue);
  final integerValue = field['integerValue'];
  if (integerValue is num) return integerValue.toDouble();
  if (integerValue is String) return double.tryParse(integerValue);
  return null;
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
Map<String, Object> _doubleField(double value) => {'doubleValue': value};
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

Future<File?> _saveInvoicePdfAs(Invoice invoice, WorkOrder order) async {
  final safeNumber = invoice.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final path = await _pickPdfSavePath(
    '${safeNumber}_invoice.pdf',
    title: 'Save invoice PDF',
  );
  if (path == null) return null;
  final file = File(path);
  await file.writeAsBytes(
    await buildInvoicePdfBytes(invoice, order),
    flush: true,
  );
  return file;
}

Future<File> _writeInvoicePdfAttachment(
  Invoice invoice,
  WorkOrder order,
) async {
  final safeNumber = invoice.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}${safeNumber}_invoice.pdf',
  );
  await file.writeAsBytes(
    await buildInvoicePdfBytes(invoice, order),
    flush: true,
  );
  return file;
}

Future<List<int>> buildInvoicePdfBytes(Invoice invoice, WorkOrder order) async {
  final logoBytes = (await rootBundle.load(
    'assets/logo1.png',
  )).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final document = pw.Document(
    title: invoice.number,
    author: 'PHEPHA MV ISDP',
    subject: 'Invoice for ${invoice.workOrderId}',
  );
  final accent = PdfColors.blueGrey800;
  final muted = PdfColors.grey700;
  final statusColor = switch (invoice.displayStatus) {
    'Paid' => PdfColors.green700,
    'Overdue' => PdfColors.red700,
    'Void' => PdfColors.grey700,
    'Issued' => PdfColors.orange700,
    _ => PdfColors.blue700,
  };

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 38, 42, 38),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'PHEPHA MV ISDP | Support: $_supportContactNumber',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Image(logo, width: 72, height: 52, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PHEPHA MV ISDP',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    pw.Text(
                      'Field service operations',
                      style: pw.TextStyle(color: muted),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                  ),
                ),
                pw.Text(invoice.number),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: statusColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    invoice.displayStatus.toUpperCase(),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('BILL TO', accent),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    invoice.customerName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (invoice.customerAddress.isNotEmpty)
                    pw.Text(invoice.customerAddress),
                  if (invoice.customerEmail.isNotEmpty)
                    pw.Text(invoice.customerEmail),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1.4),
                },
                children: [
                  _pdfDetailRow('Invoice date', _dateLabel(invoice.createdAt)),
                  _pdfDetailRow('Due date', _dateLabel(invoice.dueAt)),
                  _pdfDetailRow('Work order', invoice.workOrderId),
                  _pdfDetailRow('Site', order.site),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: const pw.BorderSide(color: PdfColors.grey300),
            bottom: const pw.BorderSide(color: PdfColors.grey400),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(4.6),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: accent),
              children: [
                _pdfTableCell('DESCRIPTION', header: true),
                _pdfTableCell('QTY', header: true, right: true),
                _pdfTableCell('UNIT PRICE', header: true, right: true),
                _pdfTableCell('AMOUNT', header: true, right: true),
              ],
            ),
            for (final item in invoice.items)
              pw.TableRow(
                children: [
                  _pdfTableCell(item.description),
                  _pdfTableCell(_invoiceQuantity(item.quantity), right: true),
                  _pdfTableCell(_billingMoney(item.unitPrice), right: true),
                  _pdfTableCell(_billingMoney(item.total), right: true),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('PAYMENT DETAILS', accent),
                  pw.SizedBox(height: 5),
                  pw.Text('Use ${invoice.number} as the payment reference.'),
                  pw.Text('Payment is due by ${_dateLabel(invoice.dueAt)}.'),
                  if (invoice.notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    _pdfLabel('NOTES', accent),
                    pw.SizedBox(height: 5),
                    pw.Text(invoice.notes.trim()),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 28),
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  _pdfTotalRow('Subtotal', _billingMoney(invoice.subtotal)),
                  _pdfTotalRow(
                    'Tax (${(invoice.taxRate * 100).toStringAsFixed(1)}%)',
                    _billingMoney(invoice.taxAmount),
                  ),
                  pw.Divider(color: accent),
                  _pdfTotalRow(
                    'TOTAL',
                    _billingMoney(invoice.total),
                    strong: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Text(
            'Thank you. Please quote the invoice number on all payment correspondence.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, color: muted),
          ),
        ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _pdfLabel(String text, PdfColor color) => pw.Text(
  text,
  style: pw.TextStyle(
    color: color,
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    letterSpacing: 0.7,
  ),
);

pw.TableRow _pdfDetailRow(String label, String value) => pw.TableRow(
  children: [
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ),
  ],
);

pw.Widget _pdfTableCell(
  String value, {
  bool header = false,
  bool right = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
  child: pw.Text(
    value,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      fontSize: header ? 8 : 9,
      color: header ? PdfColors.white : PdfColors.black,
      fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

pw.Widget _pdfTotalRow(String label, String value, {bool strong = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: strong ? 12 : 9,
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: strong ? 12 : 9,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

String _invoiceQuantity(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

Future<File?> _saveQrPdfAs(WorkOrder order) async {
  final path = await _pickPdfSavePath(
    '${_safeQrFileId(order)}_site_qr.pdf',
    title: 'Save site QR PDF',
  );
  if (path == null) return null;
  final file = File(path);
  await file.writeAsBytes(await _buildQrPdfBytes(order), flush: true);
  return file;
}

Future<String?> _pickPdfSavePath(
  String suggestedName, {
  required String title,
}) async {
  final script =
      '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Title = ${_powerShellLiteral(title)}
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
  throw 'Outlook did not attach the PDF.'
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
