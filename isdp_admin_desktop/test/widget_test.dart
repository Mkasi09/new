import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:isdp_admin_desktop/main.dart';

class FakeAdminRepository implements AdminRepository {
  final deletedIds = <String>[];
  final savedInvoices = <Invoice>[];
  final users = <AdminUserProfile>[
    const AdminUserProfile(
      uid: 'admin-1',
      email: 'admin@commit.co.sz',
      name: 'Admin User',
      role: 'admin',
      team: 'Operations',
    ),
    const AdminUserProfile(
      uid: 'tech-1',
      email: 'sibusiso@commit.co.sz',
      name: 'Sibusiso M.',
      role: 'technician',
      team: 'Field Team A',
    ),
    const AdminUserProfile(
      uid: 'tech-2',
      email: 'thabo.tech@commit.co.sz',
      name: 'Thabo M.',
      role: 'technician',
      team: 'Field Team B',
    ),
    const AdminUserProfile(
      uid: 'supervisor-1',
      email: 'mandla@commit.co.sz',
      name: 'Mandla Dlamini',
      role: 'supervisor',
      team: 'North Region',
    ),
  ];
  WorkOrder? updatedOrder;
  String? updatedAction;
  AdminUserProfile? updatedTechnician;
  String? updatedTeam;
  AdminUserProfile? savedUser;
  AdminUserProfile? deletedUser;
  AdminNotice? savedNotice;

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
  Future<List<Invoice>> fetchInvoices(AuthSession session) async {
    return List.of(savedInvoices);
  }

  @override
  Future<void> saveInvoice(AuthSession session, Invoice invoice) async {
    final index = savedInvoices.indexWhere((item) => item.id == invoice.id);
    if (index == -1) {
      savedInvoices.add(invoice);
    } else {
      savedInvoices[index] = invoice;
    }
  }

  @override
  Future<AdminNotice?> fetchAdminNotice(AuthSession session) async {
    return savedNotice;
  }

  @override
  Future<void> saveAdminNotice(AuthSession session, AdminNotice notice) async {
    savedNotice = notice;
  }

  @override
  Future<List<AdminUserProfile>> fetchUsers(AuthSession session) async {
    return List.of(users);
  }

  @override
  Future<void> saveUserProfile(
    AuthSession session,
    AdminUserProfile profile,
  ) async {
    savedUser = profile;
    final index = users.indexWhere((user) => user.uid == profile.uid);
    if (index == -1) {
      users.add(profile);
    } else {
      users[index] = profile;
    }
  }

  @override
  Future<void> deleteUserProfile(
    AuthSession session,
    AdminUserProfile profile,
  ) async {
    deletedUser = profile;
    users.removeWhere((user) => user.uid == profile.uid);
  }

  @override
  Future<List<AdminUserProfile>> fetchTechnicians(AuthSession session) async {
    return users.where((user) => user.role == 'technician').toList();
  }

  @override
  Future<void> updateTechnicianTeam(
    AuthSession session,
    AdminUserProfile technician, {
    required String team,
  }) async {
    updatedTechnician = technician;
    updatedTeam = team;
    final index = users.indexWhere((user) => user.uid == technician.uid);
    if (index != -1) {
      users[index] = users[index].copyWith(team: team);
    }
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

  test('admin repository assigns technician to a team in Firestore', () async {
    Map<String, dynamic>? payload;
    Uri? requestedUri;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );

    await repository.updateTechnicianTeam(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
      const AdminUserProfile(
        uid: 'tech-1',
        email: 'sibusiso@commit.co.sz',
        name: 'Sibusiso M.',
        role: 'technician',
        team: 'Field Team A',
      ),
      team: 'Rapid Response',
    );

    final fields = payload!['fields'] as Map<String, dynamic>;
    expect(fields['team']['stringValue'], 'Rapid Response');
    expect(requestedUri!.path, contains('/documents/users/tech-1'));
    expect(requestedUri!.queryParametersAll['updateMask.fieldPaths'], ['team']);
  });

  test('admin repository fetches all user profiles', () async {
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        expect(request.url.path, contains('/documents/users'));
        return http.Response('''
{
  "documents": [
    {
      "name": "projects/demo/databases/(default)/documents/users/admin-1",
      "fields": {
        "email": {"stringValue": "admin@commit.co.sz"},
        "name": {"stringValue": "Admin User"},
        "role": {"stringValue": "admin"},
        "disabled": {"booleanValue": false}
      }
    },
    {
      "name": "projects/demo/databases/(default)/documents/users/tech-1",
      "fields": {
        "email": {"stringValue": "tech@commit.co.sz"},
        "name": {"stringValue": "Tech User"},
        "role": {"stringValue": "technician"},
        "phone": {"stringValue": "0791762956"}
      }
    }
  ]
}
''', 200);
      }),
    );

    final users = await repository.fetchUsers(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
    );

    expect(users.map((user) => user.uid), ['admin-1', 'tech-1']);
    expect(users.first.roleLabel, 'Admin');
    expect(users.last.phone, '0791762956');
  });

  test('admin repository saves a user profile in Firestore', () async {
    Map<String, dynamic>? payload;
    Uri? requestedUri;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );

    await repository.saveUserProfile(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
      AdminUserProfile(
        uid: 'user-1',
        email: 'user@commit.co.sz',
        name: 'User One',
        role: 'supervisor',
        team: 'North Region',
        phone: '0712345678',
        disabled: true,
        createdAt: DateTime(2026, 7, 18),
      ),
    );

    final fields = payload!['fields'] as Map<String, dynamic>;
    expect(fields['email']['stringValue'], 'user@commit.co.sz');
    expect(fields['role']['stringValue'], 'supervisor');
    expect(fields['disabled']['booleanValue'], isTrue);
    expect(requestedUri!.path, contains('/documents/users/user-1'));
    expect(
      requestedUri!.queryParametersAll['updateMask.fieldPaths'],
      containsAll(['email', 'name', 'role', 'team', 'phone', 'disabled']),
    );
  });

  test('admin repository reads and saves the admin notice', () async {
    final requestedMethods = <String>[];
    final requestedPaths = <String>[];
    Map<String, dynamic>? savedPayload;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedMethods.add(request.method);
        requestedPaths.add(request.url.path);
        if (request.method == 'GET') {
          return http.Response('''
{
  "name": "projects/demo/databases/(default)/documents/admin_config/notice",
  "fields": {
    "title": {"stringValue": "Maintenance"},
    "message": {"stringValue": "Use manual dispatch today."},
    "active": {"booleanValue": true},
    "updatedBy": {"stringValue": "admin@test.com"}
  }
}
''', 200);
        }
        savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }),
    );

    final session = const AuthSession(
      idToken: 'token',
      email: 'admin@test.com',
      uid: 'admin',
    );
    final notice = await repository.fetchAdminNotice(session);
    await repository.saveAdminNotice(
      session,
      const AdminNotice(
        title: 'Dispatch',
        message: 'Prioritize overdue jobs.',
        active: false,
        updatedBy: 'admin@test.com',
      ),
    );

    expect(notice?.title, 'Maintenance');
    expect(requestedMethods, ['GET', 'PATCH']);
    expect(
      requestedPaths.every((path) => path.contains('/admin_config/notice')),
      isTrue,
    );
    final fields = savedPayload!['fields'] as Map<String, dynamic>;
    expect(fields['title']['stringValue'], 'Dispatch');
    expect(fields['active']['booleanValue'], isFalse);
  });

  test('admin repository deletes a user profile document', () async {
    Uri? requestedUri;
    String? method;
    final repository = RestAdminRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        method = request.method;
        return http.Response('{}', 200);
      }),
    );

    await repository.deleteUserProfile(
      const AuthSession(
        idToken: 'token',
        email: 'admin@test.com',
        uid: 'admin',
      ),
      const AdminUserProfile(
        uid: 'user-delete',
        email: 'delete@commit.co.sz',
        name: 'Delete User',
        role: 'viewer',
      ),
    );

    expect(method, 'DELETE');
    expect(requestedUri!.path, contains('/documents/users/user-delete'));
  });

  test('admin CSV exports quote values safely', () {
    final csv = adminWorkOrdersCsv([
      WorkOrder(
        id: 'JOB-CSV',
        site: 'Mbabane, Central',
        address: 'Main "A" Street',
        scope: 'Router replacement',
        sla: 'Due today',
        siteCode: 'SITE-CSV',
        status: 'New',
        priority: Priority.high,
      ),
    ]);

    expect(csv, contains('"Mbabane, Central"'));
    expect(csv, contains('"Main ""A"" Street"'));
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

  testWidgets('admin completes the invoice lifecycle', (
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

    await tester.tap(find.text('Billing & Invoices'));
    await tester.pumpAndSettle();

    expect(find.text('Billing & Invoices'), findsNWidgets(2));
    expect(find.text('Invoice Process'), findsOneWidget);
    expect(find.text('Ready for Invoicing'), findsOneWidget);
    expect(find.text('Editable rates'), findsOneWidget);
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();

    expect(find.text('Invoice draft - JOB-CMT-ESW-101'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Customer email'),
      'accounts@example.com',
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(repository.savedInvoices, hasLength(1));
    expect(repository.savedInvoices.single.status, InvoiceStatus.draft);

    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Invoice actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue invoice'));
    await tester.pumpAndSettle();

    expect(repository.savedInvoices.single.status, InvoiceStatus.issued);

    await tester.tap(find.byTooltip('Invoice actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();

    expect(repository.savedInvoices.single.status, InvoiceStatus.paid);
    expect(repository.savedInvoices.single.paidAt, isNotNull);
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
    expect(find.text('Back to Work orders'), findsOneWidget);
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

    await tester.tap(find.text('Back to Work orders'));
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

    expect(find.text('Sibusiso M.'), findsWidgets);
    expect(find.text('Thabo M.'), findsWidgets);
    expect(find.text('Lindiwe S.'), findsNothing);

    await tester.tap(find.byTooltip('View profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Technician Profile'), findsOneWidget);
    expect(find.text('tech-1'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Assign to team').first);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(DropdownButtonFormField<String>, 'Team'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Team'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New team').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'New team name'),
      'Rapid Response',
    );
    await tester.tap(find.text('Save team'));
    await tester.pumpAndSettle();

    expect(repository.updatedTechnician?.uid, 'tech-1');
    expect(repository.updatedTeam, 'Rapid Response');
    expect(find.textContaining('Rapid Response'), findsWidgets);

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

  testWidgets('desktop admin manages user profiles', (
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

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();

    expect(find.text('User Directory'), findsOneWidget);
    expect(find.text('Admin User'), findsOneWidget);
    expect(find.text('Sibusiso M.'), findsOneWidget);

    await tester.tap(find.text('Add user'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'User ID'),
      'viewer-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'viewer@commit.co.sz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Viewer One',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create user'));
    await tester.pumpAndSettle();

    expect(repository.savedUser?.uid, 'viewer-1');
    expect(repository.savedUser?.role, 'technician');
    expect(find.text('Viewer One'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit user').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<AdminUserRole>, 'Role'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Supervisor'), findsWidgets);
    expect(find.text('Technician'), findsWidgets);
    expect(find.text('Billing'), findsNothing);
    expect(find.text('Viewer'), findsNothing);
    await tester.tap(find.text('Admin').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Admin Updated',
    );
    await tester.tap(find.widgetWithText(SwitchListTile, 'Disabled profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save user'));
    await tester.pumpAndSettle();

    expect(repository.savedUser?.uid, 'admin-1');
    expect(repository.savedUser?.name, 'Admin Updated');
    expect(repository.savedUser?.disabled, isTrue);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search users'),
      'viewer',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete user profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete profile'));
    await tester.pumpAndSettle();

    expect(repository.deletedUser?.uid, 'viewer-1');
    expect(find.text('Viewer One'), findsNothing);
  });

  testWidgets('desktop admin uses admin tools', (WidgetTester tester) async {
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

    await tester.tap(find.text('Admin Tools'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Exports'), findsOneWidget);
    expect(find.text('Work orders CSV'), findsOneWidget);
    expect(find.text('Admin Notice'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Notice title'),
      'Maintenance',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Notice message'),
      'Use manual dispatch today.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save notice'));
    await tester.pumpAndSettle();

    expect(repository.savedNotice?.title, 'Maintenance');
    expect(repository.savedNotice?.message, 'Use manual dispatch today.');
    expect(repository.savedNotice?.updatedBy, 'admin@test.com');
  });
}
