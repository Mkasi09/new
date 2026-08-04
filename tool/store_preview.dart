import 'package:flutter/material.dart';
import 'package:isdp/app/isdp_app.dart';
import 'package:isdp/core/domain/app_role.dart';
import 'package:isdp/features/auth/domain/auth_repository.dart';
import 'package:isdp/features/isdp/data/mock_isdp_repository.dart';
import 'package:isdp/features/isdp/domain/entities.dart';
import 'package:isdp/features/isdp/presentation/isdp_shell.dart';

void main() {
  runApp(
    IsdpApp(
      home: IsdpShell(
        initialRole: AppRole.admin,
        userProfile: const AppUserProfile(
          uid: 'store-preview-admin',
          email: 'admin@example.com',
          role: AppRole.admin,
          name: 'Operations Admin',
          team: 'Operations',
        ),
        isdpRepository: const _StorePreviewRepository(),
      ),
    ),
  );
}

class _StorePreviewRepository extends MockIsdpRepository {
  const _StorePreviewRepository();

  static final List<WorkOrder> _orders = [
    WorkOrder(
      id: 'JOB-JHB-2048',
      site: 'Johannesburg Central Exchange',
      address: 'Commissioner Street, Johannesburg',
      scope: 'Replace the network router and verify service connectivity.',
      sla: 'Due in 4 hours',
      siteCode: 'JHB-CEN-04',
      status: 'Submitted',
      priority: Priority.critical,
      dueAt: DateTime.now().add(const Duration(hours: 4)),
      submittedAt: DateTime.now().subtract(const Duration(minutes: 35)),
      supervisor: 'Mandla Dlamini',
      assignedTo: 'Sibusiso Mokoena',
      assignedTechnicians: const ['Sibusiso Mokoena'],
      evidenceUploaded: true,
      evidenceSlots: const ['before', 'after'],
      customerName: 'Thandi Nkosi',
    ),
    WorkOrder(
      id: 'JOB-PTA-2051',
      site: 'Pretoria North Hub',
      address: 'Rachel de Beer Street, Pretoria',
      scope: 'Inspect the cabinet and restore the fibre uplink.',
      sla: 'Due in 8 hours',
      siteCode: 'PTA-NTH-11',
      status: 'On Site',
      priority: Priority.high,
      dueAt: DateTime.now().add(const Duration(hours: 8)),
      supervisor: 'Lerato Maseko',
      assignedTo: 'Ayanda Khumalo',
      assignedTechnicians: const ['Ayanda Khumalo'],
      arrivalVerified: true,
    ),
    WorkOrder(
      id: 'JOB-DBN-2046',
      site: 'Durban Harbour Site',
      address: 'Bayhead Road, Durban',
      scope: 'Install the replacement radio and complete acceptance tests.',
      sla: 'Due tomorrow',
      siteCode: 'DBN-HBR-07',
      status: 'Dispatched',
      priority: Priority.low,
      dueAt: DateTime.now().add(const Duration(days: 1)),
      supervisor: 'Mandla Dlamini',
      assignedTo: 'Karabo Molefe',
      assignedTechnicians: const ['Karabo Molefe'],
    ),
  ];

  @override
  List<WorkOrder> getWorkOrders() => _orders;

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value(_orders);
}
