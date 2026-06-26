import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:isdp_admin_desktop/main.dart';

class FakeAdminRepository implements AdminRepository {
  final deletedIds = <String>[];
  WorkOrder? updatedOrder;
  String? updatedAction;

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
      WorkOrder(
        id: 'JOB-CMT-ESW-101',
        site: 'Ezulwini Approved',
        address: 'Valley Road',
        scope: 'Completed router install',
        sla: 'Approved',
        siteCode: 'SITE-101',
        status: 'Approved',
        priority: Priority.low,
        dueAt: DateTime.now().add(const Duration(hours: 4)),
        supervisor: 'Mandla Dlamini',
        assignedTo: 'Thabo M.',
        arrivalVerified: true,
        evidenceUploaded: true,
      ),
      WorkOrder(
        id: 'JOB-CMT-ESW-102',
        site: 'Manzini Dispatch',
        address: 'Industrial Road',
        scope: 'New ONT install',
        sla: 'Due in 24 hours',
        siteCode: 'SITE-102',
        status: 'Accepted by Supervisor',
        priority: Priority.high,
        dueAt: DateTime.now().add(const Duration(hours: 24)),
        supervisor: 'Mandla Dlamini',
      ),
    ];
  }

  @override
  Future<List<AdminUserProfile>> fetchTechnicians(AuthSession session) async {
    return const [
      AdminUserProfile(
        uid: 'tech-1',
        email: 'sibusiso@commit.co.sz',
        name: 'Sibusiso M.',
        role: 'technician',
        team: 'Field Team A',
      ),
      AdminUserProfile(
        uid: 'tech-2',
        email: 'thabo.tech@commit.co.sz',
        name: 'Thabo M.',
        role: 'technician',
        team: 'Field Team B',
      ),
      AdminUserProfile(
        uid: 'supervisor-1',
        email: 'mandla@commit.co.sz',
        name: 'Mandla Dlamini',
        role: 'supervisor',
        team: 'North Region',
      ),
    ].where((user) => user.role == 'technician').toList();
  }

  @override
  Future<void> createWorkOrder(AuthSession session, WorkOrder order) async {}

  @override
  Future<void> updateWorkOrder(
    AuthSession session,
    WorkOrder order, {
    required String action,
  }) async {
    updatedOrder = order;
    updatedAction = action;
  }

  @override
  Future<void> deleteWorkOrder(AuthSession session, WorkOrder order) async {
    deletedIds.add(order.id);
  }

  @override
  Future<int> fetchUnreadJobMessageCount(
    AuthSession session,
    String workOrderId,
  ) async {
    return 0;
  }

  @override
  Future<void> markJobChatRead(AuthSession session, String workOrderId) async {}

  @override
  Future<List<JobChatMessage>> fetchJobMessages(
    AuthSession session,
    String workOrderId,
  ) async {
    return const [];
  }

  @override
  Future<void> sendJobMessage(
    AuthSession session, {
    required String workOrderId,
    required String message,
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

  test('work order reads assigned technicians from Firestore', () {
    final order = WorkOrder.fromFirestoreDocument({
      'name': 'projects/demo/databases/(default)/documents/work_orders/JOB-1',
      'fields': {
        'assignedTo': {'stringValue': 'fallback@example.com'},
        'assignedTechnicians': {
          'arrayValue': {
            'values': [
              {'stringValue': 'sibusiso@commit.co.sz'},
              {'stringValue': 'Thabo M.'},
            ],
          },
        },
      },
    });

    expect(order.technicianNames, ['Sibusiso', 'Thabo M.']);
    expect(order.technicianLabel, 'Sibusiso, Thabo M.');
  });

  test(
    'admin repository fetches every work order page without createdAt filter',
    () async {
      final requestedUris = <Uri>[];
      final repository = RestAdminRepository(
        client: MockClient((request) async {
          requestedUris.add(request.url);
          expect(request.url.queryParameters.containsKey('orderBy'), isFalse);
          expect(request.url.queryParameters['pageSize'], '100');

          if (request.url.queryParameters['pageToken'] == 'second') {
            return http.Response('''
{
  "documents": [
    {
      "name": "projects/demo/databases/(default)/documents/work_orders/JOB-2",
      "fields": {
        "site": {"stringValue": "Second page site"},
        "status": {"stringValue": "New"}
      }
    }
  ]
}
''', 200);
          }

          return http.Response('''
{
  "documents": [
    {
      "name": "projects/demo/databases/(default)/documents/work_orders/JOB-1",
      "fields": {
        "site": {"stringValue": "First page site"},
        "status": {"stringValue": "New"}
      }
    }
  ],
  "nextPageToken": "second"
}
''', 200);
        }),
      );

      final orders = await repository.fetchWorkOrders(
        const AuthSession(
          idToken: 'token',
          email: 'admin@test.com',
          uid: 'admin',
        ),
      );

      expect(orders.map((order) => order.id), ['JOB-1', 'JOB-2']);
      expect(requestedUris, hasLength(2));
      expect(requestedUris.last.queryParameters['pageToken'], 'second');
    },
  );

  test('admin repository deletes a work order document', () async {
    Uri? requestedUri;
    String? method;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        method = request.method;
        return http.Response('{}', 200);
      }),
    );

    await repository.deleteWorkOrder(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
      const WorkOrder(
        id: 'JOB-DELETE',
        site: 'Delete',
        address: 'Address',
        scope: 'Scope',
        sla: 'Due today',
        siteCode: 'SITE-DELETE',
        status: 'New',
        priority: Priority.high,
      ),
    );

    expect(method, 'DELETE');
    expect(requestedUri!.path, contains('/work_orders/JOB-DELETE'));
  });

  test('admin repository fetches technician users only', () async {
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        expect(request.url.path, contains('/documents/users'));
        return http.Response('''
{
  "documents": [
    {
      "name": "projects/demo/databases/(default)/documents/users/tech-1",
      "fields": {
        "email": {"stringValue": "sibusiso@commit.co.sz"},
        "name": {"stringValue": "Sibusiso M."},
        "role": {"stringValue": "technician"},
        "team": {"stringValue": "Field Team A"}
      }
    },
    {
      "name": "projects/demo/databases/(default)/documents/users/admin-1",
      "fields": {
        "email": {"stringValue": "admin@commit.co.sz"},
        "name": {"stringValue": "Admin User"},
        "role": {"stringValue": "admin"}
      }
    }
  ]
}
''', 200);
      }),
    );

    final technicians = await repository.fetchTechnicians(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
    );

    expect(technicians.map((user) => user.name), ['Sibusiso M.']);
  });

  test('admin repository writes assigned technicians to Firestore', () async {
    Map<String, dynamic>? payload;
    Uri? requestedUri;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );

    await repository.updateWorkOrder(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
      const WorkOrder(
        id: 'JOB-ASSIGN',
        site: 'Assign',
        address: 'Address',
        scope: 'Scope',
        sla: 'Due today',
        siteCode: 'SITE-ASSIGN',
        status: 'Dispatched',
        priority: Priority.high,
        assignedTo: 'Sibusiso M., Thabo M.',
        assignedTechnicians: ['Sibusiso M.', 'Thabo M.'],
      ),
      action: 'assigned',
    );

    final fields = payload!['fields'] as Map<String, dynamic>;
    final values =
        fields['assignedTechnicians']['arrayValue']['values'] as List<dynamic>;
    expect(values.map((value) => value['stringValue']), [
      'Sibusiso M.',
      'Thabo M.',
    ]);
    expect(
      requestedUri!.queryParametersAll['updateMask.fieldPaths'],
      contains('assignedTechnicians'),
    );
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
    expect(find.text('Materials'), findsNothing);
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
    expect(find.text('2 jobs found'), findsOneWidget);

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due soon'));
    await tester.pumpAndSettle();
    expect(find.text('1 job found'), findsOneWidget);
    expect(find.text('JOB-CMT-ESW-100 - Mbabane Central'), findsOneWidget);
    expect(find.text('JOB-CMT-ESW-101 - Ezulwini Approved'), findsNothing);

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

  testWidgets('desktop admin can delete a job from details', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeAdminRepository();

    await tester.pumpWidget(IsdpAdminApp(repository: repository));
    await tester.enterText(find.byType(TextFormField).first, 'admin@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open jobs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JOB-CMT-ESW-100 - Mbabane Central'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, ['JOB-CMT-ESW-100']);
  });

  testWidgets('desktop admin assigns technicians from the user directory', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeAdminRepository();

    await tester.pumpWidget(IsdpAdminApp(repository: repository));
    await tester.enterText(find.byType(TextFormField).first, 'admin@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Field teams'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Assign').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search technicians'),
      'thabo.tech',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Thabo M.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sibusiso M.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Assign 2'));
    await tester.pumpAndSettle();

    expect(repository.updatedOrder?.id, 'JOB-CMT-ESW-102');
    expect(repository.updatedOrder?.assignedTechnicians, [
      'Sibusiso M.',
      'Thabo M.',
    ]);
    expect(repository.updatedOrder?.assignedTo, 'Sibusiso M., Thabo M.');
    expect(repository.updatedAction, 'assigned to Sibusiso M., Thabo M.');
  });
}
