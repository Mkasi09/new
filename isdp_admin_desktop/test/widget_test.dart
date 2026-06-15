import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isdp_admin_desktop/main.dart';

class FakeAdminRepository implements AdminRepository {
  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    return AuthSession(idToken: 'token', email: email, uid: 'admin');
  }

  @override
  Future<List<WorkOrder>> fetchWorkOrders(AuthSession session) async {
    return [
      WorkOrder(
        id: 'JOB-CMT-ESW-100',
        site: 'Mbabane Central',
        address: 'Main Street',
        scope: 'Router replacement',
        sla: 'Due in 6 hours',
        siteCode: 'SITE-100',
        status: 'Submitted',
        priority: Priority.high,
        dueAt: DateTime.now().add(const Duration(hours: 6)),
        arrivedAt: DateTime(2026, 6, 14, 8),
        submittedAt: DateTime(2026, 6, 14, 9, 35),
        supervisor: 'Mandla Dlamini',
        assignedTo: 'Sibusiso M.',
        arrivalVerified: true,
        evidenceUploaded: true,
        evidenceSlots: const ['before', 'after'],
        evidencePhotos: const {
          'before':
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
          'after':
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL7WQAAAABJRU5ErkJggg==',
        },
      ),
    ];
  }

  @override
  Future<void> createWorkOrder(AuthSession session, WorkOrder order) async {}

  @override
  Future<void> updateWorkOrder(
    AuthSession session,
    WorkOrder order, {
    required String action,
  }) async {}
}

void main() {
  test('QR payload contains only the site code', () {
    const order = WorkOrder(
      id: 'JOB-CMT-ESW-100',
      site: 'Mbabane Central',
      address: 'Main Street',
      scope: 'Router replacement',
      sla: 'Due in 6 hours',
      siteCode: 'SITE-100',
      status: 'Submitted',
      priority: Priority.high,
    );

    expect(order.qrPayload, 'SITE-100');
  });

  test('work order reads evidence photos from Firestore', () {
    final order = WorkOrder.fromFirestoreDocument({
      'name': 'projects/demo/databases/(default)/documents/work_orders/JOB-1',
      'fields': {
        'evidencePhotos': {
          'mapValue': {
            'fields': {
              'before': {'stringValue': 'before-photo'},
              'after': {'stringValue': 'after-photo'},
            },
          },
        },
        'technicianNotes': {'stringValue': 'Replaced router and tested Wi-Fi.'},
        'issueReport': {'stringValue': 'Customer needs a follow-up survey.'},
        'customerName': {'stringValue': 'Jane Customer'},
        'customerSignature': {'stringValue': '[[[0.1,0.2],[0.8,0.7]]]'},
      },
    });

    expect(order.evidencePhotos['before'], 'before-photo');
    expect(order.evidencePhotos['after'], 'after-photo');
    expect(order.technicianNotes, 'Replaced router and tested Wi-Fi.');
    expect(order.issueReport, 'Customer needs a follow-up survey.');
    expect(order.customerName, 'Jane Customer');
  });

  testWidgets('admin dashboard smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(IsdpAdminApp(repository: FakeAdminRepository()));

    await tester.enterText(find.byType(TextFormField).first, 'admin@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsNWidgets(2));
    expect(find.text('Operational Queue'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_outlined), findsWidgets);
  });

  testWidgets('dashboard cards and job rows provide easy navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(IsdpAdminApp(repository: FakeAdminRepository()));
    await tester.enterText(find.byType(TextFormField).first, 'admin@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open jobs'));
    await tester.pumpAndSettle();
    expect(find.text('1 job found'), findsOneWidget);

    await tester.tap(find.text('JOB-CMT-ESW-100 - Mbabane Central'));
    await tester.pumpAndSettle();
    expect(find.text('Back to jobs'), findsOneWidget);
    expect(find.text('Worked 1h 35m'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Job Actions'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Approve job'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Evidence Photos'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsNWidgets(2),
    );

    await tester.scrollUntilVisible(
      find.text('Back to jobs'),
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Back to jobs'));
    await tester.pumpAndSettle();
    expect(find.text('Search jobs'), findsOneWidget);
  });
}
