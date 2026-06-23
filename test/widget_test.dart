import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdp/app/isdp_app.dart';
import 'package:isdp/core/domain/app_role.dart';
import 'package:isdp/features/auth/domain/auth_repository.dart';
import 'package:isdp/features/isdp/domain/entities.dart';
import 'package:isdp/features/isdp/domain/isdp_repository.dart';
import 'package:isdp/features/isdp/presentation/assign_technician_screen.dart';
import 'package:isdp/features/isdp/presentation/analytics_view.dart';
import 'package:isdp/features/isdp/presentation/isdp_shell.dart';
import 'package:isdp/features/isdp/presentation/completion_details_screen.dart';
import 'package:isdp/features/isdp/presentation/upload_evidence_screen.dart';

void main() {
  test('customer signature can be stored and restored', () {
    final encoded = encodeSignature([
      const [Offset(0.1, 0.2), Offset(0.8, 0.7)],
    ]);

    expect(decodeSignature(encoded), const [
      [Offset(0.1, 0.2), Offset(0.8, 0.7)],
    ]);
  });

  testWidgets('full-screen signature paints while drawing', (tester) async {
    await tester.pumpWidget(
      const IsdpApp(
        home: FullScreenSignatureScreen(
          initialStrokes: [],
          customerName: 'Customer',
        ),
      ),
    );

    expect(find.text('SIGN HERE'), findsOneWidget);
    expect(find.text('Use this signature'), findsOneWidget);

    final start = tester.getCenter(find.text('SIGN HERE'));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(160, 40));
    await tester.pump();

    expect(find.text('SIGN HERE'), findsNothing);
    final paintedCanvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is SignaturePainter,
    );
    final canvasSize = tester.getSize(paintedCanvas);
    expect(canvasSize.width, greaterThan(200));
    expect(canvasSize.height, greaterThan(200));
    final customPaint = tester.widget<CustomPaint>(paintedCanvas);
    final painter = customPaint.painter! as SignaturePainter;
    expect(painter.strokes.last.length, greaterThan(1));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Use this signature'),
    );
    expect(button.onPressed, isNotNull);
    await gesture.up();
  });

  testWidgets('technician sees on-site workflow', (tester) async {
    await tester.pumpWidget(
      IsdpApp(home: IsdpShell(isdpRepository: _TestIsdpRepository())),
    );

    expect(find.text('PHEPHA MV ISDP'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Next Steps'), findsOneWidget);
    expect(find.textContaining('Time left'), findsOneWidget);
    expect(find.text('Confirm arrival'), findsOneWidget);
    expect(find.text('Upload before photo'), findsOneWidget);
    expect(find.textContaining('Matsapha Office Block'), findsWidgets);
  });

  testWidgets('technician countdown runs before arrival scan', (tester) async {
    await tester.pumpWidget(
      IsdpApp(home: IsdpShell(isdpRepository: _UnscannedJobRepository())),
    );

    expect(find.textContaining('Due in'), findsWidgets);
    expect(find.textContaining('1 day'), findsOneWidget);
    expect(find.textContaining('5 hours'), findsOneWidget);
  });

  testWidgets('admin sees approval queue', (tester) async {
    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(
          initialRole: AppRole.admin,
          isdpRepository: _TestIsdpRepository(),
        ),
      ),
    );

    expect(find.text('Admin Control'), findsOneWidget);
    expect(find.text('Needs Approval'), findsOneWidget);
    expect(find.text('Admin Tools'), findsOneWidget);
  });

  testWidgets('admin zero-job today view keeps action buttons', (tester) async {
    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(
          initialRole: AppRole.admin,
          isdpRepository: _EmptyIsdpRepository(),
        ),
      ),
    );

    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('Create Job'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
  });

  testWidgets('admin can delete a job from job details', (tester) async {
    final repository = _DeletableIsdpRepository();

    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(initialRole: AppRole.admin, isdpRepository: repository),
      ),
    );

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Delete Site'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Job'), findsNothing);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete job'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['JOB-CMT-ESW-5001']);
    expect(find.textContaining('Delete Site'), findsNothing);
  });

  testWidgets('assignment searches by email but assigns technician names', (
    tester,
  ) async {
    List<String>? assigned;

    await tester.pumpWidget(
      IsdpApp(
        home: Scaffold(
          body: AssignTechnicianScreen(
            order: _assignableOrder(),
            technicians: const [
              AppUserProfile(
                uid: 'tech-1',
                email: 'sibusiso@example.com',
                name: 'Sibusiso M.',
                role: AppRole.technician,
              ),
              AppUserProfile(
                uid: 'tech-2',
                email: 'thabo@example.com',
                name: 'Thabo M.',
                role: AppRole.technician,
              ),
            ],
            onAssigned: (names) => assigned = names,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'thabo@example.com');
    await tester.pump();

    expect(find.text('Thabo M.'), findsOneWidget);

    await tester.tap(find.text('Thabo M.'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Assign Job'));

    expect(assigned, ['Thabo M.']);
  });

  testWidgets('assignment cannot add a technician outside the directory', (
    tester,
  ) async {
    List<String>? assigned;

    await tester.pumpWidget(
      IsdpApp(
        home: Scaffold(
          body: AssignTechnicianScreen(
            order: _assignableOrder(),
            technicians: const [
              AppUserProfile(
                uid: 'tech-1',
                email: 'sibusiso@example.com',
                name: 'Sibusiso M.',
                role: AppRole.technician,
              ),
            ],
            onAssigned: (names) => assigned = names,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'unknown@example.com');
    await tester.pump();

    expect(find.textContaining('Add Unknown'), findsNothing);
    expect(find.text('No technicians match this search.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Assign 0'));
    await tester.pump();

    expect(assigned, isNull);
    expect(find.text('Select an existing technician.'), findsOneWidget);
  });

  testWidgets('analytics person row opens job drilldown', (tester) async {
    await tester.pumpWidget(
      IsdpApp(
        home: Scaffold(
          body: AnalyticsView(
            role: AppRole.admin,
            workOrders: [
              _assignableOrder().copyWith(
                site: 'Analytics Job',
                assignedTechnicians: ['Thabo M.'],
                assignedTo: 'Thabo M.',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('People'), findsOneWidget);
    await tester.tap(find.text('Thabo M.'));
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Analytics Job'), findsOneWidget);
  });

  testWidgets('notifications dedupe repeated stream updates', (tester) async {
    final initial = _assignableOrder();
    final repository = _NotificationStreamRepository([initial]);

    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(initialRole: AppRole.admin, isdpRepository: repository),
      ),
    );

    final submitted = initial.copyWith(status: 'Submitted');
    repository.emit([submitted]);
    await tester.pump();
    await tester.pump();
    repository.emit([submitted]);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Job submitted'), findsOneWidget);
  });

  testWidgets('create job ignores duplicate taps while save is pending', (
    tester,
  ) async {
    final repository = _SlowCreateIsdpRepository();

    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(initialRole: AppRole.admin, isdpRepository: repository),
      ),
    );

    await tester.tap(find.byKey(const Key('empty-create-job-button')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Duplicate Test Site');
    await tester.enterText(fields.at(1), 'Duplicate Test Address');
    await tester.enterText(fields.at(2), 'Install duplicate prevention.');

    await tester.tap(find.widgetWithText(FilledButton, 'Create Job'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Creating...'));
    await tester.pump();

    expect(repository.createCalls, 1);

    repository.completeSave();
    await tester.pumpAndSettle();
  });

  testWidgets('upload evidence screen can show before photo only', (
    tester,
  ) async {
    await tester.pumpWidget(
      IsdpApp(
        home: UploadEvidenceScreen(
          order: _evidenceOrder(),
          targetSlot: 'before',
        ),
      ),
    );

    expect(find.text('Before photo'), findsOneWidget);
    expect(find.text('After photo'), findsNothing);
  });

  testWidgets('upload evidence screen can show after photo only', (
    tester,
  ) async {
    await tester.pumpWidget(
      IsdpApp(
        home: UploadEvidenceScreen(
          order: _evidenceOrder(),
          targetSlot: 'after',
        ),
      ),
    );

    expect(find.text('After photo'), findsOneWidget);
    expect(find.text('Before photo'), findsNothing);
  });

  testWidgets('submit enables after customer sign-off is saved', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      IsdpApp(home: IsdpShell(isdpRepository: _CompletableIsdpRepository())),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Work completed'),
      'Installed and tested successfully.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer name'),
      'Customer One',
    );
    await tester.tap(find.text('Capture signature'));
    await tester.pumpAndSettle();

    final signatureStart = tester.getCenter(find.text('SIGN HERE'));
    final gesture = await tester.startGesture(signatureStart);
    await gesture.moveBy(const Offset(120, 40));
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text('Use this signature'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save completion details'));
    await tester.pumpAndSettle();

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );
    expect(submitButton.onPressed, isNotNull);
  });

  testWidgets('supervisor sees team board', (tester) async {
    await tester.pumpWidget(
      IsdpApp(
        home: IsdpShell(
          initialRole: AppRole.supervisor,
          isdpRepository: _TestIsdpRepository(),
        ),
      ),
    );

    expect(find.text('Supervisor Desk'), findsOneWidget);
    expect(find.text('Team Queue'), findsOneWidget);
    expect(find.text('Accept Job'), findsOneWidget);
  });
}

class _TestIsdpRepository implements IsdpRepository {
  _TestIsdpRepository();

  final List<WorkOrder> _jobs = [
    WorkOrder(
      id: 'JOB-CMT-ESW-1048',
      site: 'Matsapha Office Block',
      address: 'King Mswati III Avenue, Matsapha',
      scope: 'Fix unstable Wi-Fi coverage in the reception area',
      sla: 'Due in 11 hours',
      siteCode: 'SITE-MAT-03',
      status: 'On Site',
      priority: Priority.critical,
      dueAt: _futureDueAt,
      arrivedAt: _arrivedAt,
      arrivalVerified: true,
      supervisor: 'Mandla Dlamini',
      assignedTo: 'Sibusiso M.',
    ),
    WorkOrder(
      id: 'JOB-CMT-ESW-1050',
      site: 'Manzini Warehouse',
      address: 'Ngwane Street, Manzini',
      scope: 'Repair access control keypad and submit service report',
      sla: 'Ready for approval',
      siteCode: 'SITE-MNZ-CR',
      status: 'Submitted',
      priority: Priority.low,
      dueAt: _futureDueAt,
      arrivedAt: _arrivedAt,
      supervisor: 'Mandla Dlamini',
      assignedTo: 'Thabo M.',
      evidenceUploaded: true,
      evidenceSlots: ['before', 'after'],
    ),
    WorkOrder(
      id: 'JOB-CMT-ESW-1052',
      site: 'Nhlangano Depot',
      address: 'Main Road, Nhlangano',
      scope: 'Install backup router and test failover',
      sla: 'Due in 18 hours',
      siteCode: 'SITE-NHL-08',
      status: 'Assigned to Supervisor',
      priority: Priority.high,
      dueAt: _futureDueAt,
      supervisor: 'Mandla Dlamini',
    ),
  ];

  @override
  List<WorkOrder> getWorkOrders() => _jobs;

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value(_jobs);

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream.value(SyncStatus.online);

  @override
  List<Metric> getDashboardMetrics() => const [];

  @override
  List<JobStep> getJobSteps() => const [];

  @override
  List<MaterialLine> getMaterials() => const [];

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async {
    _jobs.insert(0, order);
    return order;
  }

  @override
  Future<void> acceptWorkOrder(WorkOrder order) async {}

  @override
  Future<void> assignWorkOrder(WorkOrder order) async {}

  @override
  Future<void> markOnsite(WorkOrder order) async {}

  @override
  Future<void> saveEvidence(
    WorkOrder order,
    List<String> evidenceSlots, {
    Map<String, String> evidencePhotos = const {},
  }) async {}

  @override
  Future<void> saveCompletionDetails(WorkOrder order) async {}

  @override
  Future<void> submitCompletion(WorkOrder order) async {}

  @override
  Future<void> reviewWorkOrder(WorkOrder order) async {}

  @override
  Future<void> approveWorkOrder(WorkOrder order) async {}

  @override
  Future<void> deleteWorkOrder(WorkOrder order) async {}
}

final _futureDueAt = DateTime.now().add(const Duration(hours: 11));
final _arrivedAt = DateTime.now().subtract(const Duration(minutes: 10));

WorkOrder _evidenceOrder() {
  return WorkOrder(
    id: 'JOB-CMT-ESW-2001',
    site: 'Evidence Site',
    address: 'Test Address',
    scope: 'Capture evidence',
    sla: 'Due today',
    siteCode: 'SITE-EVD-01',
    status: 'On Site',
    priority: Priority.high,
    dueAt: _futureDueAt,
    arrivalVerified: true,
    assignedTo: 'Sibusiso M.',
  );
}

WorkOrder _assignableOrder() {
  return WorkOrder(
    id: 'JOB-CMT-ESW-2002',
    site: 'Assignment Site',
    address: 'Assignment Address',
    scope: 'Assign technicians',
    sla: 'Due today',
    siteCode: 'SITE-ASN-01',
    status: 'Accepted by Supervisor',
    priority: Priority.high,
    dueAt: _futureDueAt,
    supervisor: 'Mandla Dlamini',
  );
}

class _EmptyIsdpRepository implements IsdpRepository {
  @override
  List<WorkOrder> getWorkOrders() => const [];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value(const []);

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream.value(SyncStatus.online);

  @override
  List<Metric> getDashboardMetrics() => const [];

  @override
  List<JobStep> getJobSteps() => const [];

  @override
  List<MaterialLine> getMaterials() => const [];

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async => order;

  @override
  Future<void> acceptWorkOrder(WorkOrder order) async {}

  @override
  Future<void> assignWorkOrder(WorkOrder order) async {}

  @override
  Future<void> markOnsite(WorkOrder order) async {}

  @override
  Future<void> saveEvidence(
    WorkOrder order,
    List<String> evidenceSlots, {
    Map<String, String> evidencePhotos = const {},
  }) async {}

  @override
  Future<void> saveCompletionDetails(WorkOrder order) async {}

  @override
  Future<void> submitCompletion(WorkOrder order) async {}

  @override
  Future<void> reviewWorkOrder(WorkOrder order) async {}

  @override
  Future<void> approveWorkOrder(WorkOrder order) async {}

  @override
  Future<void> deleteWorkOrder(WorkOrder order) async {}
}

class _UnscannedJobRepository extends _EmptyIsdpRepository {
  final WorkOrder _job = WorkOrder(
    id: 'JOB-CMT-ESW-4001',
    site: 'Unscanned Site',
    address: 'Unscanned Address',
    scope: 'Arrive and complete work',
    sla: 'Due tomorrow',
    siteCode: 'SITE-UNS-01',
    status: 'Dispatched',
    priority: Priority.high,
    dueAt: DateTime.now().add(const Duration(days: 1, hours: 5, minutes: 30)),
    assignedTo: 'Sibusiso M.',
  );

  @override
  List<WorkOrder> getWorkOrders() => [_job];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value([_job]);
}

class _NotificationStreamRepository extends _EmptyIsdpRepository {
  _NotificationStreamRepository(this._orders);

  List<WorkOrder> _orders;
  final StreamController<List<WorkOrder>> _controller =
      StreamController<List<WorkOrder>>.broadcast();

  void emit(List<WorkOrder> orders) {
    _orders = orders;
    _controller.add(orders);
  }

  @override
  List<WorkOrder> getWorkOrders() => _orders;

  @override
  Stream<List<WorkOrder>> watchWorkOrders() async* {
    yield _orders;
    yield* _controller.stream;
  }
}

class _DeletableIsdpRepository extends _EmptyIsdpRepository {
  final deletedIds = <String>[];
  final List<WorkOrder> _orders = [
    WorkOrder(
      id: 'JOB-CMT-ESW-5001',
      site: 'Delete Site',
      address: 'Delete Address',
      scope: 'Remove this job',
      sla: 'Due today',
      siteCode: 'SITE-DEL-01',
      status: 'Assigned to Supervisor',
      priority: Priority.high,
      dueAt: _futureDueAt,
    ),
  ];

  @override
  List<WorkOrder> getWorkOrders() => _orders;

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value(_orders);

  @override
  Future<void> deleteWorkOrder(WorkOrder order) async {
    deletedIds.add(order.id);
    _orders.removeWhere((candidate) => candidate.id == order.id);
  }
}

class _SlowCreateIsdpRepository extends _EmptyIsdpRepository {
  final Completer<void> _saveCompleter = Completer<void>();
  int createCalls = 0;

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async {
    createCalls += 1;
    await _saveCompleter.future;
    return order;
  }

  void completeSave() {
    if (!_saveCompleter.isCompleted) _saveCompleter.complete();
  }
}

class _CompletableIsdpRepository implements IsdpRepository {
  final WorkOrder _job = WorkOrder(
    id: 'JOB-CMT-ESW-3001',
    site: 'Ready Site',
    address: 'Ready Address',
    scope: 'Complete the job',
    sla: 'Due today',
    siteCode: 'SITE-RDY-01',
    status: 'On Site',
    priority: Priority.high,
    dueAt: _futureDueAt,
    arrivedAt: _arrivedAt,
    arrivalVerified: true,
    evidenceUploaded: true,
    evidenceSlots: const ['before', 'after'],
    assignedTo: 'Sibusiso M.',
  );

  @override
  List<WorkOrder> getWorkOrders() => [_job];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value([_job]);

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream.value(SyncStatus.online);

  @override
  List<Metric> getDashboardMetrics() => const [];

  @override
  List<JobStep> getJobSteps() => const [];

  @override
  List<MaterialLine> getMaterials() => const [];

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async => order;

  @override
  Future<void> acceptWorkOrder(WorkOrder order) async {}

  @override
  Future<void> assignWorkOrder(WorkOrder order) async {}

  @override
  Future<void> markOnsite(WorkOrder order) async {}

  @override
  Future<void> saveEvidence(
    WorkOrder order,
    List<String> evidenceSlots, {
    Map<String, String> evidencePhotos = const {},
  }) async {}

  @override
  Future<void> saveCompletionDetails(WorkOrder order) async {}

  @override
  Future<void> submitCompletion(WorkOrder order) async {}

  @override
  Future<void> reviewWorkOrder(WorkOrder order) async {}

  @override
  Future<void> approveWorkOrder(WorkOrder order) async {}

  @override
  Future<void> deleteWorkOrder(WorkOrder order) async {}
}
