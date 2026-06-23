import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'isdp_mock_data.dart';

class FirebaseIsdpRepository implements IsdpRepository {
  FirebaseIsdpRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _workOrders =>
      _firestore.collection('work_orders');

  String get _uid => _firebaseAuth.currentUser?.uid ?? 'system';

  @override
  List<WorkOrder> getWorkOrders() => const [];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() {
    return _workOrders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkOrder.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<SyncStatus> watchSyncStatus() {
    return _workOrders.snapshots(includeMetadataChanges: true).map((snapshot) {
      if (snapshot.docs.any((doc) => doc.metadata.hasPendingWrites)) {
        return SyncStatus.syncing;
      }
      return snapshot.metadata.isFromCache
          ? SyncStatus.offline
          : SyncStatus.online;
    }).distinct();
  }

  @override
  List<Metric> getDashboardMetrics() => dashboardMetrics;

  @override
  List<JobStep> getJobSteps() => jobSteps;

  @override
  List<MaterialLine> getMaterials() => materials;

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async {
    final doc = _workOrders.doc(order.id);
    final created = order.copyWith(
      status: 'Assigned to Supervisor',
      createdBy: _uid,
    );
    await doc.set({
      ...created.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('created')]),
    });
    return created;
  }

  @override
  Future<void> acceptWorkOrder(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'status': 'Accepted by Supervisor',
      if (order.supervisor != null) 'supervisor': order.supervisor,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        _historyEntry('accepted by supervisor'),
      ]),
    });
  }

  @override
  Future<void> assignWorkOrder(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'status': 'Dispatched',
      'assignedTo': order.technicianLabel ?? order.assignedTo ?? _uid,
      'assignedTechnicians': order.assignedTechnicians,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('assigned')]),
    });
  }

  @override
  Future<void> markOnsite(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'status': 'On Site',
      'arrivalVerified': true,
      'arrivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('on site')]),
    });
  }

  @override
  Future<void> saveEvidence(
    WorkOrder order,
    List<String> evidenceSlots, {
    Map<String, String> evidencePhotos = const {},
  }) {
    final normalizedSlots = evidenceSlots.toSet().toList()..sort();
    final photos = {...order.evidencePhotos, ...evidencePhotos};
    return _workOrders.doc(order.id).update({
      'evidenceSlots': normalizedSlots,
      'evidencePhotos': photos,
      'evidenceUploaded': normalizedSlots.length >= 2,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('evidence uploaded')]),
    });
  }

  @override
  Future<void> saveCompletionDetails(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'technicianNotes': order.technicianNotes,
      'issueReport': order.issueReport,
      'customerName': order.customerName,
      'customerSignature': order.customerSignature,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        _historyEntry('completion details saved'),
      ]),
    });
  }

  @override
  Future<void> submitCompletion(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'status': 'Submitted',
      'sla': 'Ready for approval',
      'evidenceUploaded': true,
      'evidenceSlots': order.evidenceSlots,
      'evidencePhotos': order.evidencePhotos,
      'technicianNotes': order.technicianNotes,
      'issueReport': order.issueReport,
      'customerName': order.customerName,
      'customerSignature': order.customerSignature,
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewed': false,
      'reviewedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('submitted')]),
    });
  }

  @override
  Future<void> reviewWorkOrder(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'reviewed': true,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('reviewed')]),
    });
  }

  @override
  Future<void> approveWorkOrder(WorkOrder order) {
    return _updateStatus(order, 'Approved', sla: 'Approved');
  }

  @override
  Future<void> deleteWorkOrder(WorkOrder order) {
    return _workOrders.doc(order.id).delete();
  }

  Future<void> _updateStatus(WorkOrder order, String status, {String? sla}) {
    final update = <String, Object?>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry(status.toLowerCase())]),
    };
    if (sla != null) update['sla'] = sla;
    return _workOrders.doc(order.id).update(update);
  }

  Map<String, Object?> _historyEntry(String action) {
    return {'action': action, 'userId': _uid, 'at': Timestamp.now()};
  }
}
