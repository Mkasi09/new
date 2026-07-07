import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/app_role.dart';
import '../../../core/support/support_contact.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/mock_isdp_repository.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'account_view.dart';
import 'add_user_screen.dart';
import 'admin_job_screen.dart';
import 'analytics_view.dart';
import 'assign_technician_screen.dart';
import 'create_job_screen.dart';
import 'completion_details_screen.dart';
import 'dashboard_view.dart';
import 'decline_job_screen.dart';
import 'empty_jobs_view.dart';
import 'job_chat_screen.dart';
import 'job_chats_screen.dart';
import 'mobile_billing_preview.dart';
import 'qr_arrival_scan_screen.dart';
import 'review_job_screen.dart';
import 'review_queue_screen.dart';
import 'supervisor_job_screen.dart';
import 'supervisor_queue_screen.dart';
import 'support_inbox_screen.dart';
import 'upload_evidence_screen.dart';
import 'work_orders_view.dart';

enum _WorkflowView {
  createJob,
  assignTechnician,
  scanQr,
  uploadEvidence,
  completionDetails,
  analytics,
  reviewQueue,
  reviewJob,
  declineJob,
  billingPreview,
  jobChats,
  supportInbox,
  supervisorQueue,
  supervisorJob,
  addUser,
}

class IsdpShell extends StatefulWidget {
  const IsdpShell({
    super.key,
    this.initialRole,
    this.userProfile,
    this.authRepository,
    this.isdpRepository,
  });

  final AppRole? initialRole;
  final AppUserProfile? userProfile;
  final AuthRepository? authRepository;
  final IsdpRepository? isdpRepository;

  @override
  State<IsdpShell> createState() => _IsdpShellState();
}

class _IsdpShellState extends State<IsdpShell> {
  int _tab = 0;
  late final AppRole _role = widget.initialRole ?? AppRole.technician;
  late final IsdpRepository _repository =
      widget.isdpRepository ?? const MockIsdpRepository();
  late List<WorkOrder> _workOrders = List.of(_repository.getWorkOrders());
  String? _selectedOrderId;
  _WorkflowView? _workflowView;
  WorkOrder? _assigningOrder;
  WorkOrder? _scanningOrder;
  WorkOrder? _uploadingOrder;
  String? _uploadingEvidenceSlot;
  WorkOrder? _completionOrder;
  WorkOrder? _reviewingOrder;
  WorkOrder? _supervisorOrder;
  WorkOrder? _adminOrder;
  bool _returnToReviewQueue = false;
  Completer<bool?>? _scanCompleter;
  Completer<List<String>?>? _uploadCompleter;
  final List<_AppNotification> _notifications = [];
  final Map<String, WorkOrder> _knownOrders = {};
  final Set<String> _notificationKeys = {};
  final Set<String> _readNotificationKeys = {};
  final Set<String> _pendingCreateIds = {};
  final List<_NavigationSnapshot> _navigationHistory = [];
  List<AppUserProfile> _technicians = const [];
  bool _notificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    if (_role != AppRole.technician) {
      unawaited(_loadTechnicians());
    }
    unawaited(_loadReadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePhoneBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const _AppBarBrandTitle(),
          actions: [
            StreamBuilder<SyncStatus>(
              stream: _repository.watchSyncStatus(),
              initialData: SyncStatus.online,
              builder: (context, snapshot) {
                final status = snapshot.data ?? SyncStatus.online;
                return status == SyncStatus.offline
                    ? _SyncStatusButton(status: status)
                    : const SizedBox.shrink();
              },
            ),
            _NotificationButton(
              count: _notifications.where((item) => !item.read).length,
              onPressed: _showNotifications,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: StreamBuilder<List<WorkOrder>>(
          stream: _repository.watchWorkOrders(),
          initialData: _workOrders,
          builder: (context, snapshot) {
            final liveOrders = _mergeWorkOrders(snapshot.data ?? const []);
            final visibleOrders = _visibleOrdersForRole(liveOrders);
            final waitingForJobs =
                snapshot.connectionState == ConnectionState.waiting &&
                visibleOrders.isEmpty;
            // The initialData value is only a rendering placeholder. Using it
            // as the notification baseline makes every existing Firestore job
            // look new when the app is installed with an empty local cache.
            if (snapshot.connectionState == ConnectionState.active) {
              _observeOrderNotifications(visibleOrders);
            }
            final selectedOrder = _selectedOrder(visibleOrders);
            final workflowPage = _buildWorkflowPage(visibleOrders);
            final pages = [
              if (workflowPage != null)
                workflowPage
              else if (waitingForJobs)
                const _JobsLoadingView()
              else if (selectedOrder == null)
                EmptyJobsView(
                  role: _role,
                  onCreateJob: _openCreateJobScreen,
                  onOpenReviewQueue: _role == AppRole.admin
                      ? _openReviewQueueScreen
                      : null,
                  onOpenAnalytics: _role == AppRole.admin
                      ? _openAnalyticsScreen
                      : null,
                  onAddUser: _role == AppRole.admin
                      ? widget.authRepository == null
                            ? null
                            : _openAddUserScreen
                      : null,
                )
              else
                DashboardView(
                  role: _role,
                  selectedOrder: selectedOrder,
                  workOrders: visibleOrders,
                  repository: _repository,
                  jobSteps: _repository.getJobSteps(),
                  materials: _repository.getMaterials(),
                  onOpenOrder: _openOrder,
                  onCreateJob: _openCreateJobScreen,
                  onOpenAnalytics: _openAnalyticsScreen,
                  onOpenReviewQueue: _openReviewQueueScreen,
                  onOpenBilling: mobileBillingPreviewEnabled
                      ? _openBillingPreview
                      : null,
                  onAddUser: widget.authRepository == null
                      ? null
                      : _openAddUserScreen,
                  onOpenTeamQueue: _openSupervisorQueueScreen,
                  onOpenSupervisorJob: _openSupervisorJobScreen,
                  onAcceptOrder: _acceptOrder,
                  onOpenReviewOrder: _openReviewScreen,
                  onAssignOrder: _assignOrder,
                  onScanArrival: _scanArrival,
                  onUploadEvidence: _uploadEvidence,
                  onOpenCompletionDetails: _openCompletionDetails,
                  onSubmitCompletion: _submitCompletion,
                  onCloseDeclinedJob: _closeDeclinedJob,
                  onOpenJobChat: _openJobChat,
                  onOpenJobChats: _openJobChatsScreen,
                  onOpenSupportInbox: _openSupportInboxScreen,
                ),
              if (_role == AppRole.admin && _adminOrder != null)
                _buildAdminJobPage(visibleOrders)
              else
                WorkOrdersView(
                  role: _role,
                  workOrders: visibleOrders,
                  onOpenOrder: _openOrder,
                ),
              AccountView(
                role: _role,
                userProfile: widget.userProfile,
                authRepository: widget.authRepository,
                repository: _repository,
              ),
            ];

            return pages[_tab];
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int value) {
    if (value == _tab) return;
    _rememberNavigation();
    setState(() {
      _tab = value;
      if (value != 1) {
        _adminOrder = null;
      }
      if (value != 0) {
        _clearWorkflowState();
      }
    });
  }

  Future<void> _handlePhoneBack() async {
    if (_navigationHistory.isNotEmpty) {
      _navigateBack();
      return;
    }
    if (_workflowView != null) {
      _closeWorkflow();
      return;
    }
    if (_adminOrder != null) {
      _closeAdminJob();
      return;
    }
    if (_tab != 0) {
      _selectTab(0);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to close PHEPHA MV ISDP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (exit == true) {
      SystemNavigator.pop();
    }
  }

  void _clearWorkflowState() {
    _workflowView = null;
    _assigningOrder = null;
    _scanningOrder = null;
    _uploadingOrder = null;
    _uploadingEvidenceSlot = null;
    _completionOrder = null;
    _reviewingOrder = null;
    _supervisorOrder = null;
    _returnToReviewQueue = false;
    final completer = _scanCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _scanCompleter = null;
    final uploadCompleter = _uploadCompleter;
    if (uploadCompleter != null && !uploadCompleter.isCompleted) {
      uploadCompleter.complete(null);
    }
    _uploadCompleter = null;
  }

  void _rememberNavigation() {
    _navigationHistory.add(
      _NavigationSnapshot(
        tab: _tab,
        workflowView: _workflowView,
        selectedOrderId: _selectedOrderId,
        assigningOrder: _assigningOrder,
        scanningOrder: _scanningOrder,
        uploadingOrder: _uploadingOrder,
        uploadingEvidenceSlot: _uploadingEvidenceSlot,
        completionOrder: _completionOrder,
        reviewingOrder: _reviewingOrder,
        supervisorOrder: _supervisorOrder,
        adminOrder: _adminOrder,
        returnToReviewQueue: _returnToReviewQueue,
      ),
    );
  }

  void _navigateBack() {
    if (_navigationHistory.isEmpty) {
      _closeWorkflow();
      return;
    }
    final scanCompleter = _scanCompleter;
    if (scanCompleter != null && !scanCompleter.isCompleted) {
      scanCompleter.complete(null);
    }
    final uploadCompleter = _uploadCompleter;
    if (uploadCompleter != null && !uploadCompleter.isCompleted) {
      uploadCompleter.complete(null);
    }
    _scanCompleter = null;
    _uploadCompleter = null;
    final previous = _navigationHistory.removeLast();
    setState(() {
      _tab = previous.tab;
      _workflowView = previous.workflowView;
      _selectedOrderId = previous.selectedOrderId;
      _assigningOrder = previous.assigningOrder;
      _scanningOrder = previous.scanningOrder;
      _uploadingOrder = previous.uploadingOrder;
      _uploadingEvidenceSlot = previous.uploadingEvidenceSlot;
      _completionOrder = previous.completionOrder;
      _reviewingOrder = previous.reviewingOrder;
      _supervisorOrder = previous.supervisorOrder;
      _adminOrder = previous.adminOrder;
      _returnToReviewQueue = previous.returnToReviewQueue;
    });
  }

  WorkOrder? _selectedOrder(List<WorkOrder> orders) {
    if (orders.isEmpty) return null;
    if (_selectedOrderId != null) {
      return orders.firstWhere(
        (order) => order.id == _selectedOrderId,
        orElse: () => _preferredOrder(orders),
      );
    }
    return _preferredOrder(orders);
  }

  WorkOrder _preferredOrder(List<WorkOrder> orders) {
    if (_role == AppRole.supervisor) {
      return orders.firstWhere(
        (order) => order.status == 'Assigned to Supervisor',
        orElse: () => orders.first,
      );
    }
    return orders.first;
  }

  List<WorkOrder> _visibleOrdersForRole(List<WorkOrder> orders) {
    return switch (_role) {
      AppRole.admin => orders,
      AppRole.supervisor =>
        orders
            .where(
              (order) =>
                  _matchesCurrentSupervisor(order, includeUnassigned: true),
            )
            .toList(),
      AppRole.technician =>
        orders
            .where(
              (order) =>
                  _matchesCurrentTechnician(order) &&
                  (order.status == 'Dispatched' ||
                      order.status == 'On Site' ||
                      order.status == 'Submitted' ||
                      order.status == 'Declined' ||
                      order.status == 'Declined - Closed' ||
                      order.status == 'Approved'),
            )
            .toList(),
    };
  }

  bool _matchesCurrentUser(String? value, {bool includeUnassigned = false}) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return includeUnassigned;

    final profile = widget.userProfile;
    if (profile == null) return true;
    return normalized == profile.uid.toLowerCase() ||
        normalized == profile.name.trim().toLowerCase() ||
        normalized == profile.email.trim().toLowerCase();
  }

  bool _matchesCurrentTechnician(WorkOrder order) {
    final profile = widget.userProfile;
    if (profile == null) return true;
    final values = [
      ...order.assignedTechnicianIds,
      order.assignedTo,
      ...order.assignedTechnicians,
      ...order.technicianNames,
    ];
    return values.any((value) => _matchesCurrentUser(value));
  }

  bool _matchesCurrentSupervisor(
    WorkOrder order, {
    bool includeUnassigned = false,
  }) {
    final profile = widget.userProfile;
    if (profile == null) return true;
    if (order.supervisorId?.trim().isNotEmpty == true) {
      return order.supervisorId!.trim().toLowerCase() ==
          profile.uid.trim().toLowerCase();
    }
    return _matchesCurrentUser(
      order.supervisor,
      includeUnassigned: includeUnassigned,
    );
  }

  Future<void> _loadTechnicians() async {
    final authRepository = widget.authRepository;
    if (authRepository == null) return;
    try {
      final users = await authRepository.listUsers();
      if (!mounted) return;
      setState(() {
        _technicians = users
            .where((user) => user.role == AppRole.technician)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _technicians = const []);
    }
  }

  List<WorkOrder> _mergeWorkOrders(List<WorkOrder> repositoryOrders) {
    final localById = {for (final order in _workOrders) order.id: order};
    final repositoryById = {
      for (final order in repositoryOrders) order.id: order,
    };
    return {...localById.keys, ...repositoryById.keys}.map((id) {
      final local = localById[id];
      final remote = repositoryById[id];
      if (local == null) return remote!;
      if (remote == null) return local;
      return _mergeWorkOrder(local: local, remote: remote);
    }).toList();
  }

  WorkOrder _mergeWorkOrder({
    required WorkOrder local,
    required WorkOrder remote,
  }) {
    final evidenceSlots = {
      ...remote.evidenceSlots,
      ...local.evidenceSlots,
    }.toList();
    final hasLocalSubmit =
        local.submittedAt != null && remote.submittedAt == null;

    return remote.copyWith(
      status: hasLocalSubmit ? local.status : remote.status,
      sla: hasLocalSubmit ? local.sla : remote.sla,
      submittedAt: remote.submittedAt ?? local.submittedAt,
      arrivalVerified: remote.arrivalVerified || local.arrivalVerified,
      evidenceUploaded: remote.evidenceUploaded || local.evidenceUploaded,
      evidenceSlots: evidenceSlots,
      evidencePhotos: {...remote.evidencePhotos, ...local.evidencePhotos},
      technicianNotes: _preferSavedText(
        remote.technicianNotes,
        local.technicianNotes,
      ),
      issueReport: _preferSavedText(remote.issueReport, local.issueReport),
      customerName: _preferSavedText(remote.customerName, local.customerName),
      customerSignature: _preferSavedText(
        remote.customerSignature,
        local.customerSignature,
      ),
      assignedTechnicians: {
        ...remote.assignedTechnicians,
        ...local.assignedTechnicians,
      }.toList(),
      reviewed: hasLocalSubmit ? local.reviewed : remote.reviewed,
    );
  }

  String? _preferSavedText(String? remote, String? local) {
    if (remote?.trim().isNotEmpty == true) return remote;
    if (local?.trim().isNotEmpty == true) return local;
    return remote ?? local;
  }

  Widget? _buildWorkflowPage(List<WorkOrder> visibleOrders) {
    return switch (_workflowView) {
      _WorkflowView.analytics => AnalyticsView(
        role: _role,
        workOrders: visibleOrders,
        onOpenJob: _openJobFromAnalytics,
        onClose: _navigateBack,
      ),
      _WorkflowView.reviewQueue => ReviewQueueScreen(
        orders: visibleOrders,
        onOpenReview: _openReviewScreenFromQueue,
        onClose: _navigateBack,
      ),
      _WorkflowView.jobChats => JobChatsScreen(
        orders: visibleOrders,
        repository: _repository,
        onOpenChat: _openJobChat,
        onClose: _navigateBack,
      ),
      _WorkflowView.supportInbox => SupportInboxScreen(
        repository: _repository,
        onClose: _navigateBack,
      ),
      _WorkflowView.supervisorQueue => SupervisorQueueScreen(
        orders: visibleOrders,
        onOpenJob: _openSupervisorJobScreen,
        onClose: _navigateBack,
      ),
      _WorkflowView.supervisorJob => _buildSupervisorJobPage(visibleOrders),
      _WorkflowView.createJob => CreateJobScreen(
        onCreated: _createJob,
        onCancel: _navigateBack,
      ),
      _WorkflowView.addUser when widget.authRepository != null => AddUserScreen(
        authRepository: widget.authRepository!,
        onClose: _closeAddUserScreen,
      ),
      _WorkflowView.assignTechnician when _assigningOrder != null =>
        AssignTechnicianScreen(
          order: _assigningOrder!,
          technicians: _technicians,
          onTechniciansAssigned: _completeAssignment,
          onCancel: _navigateBack,
        ),
      _WorkflowView.scanQr when _scanningOrder != null => QrArrivalScanScreen(
        order: _scanningOrder!,
        onMatched: _completeScan,
        onCancel: _cancelScan,
      ),
      _WorkflowView.uploadEvidence when _uploadingOrder != null =>
        UploadEvidenceScreen(
          order: _uploadingOrder!,
          targetSlot: _uploadingEvidenceSlot,
          onCompleted: _completeUpload,
          onCancel: _cancelUpload,
        ),
      _WorkflowView.completionDetails when _completionOrder != null =>
        CompletionDetailsScreen(
          order: _completionOrder!,
          onSaved: _saveCompletionDetails,
          onCancel: _navigateBack,
        ),
      _WorkflowView.reviewJob => _buildReviewPage(visibleOrders),
      _WorkflowView.declineJob when _reviewingOrder != null => DeclineJobScreen(
        order: _reviewingOrder!,
        onDecline: _completeDecline,
        onCancel: _openReviewAfterDeclineCancel,
      ),
      _WorkflowView.billingPreview => MobileBillingPreview(
        orders: visibleOrders,
        onClose: _navigateBack,
        onOpenJob: _openAdminJob,
      ),
      _ => null,
    };
  }

  Widget? _buildSupervisorJobPage(List<WorkOrder> visibleOrders) {
    final supervisorOrder = _supervisorOrder;
    if (supervisorOrder == null) return null;
    final order = visibleOrders.firstWhere(
      (candidate) => candidate.id == supervisorOrder.id,
      orElse: () => supervisorOrder,
    );

    return SupervisorJobScreen(
      order: order,
      onAccept: () => _acceptOrder(order),
      onAssign: () => _assignOrder(order),
      onOpenChat: () => _openJobChat(order),
      unreadChatStream: _repository.watchUnreadJobMessageCount(order.id),
      onClose: _navigateBack,
    );
  }

  Widget _buildAdminJobPage(List<WorkOrder> visibleOrders) {
    final adminOrder = _adminOrder!;
    final order = visibleOrders.firstWhere(
      (candidate) => candidate.id == adminOrder.id,
      orElse: () => adminOrder,
    );

    return AdminJobScreen(
      order: order,
      onSendQr: () => _sendQr(order),
      onReview: () => _openReviewScreen(order),
      onOpenChat: () => _openJobChat(order),
      unreadChatStream: _repository.watchUnreadJobMessageCount(order.id),
      onDelete: () => _confirmDeleteOrder(order),
      onClose: _navigateBack,
    );
  }

  Widget? _buildReviewPage(List<WorkOrder> visibleOrders) {
    final reviewingOrder = _reviewingOrder;
    if (reviewingOrder == null) return null;
    final order = visibleOrders.firstWhere(
      (candidate) => candidate.id == reviewingOrder.id,
      orElse: () => reviewingOrder,
    );

    return ReviewJobScreen(
      order: order,
      onApprove: () => _approveFromReview(order),
      onDecline: () => _openDeclineScreen(order),
      onClose: _navigateBack,
    );
  }

  void _closeWorkflow() {
    if (_navigationHistory.isNotEmpty) {
      _navigationHistory.removeLast();
    }
    setState(() {
      _workflowView = null;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _uploadingEvidenceSlot = null;
      _completionOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
    });
  }

  void _closeAddUserScreen() {
    _navigateBack();
    unawaited(_loadTechnicians());
  }

  void _openOrder(WorkOrder order) {
    if (_role == AppRole.admin && _tab == 1) {
      _openAdminJob(order);
      return;
    }
    if (_role == AppRole.supervisor) {
      _openSupervisorJobScreen(order);
      return;
    }
    _rememberNavigation();
    setState(() {
      _selectedOrderId = order.id;
      _tab = 0;
    });
  }

  void _openJobFromAnalytics(WorkOrder order) {
    if (_role == AppRole.admin) {
      _openAdminJob(order);
      return;
    }
    if (_role == AppRole.supervisor) {
      _openSupervisorJobScreen(order);
      return;
    }
    _openOrder(order);
  }

  void _openAdminJob(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _adminOrder = order;
      _selectedOrderId = order.id;
      _tab = 1;
      _clearWorkflowState();
    });
  }

  void _openJobChat(WorkOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => JobChatScreen(
          order: order,
          repository: _repository,
          userProfile: widget.userProfile,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _closeAdminJob() {
    setState(() => _adminOrder = null);
  }

  Future<void> _confirmDeleteOrder(WorkOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text(
          'Delete ${order.id} for ${order.site}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteOrder(order);
  }

  Future<void> _deleteOrder(WorkOrder order) async {
    try {
      await _repository.deleteWorkOrder(order);
      if (!mounted) return;
      _knownOrders.remove(order.id);
      _notificationKeys.removeWhere((key) => key.startsWith('${order.id}:'));
      _readNotificationKeys.removeWhere(
        (key) => key.startsWith('${order.id}:'),
      );
      unawaited(_saveReadNotifications());
      setState(() {
        _workOrders = _workOrders
            .where((candidate) => candidate.id != order.id)
            .toList();
        _selectedOrderId = _selectedOrderId == order.id
            ? null
            : _selectedOrderId;
        if (_adminOrder?.id == order.id) _adminOrder = null;
        _notifications.removeWhere((item) => item.orderId == order.id);
        _tab = 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${order.id} deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this job. $supportContactMessage'),
        ),
      );
    }
  }

  Future<void> _sendQr(WorkOrder order) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PHEPHA MV ISDP Job QR',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(order.site, style: const pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 6),
            pw.Text(order.address),
            pw.SizedBox(height: 6),
            pw.Text(order.id),
            pw.SizedBox(height: 32),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: order.siteCode,
                width: 240,
                height: 240,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text('Scan this QR on site to confirm technician arrival.'),
          ],
        ),
      ),
    );

    Printing.sharePdf(bytes: await pdf.save(), filename: '${order.id}_qr.pdf');
  }

  void _replaceOrder(WorkOrder updated) {
    _knownOrders[updated.id] = updated;
    setState(() {
      _workOrders = _workOrders
          .map((order) => order.id == updated.id ? updated : order)
          .toList();
      _selectedOrderId = updated.id;
    });
  }

  void _openCreateJobScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.createJob;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openAnalyticsScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.analytics;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openBillingPreview() {
    _rememberNavigation();
    setState(() {
      _clearWorkflowState();
      _workflowView = _WorkflowView.billingPreview;
      _tab = 0;
    });
  }

  void _openAddUserScreen() {
    _rememberNavigation();
    setState(() {
      _clearWorkflowState();
      _workflowView = _WorkflowView.addUser;
      _tab = 0;
    });
  }

  void _openReviewQueueScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.reviewQueue;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openJobChatsScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.jobChats;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openSupportInboxScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.supportInbox;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openSupervisorQueueScreen() {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.supervisorQueue;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openSupervisorJobScreen(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.supervisorJob;
      _supervisorOrder = order;
      _selectedOrderId = order.id;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  void _openReviewScreen(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.reviewJob;
      _reviewingOrder = order;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
    unawaited(_reviewOrder(order));
  }

  void _openReviewScreenFromQueue(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.reviewJob;
      _reviewingOrder = order;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = true;
      _tab = 0;
    });
    unawaited(_reviewOrder(order));
  }

  Future<void> _createJob(WorkOrder created) async {
    if (!_pendingCreateIds.add(created.id)) return;

    try {
      final saved = await _repository.createWorkOrder(created);
      if (!mounted) return;
      _knownOrders[saved.id] = saved;
      if (_navigationHistory.isNotEmpty) _navigationHistory.removeLast();
      setState(() {
        _workOrders = [
          saved,
          ..._workOrders.where((order) => order.id != saved.id),
        ];
        _selectedOrderId = saved.id;
        _workflowView = null;
        _tab = 0;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create job. Check the network and retry. $supportContactMessage',
          ),
        ),
      );
    } finally {
      _pendingCreateIds.remove(created.id);
    }
  }

  Future<void> _acceptOrder(WorkOrder order) async {
    final supervisor = widget.userProfile?.name.trim().isNotEmpty == true
        ? widget.userProfile!.name.trim()
        : displayPersonName(order.supervisor);
    final accepted = order.copyWith(
      status: 'Accepted by Supervisor',
      supervisor: supervisor,
      supervisorId: widget.userProfile?.uid,
    );
    await _repository.acceptWorkOrder(accepted);
    _replaceOrder(accepted);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id} accepted by supervisor.')),
    );
  }

  Future<void> _approveOrder(WorkOrder order) async {
    final approved = order.copyWith(
      status: 'Approved',
      sla: 'Approved',
      approvedAt: DateTime.now(),
    );
    await _repository.approveWorkOrder(order);
    _replaceOrder(approved);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${order.id} approved by Admin.')));
  }

  Future<void> _reviewOrder(WorkOrder order) async {
    if (order.reviewed) return;
    final reviewed = order.copyWith(reviewed: true, reviewedAt: DateTime.now());
    await _repository.reviewWorkOrder(order);
    _replaceOrder(reviewed);
  }

  Future<void> _assignOrder(WorkOrder order) async {
    if (order.status == 'Assigned to Supervisor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the job before dispatching a technician.'),
        ),
      );
      return;
    }

    await _loadTechnicians();
    if (!mounted) return;
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.assignTechnician;
      _assigningOrder = order;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
  }

  Future<void> _completeAssignment(
    List<AppUserProfile> assignedTechnicians,
  ) async {
    final order = _assigningOrder;
    if (order == null) return;
    final names =
        assignedTechnicians
            .map((technician) => displayPersonName(technician.name))
            .toSet()
            .toList()
          ..sort();
    final ids =
        assignedTechnicians
            .map((technician) => technician.uid)
            .where((uid) => uid.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (ids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify the technician.')),
      );
      return;
    }
    final assigned = order.copyWith(
      status: 'Dispatched',
      assignedTo: names.join(', '),
      assignedTechnicians: names,
      assignedTechnicianIds: ids,
    );
    await _repository.assignWorkOrder(assigned);
    _replaceOrder(assigned);
    _closeWorkflow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id} assigned to technician.')),
    );
  }

  Future<bool?> _scanArrival(WorkOrder order) {
    _scanCompleter?.complete(null);
    final completer = Completer<bool?>();
    _rememberNavigation();
    setState(() {
      _scanCompleter = completer;
      _workflowView = _WorkflowView.scanQr;
      _scanningOrder = order;
      _assigningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
    return completer.future;
  }

  void _completeScan(bool matched) {
    final order = _scanningOrder;
    if (matched && order != null) {
      final onsite = order.copyWith(
        status: 'On Site',
        arrivalVerified: true,
        arrivedAt: DateTime.now(),
      );
      _repository.markOnsite(order);
      _replaceOrder(onsite);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arrival confirmed. Upload the before photo when work starts.',
          ),
        ),
      );
    }

    final completer = _scanCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(matched);
    }
    _scanCompleter = null;
    _navigateBack();
  }

  void _cancelScan() {
    final completer = _scanCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _scanCompleter = null;
    _navigateBack();
  }

  Future<List<String>?> _uploadEvidence(WorkOrder order, String? slot) {
    _uploadCompleter?.complete(null);
    final completer = Completer<List<String>?>();
    _rememberNavigation();
    setState(() {
      _uploadCompleter = completer;
      _workflowView = _WorkflowView.uploadEvidence;
      _uploadingOrder = order;
      _uploadingEvidenceSlot = slot;
      _assigningOrder = null;
      _scanningOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
    return completer.future;
  }

  void _completeUpload(
    List<String> evidenceSlots,
    Map<String, String> evidencePhotos,
  ) async {
    final order = _uploadingOrder;
    if (order != null) {
      final uploaded = const ['before', 'after'].every(evidenceSlots.contains);
      final mergedPhotos = {...order.evidencePhotos, ...evidencePhotos};
      final updated = order.copyWith(
        evidenceSlots: evidenceSlots,
        evidencePhotos: mergedPhotos,
        evidenceUploaded: uploaded,
      );
      try {
        await _repository.saveEvidence(
          order,
          evidenceSlots,
          evidencePhotos: evidencePhotos,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save uploaded evidence. $supportContactMessage',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      _replaceOrder(updated);
    }
    final completer = _uploadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(evidenceSlots);
    }
    _uploadCompleter = null;
    _navigateBack();
  }

  void _cancelUpload() {
    final completer = _uploadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _uploadCompleter = null;
    _navigateBack();
  }

  Future<void> _submitCompletion(WorkOrder order) async {
    if (order.technicianNotes?.trim().isEmpty != false ||
        order.customerName?.trim().isEmpty != false ||
        order.customerSignature?.isEmpty != false) {
      _openCompletionDetails(order);
      return;
    }
    final isResubmission = order.status == 'Declined';
    final complete = order.copyWith(
      status: 'Submitted',
      sla: 'Ready for approval',
      evidenceUploaded: true,
      reviewed: false,
      submittedAt: DateTime.now(),
    );
    unawaited(_repository.submitCompletion(complete));
    _replaceOrder(complete);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isResubmission
              ? '${order.id} resubmitted for Admin approval.'
              : '${order.id} submitted for Admin approval.',
        ),
      ),
    );
  }

  Future<void> _closeDeclinedJob(WorkOrder order) async {
    if (order.status != 'Declined') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close declined job?'),
        content: const Text(
          'This ends the job without resubmitting it for approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close Job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.closeWorkOrder(order);
    _replaceOrder(order.copyWith(status: 'Closed', isOpen: false));
  }

  void _observeOrderNotifications(List<WorkOrder> orders) {
    final current = {for (final order in orders) order.id: order};
    if (!_notificationsInitialized) {
      _knownOrders
        ..clear()
        ..addAll(current);
      _notificationsInitialized = true;
      return;
    }

    final updates = <_AppNotification>[];
    for (final order in orders) {
      final previous = _knownOrders[order.id];
      if (previous == null) {
        updates.add(
          _AppNotification(
            key: _newNotificationKey(order),
            orderId: order.id,
            title: 'New work order',
            message: '${order.site} has been added to your queue.',
            createdAt: DateTime.now(),
            type: _NotificationType.assignment,
            read: _isNotificationRead(_newNotificationKey(order)),
          ),
        );
        continue;
      }

      if (previous.issueReport != order.issueReport &&
          order.issueReport?.trim().isNotEmpty == true) {
        final key = _issueNotificationKey(order);
        updates.add(
          _AppNotification(
            key: key,
            orderId: order.id,
            title: 'Issue reported',
            message: '${order.site}: ${order.issueReport!.trim()}',
            createdAt: DateTime.now(),
            type: _NotificationType.issue,
            read: _isNotificationRead(key),
          ),
        );
      }

      if (previous.status != order.status) {
        updates.add(_statusNotification(order));
      }

      if (previous.technicianLabel != order.technicianLabel &&
          order.technicianLabel != null) {
        final key = _assignedNotificationKey(order);
        updates.add(
          _AppNotification(
            key: key,
            orderId: order.id,
            title: 'Technician assigned',
            message: '${order.site} assigned to ${order.technicianLabel}.',
            createdAt: DateTime.now(),
            type: _NotificationType.assignment,
            read: _isNotificationRead(key),
          ),
        );
      }

      if (previous.customerSignature != order.customerSignature &&
          order.customerSignature?.isNotEmpty == true) {
        updates.add(
          _AppNotification(
            key: _signoffNotificationKey(order),
            orderId: order.id,
            title: 'Customer sign-off captured',
            message: '${order.site} completion details are ready.',
            createdAt: DateTime.now(),
            type: _NotificationType.success,
            read: _isNotificationRead(_signoffNotificationKey(order)),
          ),
        );
      }
    }
    _knownOrders
      ..clear()
      ..addAll(current);
    if (updates.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uniqueUpdates = updates
          .where((item) => _notificationKeys.add(item.key))
          .toList();
      if (uniqueUpdates.isEmpty) return;
      setState(() {
        _notifications.insertAll(0, uniqueUpdates);
        if (_notifications.length > 30) {
          final removed = _notifications.sublist(30);
          _notifications.removeRange(30, _notifications.length);
          for (final item in removed) {
            _notificationKeys.remove(item.key);
          }
        }
      });
    });
  }

  Future<void> _showNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final hasUnread = _notifications.any((item) => !item.read);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activity Centre',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Recent job updates and required actions',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (hasUnread)
                          TextButton(
                            onPressed: () {
                              setState(_markAllNotificationsRead);
                              setSheetState(() {});
                            },
                            child: const Text('Mark all read'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _notifications.isEmpty
                        ? const _NotificationEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final item = _notifications[index];
                              return _NotificationCard(
                                notification: item,
                                onTap: () {
                                  setState(() => _markNotificationRead(item));
                                  Navigator.pop(context);
                                  _openNotificationTarget(item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openNotificationTarget(_AppNotification notification) {
    final order =
        _knownOrders[notification.orderId] ??
        _workOrders.cast<WorkOrder?>().firstWhere(
          (order) => order?.id == notification.orderId,
          orElse: () => null,
        );
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This job is no longer in your queue.')),
      );
      return;
    }

    if (_role == AppRole.admin) {
      if (notification.type == _NotificationType.action ||
          order.status == 'Submitted') {
        _openReviewScreen(order);
      } else {
        _openAdminJob(order);
      }
      return;
    }

    if (_role == AppRole.supervisor) {
      _openSupervisorJobScreen(order);
      return;
    }

    _openOrder(order);
  }

  _AppNotification _statusNotification(WorkOrder order) {
    final type = switch (order.status) {
      'Approved' => _NotificationType.success,
      'Submitted' => _NotificationType.action,
      'Dispatched' || 'On Site' => _NotificationType.progress,
      _ => _NotificationType.info,
    };
    final title = switch (order.status) {
      'Approved' => 'Job approved',
      'Submitted' => 'Job submitted',
      'Dispatched' => 'Technician dispatched',
      'On Site' => 'Arrival confirmed',
      _ => 'Job status updated',
    };
    return _AppNotification(
      key: _statusNotificationKey(order),
      orderId: order.id,
      title: title,
      message: '${order.site} is now ${order.status.toLowerCase()}.',
      createdAt: DateTime.now(),
      type: type,
      read: _isNotificationRead(_statusNotificationKey(order)),
    );
  }

  Future<void> _loadReadNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_readNotificationsStorageKey);
    if (saved == null || !mounted) return;
    setState(() {
      _readNotificationKeys
        ..clear()
        ..addAll(saved);
      for (final item in _notifications) {
        item.read = _isNotificationRead(item.key);
      }
    });
  }

  Future<void> _saveReadNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _readNotificationsStorageKey,
      _readNotificationKeys.take(300).toList(growable: false),
    );
  }

  String get _readNotificationsStorageKey {
    final userKey =
        widget.userProfile?.uid ?? widget.userProfile?.email ?? 'local';
    return 'isdp_read_notifications_$userKey';
  }

  bool _isNotificationRead(String key) => _readNotificationKeys.contains(key);

  void _markNotificationRead(_AppNotification item) {
    _readNotificationKeys.add(item.key);
    _notifications.removeWhere((notification) => notification.key == item.key);
    _notificationKeys.remove(item.key);
    unawaited(_saveReadNotifications());
  }

  void _markAllNotificationsRead() {
    for (final item in _notifications) {
      _readNotificationKeys.add(item.key);
    }
    _notificationKeys.removeAll(_notifications.map((item) => item.key));
    _notifications.clear();
    unawaited(_saveReadNotifications());
  }

  String _newNotificationKey(WorkOrder order) => '${order.id}:new';

  String _issueNotificationKey(WorkOrder order) =>
      '${order.id}:issue:${order.issueReport!.trim()}';

  String _assignedNotificationKey(WorkOrder order) =>
      '${order.id}:assigned:${order.technicianLabel}';

  String _signoffNotificationKey(WorkOrder order) => '${order.id}:signoff';

  String _statusNotificationKey(WorkOrder order) =>
      '${order.id}:status:${order.status}';

  void _openCompletionDetails(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _workflowView = _WorkflowView.completionDetails;
      _completionOrder = order;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _tab = 0;
    });
  }

  void _saveCompletionDetails(WorkOrder updated) {
    unawaited(_repository.saveCompletionDetails(updated));
    _replaceOrder(updated);
    _closeWorkflow();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Completion details saved. They will sync automatically if offline.',
        ),
      ),
    );
  }

  Future<void> _approveFromReview(WorkOrder order) async {
    final returnToQueue = _returnToReviewQueue;
    await _approveOrder(order);
    if (!mounted) return;
    if (returnToQueue) {
      _navigateBack();
    } else {
      _closeWorkflow();
    }
  }

  void _openDeclineScreen(WorkOrder order) {
    _rememberNavigation();
    setState(() {
      _reviewingOrder = order;
      _workflowView = _WorkflowView.declineJob;
      _tab = 0;
    });
  }

  void _openReviewAfterDeclineCancel() {
    _navigateBack();
  }

  Future<void> _completeDecline(DeclineDecision decision) async {
    final order = _reviewingOrder;
    if (order == null) return;
    final status = decision.allowResubmission
        ? 'Declined'
        : 'Declined - Closed';
    final declined = order.copyWith(
      status: status,
      declineReason: decision.reason,
      declinedAt: DateTime.now(),
      closedAt: decision.allowResubmission ? null : DateTime.now(),
      reviewed: true,
      isOpen: decision.allowResubmission,
    );
    await _repository.declineWorkOrder(
      order,
      decision.reason,
      allowResubmission: decision.allowResubmission,
    );
    _replaceOrder(declined);
    if (!mounted) return;
    if (_returnToReviewQueue) {
      _navigateBack();
    } else {
      _closeWorkflow();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          decision.allowResubmission
              ? '${order.id} declined and returned.'
              : '${order.id} declined and closed.',
        ),
      ),
    );
  }
}

class _JobsLoadingView extends StatelessWidget {
  const _JobsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Loading your jobs...',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarBrandTitle extends StatelessWidget {
  const _AppBarBrandTitle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'PHEPHA MV '),
          TextSpan(
            text: 'ISDP',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      SyncStatus.online => (Icons.cloud_done_outlined, 'Synced', Colors.green),
      SyncStatus.syncing => (
        Icons.cloud_sync_outlined,
        'Syncing',
        Colors.orange,
      ),
      SyncStatus.offline => (Icons.cloud_off_outlined, 'Offline', Colors.red),
    };
    return Tooltip(
      message: status == SyncStatus.offline
          ? 'Offline changes are saved on this device and will sync automatically.'
          : label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Chip(
          avatar: Icon(icon, size: 17, color: color),
          label: Text(label),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 9 ? '9+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _NavigationSnapshot {
  const _NavigationSnapshot({
    required this.tab,
    required this.workflowView,
    required this.selectedOrderId,
    required this.assigningOrder,
    required this.scanningOrder,
    required this.uploadingOrder,
    required this.uploadingEvidenceSlot,
    required this.completionOrder,
    required this.reviewingOrder,
    required this.supervisorOrder,
    required this.adminOrder,
    required this.returnToReviewQueue,
  });

  final int tab;
  final _WorkflowView? workflowView;
  final String? selectedOrderId;
  final WorkOrder? assigningOrder;
  final WorkOrder? scanningOrder;
  final WorkOrder? uploadingOrder;
  final String? uploadingEvidenceSlot;
  final WorkOrder? completionOrder;
  final WorkOrder? reviewingOrder;
  final WorkOrder? supervisorOrder;
  final WorkOrder? adminOrder;
  final bool returnToReviewQueue;
}

enum _NotificationType { assignment, action, issue, progress, success, info }

class _AppNotification {
  _AppNotification({
    required this.key,
    required this.orderId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.read = false,
  });

  final String key;
  final String orderId;
  final String title;
  final String message;
  final DateTime createdAt;
  final _NotificationType type;
  bool read;
}

String _notificationTime(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.inMinutes < 1) return 'Now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final _AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, category) = switch (notification.type) {
      _NotificationType.assignment => (
        Icons.assignment_ind_outlined,
        Colors.blue,
        'Assignment',
      ),
      _NotificationType.action => (
        Icons.pending_actions_outlined,
        Colors.orange,
        'Action required',
      ),
      _NotificationType.issue => (
        Icons.report_problem_outlined,
        Colors.red,
        'Attention',
      ),
      _NotificationType.progress => (
        Icons.route_outlined,
        Colors.teal,
        'Progress',
      ),
      _NotificationType.success => (
        Icons.check_circle_outline,
        Colors.green,
        'Completed',
      ),
      _NotificationType.info => (Icons.info_outline, Colors.blueGrey, 'Update'),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: notification.read
            ? Colors.transparent
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.read
              ? Colors.grey.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.24),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(icon),
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
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    _notificationTime(notification.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_outlined, size: 52, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'You are up to date',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'There are no unread notifications.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
