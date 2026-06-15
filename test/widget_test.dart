import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdp/app/isdp_app.dart';
import 'package:isdp/core/domain/app_role.dart';
import 'package:isdp/features/isdp/domain/entities.dart';
import 'package:isdp/features/isdp/domain/isdp_repository.dart';
import 'package:isdp/features/isdp/presentation/isdp_shell.dart';
import 'package:isdp/features/isdp/presentation/completion_details_screen.dart';

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
}

final _futureDueAt = DateTime.now().add(const Duration(hours: 11));
final _arrivedAt = DateTime.now().subtract(const Duration(minutes: 10));
