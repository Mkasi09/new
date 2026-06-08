import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/domain/app_role.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/demo_people.dart';
import '../data/mock_isdp_repository.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'account_view.dart';
import 'admin_job_screen.dart';
import 'analytics_view.dart';
import 'assign_technician_screen.dart';
import 'create_job_screen.dart';
import 'dashboard_view.dart';
import 'empty_jobs_view.dart';
import 'qr_arrival_scan_screen.dart';
import 'review_job_screen.dart';
import 'review_queue_screen.dart';
import 'supervisor_job_screen.dart';
import 'supervisor_queue_screen.dart';
import 'upload_evidence_screen.dart';
import 'work_orders_view.dart';

enum _WorkflowView {
  createJob,
  assignTechnician,
  scanQr,
  uploadEvidence,
  analytics,
  reviewQueue,
  reviewJob,
  supervisorQueue,
  supervisorJob,
}

class IsdpShell extends StatefulWidget {
  const IsdpShell({
    super.key,
    this.initialRole,
    this.authRepository,
    this.isdpRepository,
  });

  final AppRole? initialRole;
  final AuthRepository? authRepository;
  final IsdpRepository? isdpRepository;

  @override
  State<IsdpShell> createState() => _IsdpShellState();
}

class _IsdpShellState extends State<IsdpShell> {
  int _tab = 0;
  late AppRole _role = widget.initialRole ?? AppRole.technician;
  late final IsdpRepository _repository =
      widget.isdpRepository ?? const MockIsdpRepository();
  late List<WorkOrder> _workOrders = List.of(_repository.getWorkOrders());
  late DemoPerson _demoPerson = defaultDemoPersonForRole(_role);
  String? _selectedOrderId;
  _WorkflowView? _workflowView;
  WorkOrder? _assigningOrder;
  WorkOrder? _scanningOrder;
  WorkOrder? _uploadingOrder;
  WorkOrder? _reviewingOrder;
  WorkOrder? _supervisorOrder;
  WorkOrder? _adminOrder;
  bool _returnToReviewQueue = false;
  Completer<bool?>? _scanCompleter;
  Completer<List<String>?>? _uploadCompleter;

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
          title: Row(
            children: [
              Image.asset('assets/logo.png', height: 30),
              const SizedBox(width: 10),
              const Expanded(child: Text('Commit ISDP')),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sync',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All local changes are synced.'),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_done_outlined),
            ),
          ],
        ),
        body: StreamBuilder<List<WorkOrder>>(
          stream: _repository.watchWorkOrders(),
          initialData: _workOrders,
          builder: (context, snapshot) {
            final liveOrders = _mergeWorkOrders(snapshot.data ?? const []);
            final visibleOrders = _visibleOrdersForRole(liveOrders);
            final selectedOrder = _selectedOrder(visibleOrders);
            final workflowPage = _buildWorkflowPage(visibleOrders);
            final pages = [
              if (workflowPage != null)
                workflowPage
              else if (selectedOrder == null)
                EmptyJobsView(role: _role, onCreateJob: _openCreateJobScreen)
              else
                DashboardView(
                  role: _role,
                  selectedOrder: selectedOrder,
                  workOrders: visibleOrders,
                  jobSteps: _repository.getJobSteps(),
                  materials: _repository.getMaterials(),
                  onOpenOrder: _openOrder,
                  onCreateJob: _openCreateJobScreen,
                  onOpenAnalytics: _openAnalyticsScreen,
                  onOpenReviewQueue: _openReviewQueueScreen,
                  onOpenTeamQueue: _openSupervisorQueueScreen,
                  onOpenSupervisorJob: _openSupervisorJobScreen,
                  onAcceptOrder: _acceptOrder,
                  onOpenReviewOrder: _openReviewScreen,
                  onAssignOrder: _assignOrder,
                  onMessageOrder: _messageOrder,
                  onFollowUpOrder: _followUpOrder,
                  onScanArrival: _scanArrival,
                  onUploadEvidence: _uploadEvidence,
                  onSubmitCompletion: _submitCompletion,
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
                demoPerson: _demoPerson,
                availablePeople: demoPeopleForRole(_role),
                onRoleChanged: _changeRole,
                onDemoPersonChanged: _changeDemoPerson,
                authRepository: widget.authRepository,
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
    if (_workflowView == _WorkflowView.supervisorJob) {
      _openSupervisorQueueScreen();
      return;
    }
    if (_workflowView == _WorkflowView.reviewJob && _returnToReviewQueue) {
      _openReviewQueueScreen();
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
        content: const Text('Do you want to close Commit ISDP?'),
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
                  order.status != 'Approved' &&
                  order.supervisor == _demoPerson.name,
            )
            .toList(),
      AppRole.technician =>
        orders
            .where(
              (order) =>
                  order.assignedTo == _demoPerson.name &&
                  (order.status == 'Dispatched' ||
                      order.status == 'On Site' ||
                      order.status == 'Submitted' ||
                      order.status == 'Approved'),
            )
            .toList(),
    };
  }

  List<WorkOrder> _mergeWorkOrders(List<WorkOrder> repositoryOrders) {
    final ordersById = {
      for (final order in _workOrders) order.id: order,
      for (final order in repositoryOrders) order.id: order,
    };
    return ordersById.values.toList();
  }

  Widget? _buildWorkflowPage(List<WorkOrder> visibleOrders) {
    return switch (_workflowView) {
      _WorkflowView.analytics => AnalyticsView(
        role: _role,
        workOrders: visibleOrders,
        onClose: _closeWorkflow,
      ),
      _WorkflowView.reviewQueue => ReviewQueueScreen(
        orders: visibleOrders,
        onOpenReview: _openReviewScreenFromQueue,
        onClose: _closeWorkflow,
      ),
      _WorkflowView.supervisorQueue => SupervisorQueueScreen(
        orders: visibleOrders,
        onOpenJob: _openSupervisorJobScreen,
        onClose: _closeWorkflow,
      ),
      _WorkflowView.supervisorJob => _buildSupervisorJobPage(visibleOrders),
      _WorkflowView.createJob => CreateJobScreen(
        onCreated: _createJob,
        onCancel: _closeWorkflow,
      ),
      _WorkflowView.assignTechnician when _assigningOrder != null =>
        AssignTechnicianScreen(
          order: _assigningOrder!,
          onAssigned: _completeAssignment,
          onCancel: _closeWorkflow,
        ),
      _WorkflowView.scanQr when _scanningOrder != null => QrArrivalScanScreen(
        order: _scanningOrder!,
        onMatched: _completeScan,
        onCancel: _cancelScan,
      ),
      _WorkflowView.uploadEvidence when _uploadingOrder != null =>
        UploadEvidenceScreen(
          order: _uploadingOrder!,
          onCompleted: _completeUpload,
          onCancel: _cancelUpload,
        ),
      _WorkflowView.reviewJob => _buildReviewPage(visibleOrders),
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
      onMessage: () => _messageOrder(order),
      onFollowUp: () => _followUpOrder(order),
      onClose: _openSupervisorQueueScreen,
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
      onClose: _closeAdminJob,
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
      onClose: _returnToReviewQueue ? _openReviewQueueScreen : _closeWorkflow,
    );
  }

  void _changeRole(AppRole role) {
    setState(() {
      _role = role;
      _demoPerson = defaultDemoPersonForRole(role);
      _selectedOrderId = null;
      _workflowView = null;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _adminOrder = null;
      _returnToReviewQueue = false;
      _scanCompleter?.complete(null);
      _scanCompleter = null;
      _uploadCompleter?.complete(null);
      _uploadCompleter = null;
    });
  }

  void _changeDemoPerson(DemoPerson person) {
    setState(() {
      _demoPerson = person;
      _selectedOrderId = null;
      _workflowView = null;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _adminOrder = null;
      _returnToReviewQueue = false;
      _scanCompleter?.complete(null);
      _scanCompleter = null;
      _uploadCompleter?.complete(null);
      _uploadCompleter = null;
    });
  }

  void _closeWorkflow() {
    setState(() {
      _workflowView = null;
      _assigningOrder = null;
      _scanningOrder = null;
      _uploadingOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
    });
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
    setState(() {
      _selectedOrderId = order.id;
      _tab = 0;
    });
  }

  void _openAdminJob(WorkOrder order) {
    setState(() {
      _adminOrder = order;
      _selectedOrderId = order.id;
      _tab = 1;
      _clearWorkflowState();
    });
  }

  void _closeAdminJob() {
    setState(() => _adminOrder = null);
  }

  void _sendQr(WorkOrder order) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Commit ISDP Job QR',
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

    Printing.sharePdf(
      bytes: pdf.save(),
      filename: '${order.id}_qr.pdf',
    );
  }

  void _replaceOrder(WorkOrder updated) {
    setState(() {
      _workOrders = _workOrders
          .map((order) => order.id == updated.id ? updated : order)
          .toList();
      _selectedOrderId = updated.id;
    });
  }

  void _openCreateJobScreen() {
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

  void _openReviewQueueScreen() {
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

  void _openSupervisorQueueScreen() {
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
    final saved = await _repository.createWorkOrder(created);
    if (!mounted) return;
    setState(() {
      _workOrders = [saved, ..._workOrders];
      _selectedOrderId = saved.id;
      _workflowView = null;
      _tab = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${saved.id} created. QR value: ${saved.siteCode}'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: saved.siteCode));
          },
        ),
      ),
    );
  }

  Future<void> _acceptOrder(WorkOrder order) async {
    final accepted = order.copyWith(status: 'Accepted by Supervisor');
    await _repository.acceptWorkOrder(order);
    _replaceOrder(accepted);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id} accepted by supervisor.')),
    );
  }

  Future<void> _approveOrder(WorkOrder order) async {
    final approved = order.copyWith(status: 'Approved', sla: 'Approved');
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

  Future<void> _completeAssignment(String assignedTo) async {
    final order = _assigningOrder;
    if (order == null) return;
    final assigned = order.copyWith(
      status: 'Dispatched',
      assignedTo: assignedTo,
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
    setState(() {
      _scanCompleter = null;
      _workflowView = null;
      _scanningOrder = null;
    });
  }

  void _cancelScan() {
    final completer = _scanCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    setState(() {
      _scanCompleter = null;
      _workflowView = null;
      _scanningOrder = null;
    });
  }

  Future<List<String>?> _uploadEvidence(WorkOrder order) {
    _uploadCompleter?.complete(null);
    final completer = Completer<List<String>?>();
    setState(() {
      _uploadCompleter = completer;
      _workflowView = _WorkflowView.uploadEvidence;
      _uploadingOrder = order;
      _assigningOrder = null;
      _scanningOrder = null;
      _reviewingOrder = null;
      _supervisorOrder = null;
      _returnToReviewQueue = false;
      _tab = 0;
    });
    return completer.future;
  }

  void _completeUpload(List<String> evidenceSlots) async {
    final order = _uploadingOrder;
    if (order != null) {
      final uploaded = const ['before', 'after'].every(evidenceSlots.contains);
      final updated = order.copyWith(
        evidenceSlots: evidenceSlots,
        evidenceUploaded: uploaded,
      );
      try {
        await _repository.saveEvidence(order, evidenceSlots);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save uploaded evidence.')),
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
    setState(() {
      _uploadCompleter = null;
      _workflowView = null;
      _uploadingOrder = null;
    });
  }

  void _cancelUpload() {
    final completer = _uploadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    setState(() {
      _uploadCompleter = null;
      _workflowView = null;
      _uploadingOrder = null;
    });
  }

  void _messageOrder(WorkOrder order) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Message sent for ${order.id}.')));
  }

  void _followUpOrder(WorkOrder order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Follow-up logged for ${order.id}.')),
    );
  }

  Future<void> _submitCompletion(WorkOrder order) async {
    final complete = order.copyWith(
      status: 'Submitted',
      sla: 'Ready for approval',
      evidenceUploaded: true,
      reviewed: false,
    );
    await _repository.submitCompletion(order);
    _replaceOrder(complete);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id} submitted for Admin approval.')),
    );
  }

  Future<void> _approveFromReview(WorkOrder order) async {
    final returnToQueue = _returnToReviewQueue;
    await _approveOrder(order);
    if (!mounted) return;
    if (returnToQueue) {
      _openReviewQueueScreen();
    } else {
      _closeWorkflow();
    }
  }
}
