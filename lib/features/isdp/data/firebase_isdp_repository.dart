import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  CollectionReference<Map<String, dynamic>> get _supportMessages =>
      _firestore.collection('support_messages');

  late final List<Query<Map<String, dynamic>>> _visibleWorkOrderQueries =
      _buildVisibleWorkOrderQueries();

  late final Stream<List<QuerySnapshot<Map<String, dynamic>>>>
  _visibleSnapshots = _combineQuerySnapshots(
    _visibleWorkOrderQueries,
  ).asBroadcastStream();

  String get _uid => _firebaseAuth.currentUser?.uid ?? 'system';
  String get _workOrderCacheKey => 'isdp_work_orders_${role.name}_$userId';

  List<Query<Map<String, dynamic>>> _buildVisibleWorkOrderQueries() {
    final approvalCutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 14)),
    );
    return switch (role) {
      AppRole.admin => [_workOrders.orderBy('createdAt', descending: true)],
      AppRole.supervisor => [
        _workOrders
            .where('supervisorId', isNull: true)
            .where('isOpen', isEqualTo: true),
        _workOrders
            .where('supervisorId', isEqualTo: userId)
            .where('isOpen', isEqualTo: true),
        _workOrders
            .where('supervisorId', isEqualTo: userId)
            .where('isOpen', isEqualTo: false)
            .where('approvedAt', isGreaterThanOrEqualTo: approvalCutoff),
        _workOrders
            .where('supervisorId', isEqualTo: userId)
            .where('isOpen', isEqualTo: false)
            .where('closedAt', isGreaterThanOrEqualTo: approvalCutoff),
      ],
      AppRole.technician => [
        _workOrders
            .where('assignedTechnicianIds', arrayContains: userId)
            .where('isOpen', isEqualTo: true),
        _workOrders
            .where('assignedTechnicianIds', arrayContains: userId)
            .where('isOpen', isEqualTo: false)
            .where('approvedAt', isGreaterThanOrEqualTo: approvalCutoff),
        _workOrders
            .where('assignedTechnicianIds', arrayContains: userId)
            .where('isOpen', isEqualTo: false)
            .where('closedAt', isGreaterThanOrEqualTo: approvalCutoff),
      ],
    };
  }

  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _combineQuerySnapshots(
    List<Query<Map<String, dynamic>>> queries,
  ) {
    late final StreamController<List<QuerySnapshot<Map<String, dynamic>>>>
    controller;
    final latest = <int, QuerySnapshot<Map<String, dynamic>>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    controller = StreamController<List<QuerySnapshot<Map<String, dynamic>>>>(
      onListen: () {
        for (var index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots(includeMetadataChanges: true).listen((
              snapshot,
            ) {
              latest[index] = snapshot;
              if (latest.length == queries.length) {
                controller.add([
                  for (var i = 0; i < queries.length; i++) latest[i]!,
                ]);
              }
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  List<WorkOrder> getWorkOrders() => const [];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() {
    late final StreamController<List<WorkOrder>> controller;
    StreamSubscription<List<QuerySnapshot<Map<String, dynamic>>>>? subscription;
    var hasLiveData = false;

    controller = StreamController<List<WorkOrder>>(
      onListen: () {
        subscription = _visibleSnapshots.listen((snapshots) {
          hasLiveData = true;
          final orders = _ordersFromSnapshots(snapshots);
          unawaited(_saveCachedWorkOrders(orders));
          controller.add(orders);
        }, onError: controller.addError);
        unawaited(
          _loadCachedWorkOrders().then((cached) {
            if (!hasLiveData && cached.isNotEmpty && !controller.isClosed) {
              controller.add(cached);
            }
          }),
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  List<WorkOrder> _ordersFromSnapshots(
    List<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final snapshot in snapshots)
        for (final document in snapshot.docs) document.id: document,
    };
    final orders = documents.values
        .map((doc) => WorkOrder.fromMap(doc.id, doc.data()))
        .toList();
    orders.sort((a, b) {
      final aDate = a.approvedAt ?? a.submittedAt ?? a.dueAt;
      final bDate = b.approvedAt ?? b.submittedAt ?? b.dueAt;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });
    return orders;
  }

  Future<List<WorkOrder>> _loadCachedWorkOrders() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_workOrderCacheKey);
      if (encoded == null || encoded.isEmpty) return const [];
      final values = jsonDecode(encoded) as List<dynamic>;
      return values.whereType<Map>().map((value) {
        final entry = Map<String, dynamic>.from(value);
        return WorkOrder.fromMap(
          entry['id'] as String,
          Map<String, dynamic>.from(entry['data'] as Map),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCachedWorkOrders(List<WorkOrder> orders) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final values = orders
          .take(100)
          .map((order) => {'id': order.id, 'data': order.toMap()})
          .toList(growable: false);
      await preferences.setString(_workOrderCacheKey, jsonEncode(values));
    } catch (_) {
      // Firestore remains the source of truth if local cache storage fails.
    }
  }

  @override
  Stream<SyncStatus> watchSyncStatus() {
    return _visibleSnapshots.map((snapshots) {
      if (snapshots.any(
        (snapshot) => snapshot.docs.any((doc) => doc.metadata.hasPendingWrites),
      )) {
        return SyncStatus.syncing;
      }
      return snapshots.any((snapshot) => snapshot.metadata.isFromCache)
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
    final isResubmission = order.declineReason?.trim().isNotEmpty == true;
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
      'declineReason': null,
      'declinedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        _historyEntry(isResubmission ? 'resubmitted' : 'submitted'),
      ]),
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
    return _updateStatus(
      order,
      'Approved',
      sla: 'Approved',
      recordApproval: true,
    );
  }

  @override
  Future<void> declineWorkOrder(
    WorkOrder order,
    String reason, {
    required bool allowResubmission,
  }) {
    return _workOrders.doc(order.id).update({
      'status': allowResubmission ? 'Declined' : 'Declined - Closed',
      'declineReason': reason.trim(),
      'declinedAt': FieldValue.serverTimestamp(),
      'closedAt': allowResubmission ? null : FieldValue.serverTimestamp(),
      'reviewed': true,
      'isOpen': allowResubmission,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry('declined by admin')]),
    });
  }

  @override
  Future<void> closeWorkOrder(WorkOrder order) {
    return _workOrders.doc(order.id).update({
      'status': 'Closed',
      'isOpen': false,
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        _historyEntry('closed by technician after decline'),
      ]),
    });
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
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_unread')
        .doc(workOrderId)
        .snapshots()
        .map((snapshot) => (snapshot.data()?['count'] as num?)?.toInt() ?? 0)
        .distinct();
  }

  @override
  Stream<int> watchUnreadJobMessageTotal(List<String> workOrderIds) {
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

  @override
  Stream<List<SupportMessage>> watchSupportMessages({int limit = 50}) {
    final query = _supportMessagesQuery().limit(limit);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Future<List<SupportMessage>> fetchSupportMessages({
    int limit = 50,
    SupportMessage? startAfterMessage,
  }) async {
    var query = _supportMessagesQuery().limit(limit);
    if (startAfterMessage != null) {
      query = query.startAfter([
        startAfterMessage.status,
        Timestamp.fromDate(startAfterMessage.createdAt),
      ]);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
        .toList();
  }

  Query<Map<String, dynamic>> _supportMessagesQuery() {
    return role == AppRole.admin
        ? _supportMessages
              .orderBy('status')
              .orderBy('createdAt', descending: true)
        : _supportMessages
              .where('senderId', isEqualTo: _uid)
              .orderBy('status')
              .orderBy('createdAt', descending: true);
  }

  @override
  Stream<int> watchSupportMessageCount() {
    if (role != AppRole.admin) return Stream.value(0);
    return _supportMessages
        .where('status', isEqualTo: 'new')
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .distinct();
  }

  @override
  Future<void> sendSupportMessage({
    required String message,
    required String senderName,
    required String senderRole,
    required String senderEmail,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    await _supportMessages.add({
      'senderId': _uid,
      'senderName': senderName.trim().isEmpty ? 'ISDP User' : senderName.trim(),
      'senderRole': senderRole,
      'senderEmail': senderEmail.trim(),
      'message': trimmed,
      'source': 'support',
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSupportMessagesRead() async {
    if (role != AppRole.admin) return;
    final snapshot = await _supportMessages
        .where('status', isEqualTo: 'new')
        .limit(50)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'read',
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> clearLocalCache() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_workOrderCacheKey);
  }

  Future<void> _updateStatus(
    WorkOrder order,
    String status, {
    String? sla,
    bool recordApproval = false,
  }) {
    final update = <String, Object?>{
      'status': status,
      'isOpen': status != 'Approved',
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([_historyEntry(status.toLowerCase())]),
    };
    if (sla != null) update['sla'] = sla;
    if (recordApproval) update['approvedAt'] = FieldValue.serverTimestamp();
    return _workOrders.doc(order.id).update(update);
  }

  Map<String, Object?> _historyEntry(String action) {
    return {'action': action, 'userId': _uid, 'at': Timestamp.now()};
  }
}
