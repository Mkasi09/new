import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'isdp_mock_data.dart';

class FirebaseIsdpRepository implements IsdpRepository {
  FirebaseIsdpRepository({
    required this.role,
    required this.userId,
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final AppRole role;
  final String userId;

  CollectionReference<Map<String, dynamic>> get _workOrders =>
      _firestore.collection('work_orders');

  late final Query<Map<String, dynamic>> _visibleWorkOrders = switch (role) {
    AppRole.admin =>
      _workOrders
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 45)),
            ),
          )
          .orderBy('createdAt', descending: true),
    AppRole.technician =>
      _workOrders
          .where('assignedTechnicianIds', arrayContains: userId)
          .where('isOpen', isEqualTo: true)
          .orderBy('createdAt', descending: true),
    AppRole.supervisor =>
      _workOrders
          .where('isOpen', isEqualTo: true)
          .orderBy('createdAt', descending: true),
  };

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _visibleSnapshots =
      _visibleWorkOrders
          .snapshots(includeMetadataChanges: true)
          .asBroadcastStream();

  String get _uid => _firebaseAuth.currentUser?.uid ?? 'system';

  @override
  List<WorkOrder> getWorkOrders() => const [];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() {
    return _visibleSnapshots.map(
      (snapshot) => snapshot.docs
          .map((doc) => WorkOrder.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Stream<SyncStatus> watchSyncStatus() {
    return _visibleSnapshots.map((snapshot) {
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
      isOpen: true,
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
      'supervisorId': _uid,
      'isOpen': true,
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
      'assignedTechnicianIds': order.assignedTechnicianIds,
      'isOpen': true,
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

  @override
  Stream<List<JobChatMessage>> watchJobMessages(String workOrderId) {
    return _workOrders
        .doc(workOrderId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => JobChatMessage.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> sendJobMessage({
    required String workOrderId,
    required String message,
    required String senderName,
    required String senderRole,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final doc = _workOrders.doc(workOrderId).collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    await doc.set({
      'workOrderId': workOrderId,
      'senderId': _uid,
      'senderName': senderName.trim().isEmpty ? 'ISDP User' : senderName.trim(),
      'senderRole': senderRole,
      'message': trimmed,
      'createdAt': now,
    });
    await _workOrders.doc(workOrderId).update({
      'lastMessage': trimmed,
      'lastMessageAt': now,
      'lastMessageBy': senderName.trim().isEmpty
          ? 'ISDP User'
          : senderName.trim(),
      'chatMessageCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<int> watchUnreadJobMessageCount(String workOrderId) {
<<<<<<< HEAD
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_unread')
=======
    final uid = _uid;
    final controller = StreamController<int>();
    List<JobChatMessage> messages = const [];
    DateTime? readAt;
    var hasMessages = false;
    var hasReadState = false;
    int? lastCount;

    void emit() {
      if (controller.isClosed) return;
      if (!hasMessages || !hasReadState) return;
      final count = messages
          .where(
            (message) =>
                message.senderId != uid &&
                (readAt == null || message.createdAt.isAfter(readAt!)),
          )
          .length;
      if (count == lastCount) return;
      lastCount = count;
      controller.add(count);
    }

    final messageSub = watchJobMessages(workOrderId).listen((value) {
      messages = value;
      hasMessages = true;
      emit();
    }, onError: controller.addError);
    final readSub = _workOrders
>>>>>>> fe0d8aa8942866d04708b81b87a8ba88df48210d
        .doc(workOrderId)
        .snapshots()
<<<<<<< HEAD
        .map((snapshot) => (snapshot.data()?['count'] as num?)?.toInt() ?? 0)
        .distinct();
=======
        .listen((snapshot) {
          readAt = _dateTimeFromValue(snapshot.data()?['readAt']);
          hasReadState = true;
          emit();
        }, onError: controller.addError);

    controller.onCancel = () async {
      await messageSub.cancel();
      await readSub.cancel();
    };
    return controller.stream;
>>>>>>> fe0d8aa8942866d04708b81b87a8ba88df48210d
  }

  @override
  Stream<int> watchUnreadJobMessageTotal(List<String> workOrderIds) {
<<<<<<< HEAD
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_unread')
        .where('count', isGreaterThan: 0)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.fold<int>(
            0,
            (total, doc) =>
                total + ((doc.data()['count'] as num?)?.toInt() ?? 0),
          ),
        )
        .distinct();
=======
    final ids = workOrderIds.toSet().toList();
    if (ids.isEmpty) return Stream.value(0);
    final controller = StreamController<int>();
    final counts = <String, int>{for (final id in ids) id: 0};
    final readyIds = <String>{};
    final subscriptions = <StreamSubscription<int>>[];
    int? lastTotal;

    void emit() {
      if (controller.isClosed || readyIds.length != ids.length) return;
      final total = counts.values.fold<int>(
        0,
        (currentTotal, value) => currentTotal + value,
      );
      if (total == lastTotal) return;
      lastTotal = total;
      controller.add(total);
    }

    for (final id in ids) {
      subscriptions.add(
        watchUnreadJobMessageCount(id).listen((value) {
          counts[id] = value;
          readyIds.add(id);
          emit();
        }, onError: controller.addError),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    return controller.stream;
>>>>>>> fe0d8aa8942866d04708b81b87a8ba88df48210d
  }

  @override
  Future<void> markJobChatRead(String workOrderId) async {
    final batch = _firestore.batch();
    batch.set(
      _workOrders.doc(workOrderId).collection('chat_reads').doc(_uid),
      {'userId': _uid, 'readAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    batch.set(
      _firestore
          .collection('users')
          .doc(_uid)
          .collection('chat_unread')
          .doc(workOrderId),
      {'count': 0, 'readAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _updateStatus(WorkOrder order, String status, {String? sla}) {
    final update = <String, Object?>{
      'status': status,
      'isOpen': status != 'Approved',
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
