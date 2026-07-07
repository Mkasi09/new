import 'entities.dart';

enum SyncStatus { online, syncing, offline }

abstract class IsdpRepository {
  List<WorkOrder> getWorkOrders();

  Stream<List<WorkOrder>> watchWorkOrders();

  Stream<SyncStatus> watchSyncStatus();

  List<Metric> getDashboardMetrics();

  List<JobStep> getJobSteps();

  List<MaterialLine> getMaterials();

  Future<WorkOrder> createWorkOrder(WorkOrder order);

  Future<void> acceptWorkOrder(WorkOrder order);

  Future<void> assignWorkOrder(WorkOrder order);

  Future<void> markOnsite(WorkOrder order);

  Future<void> saveEvidence(
    WorkOrder order,
    List<String> evidenceSlots, {
    Map<String, String> evidencePhotos = const {},
  });

  Future<void> saveCompletionDetails(WorkOrder order);

  Future<void> submitCompletion(WorkOrder order);

  Future<void> reviewWorkOrder(WorkOrder order);

  Future<void> approveWorkOrder(WorkOrder order);

  Future<void> declineWorkOrder(
    WorkOrder order,
    String reason, {
    required bool allowResubmission,
  });

  Future<void> closeWorkOrder(WorkOrder order);

  Future<void> deleteWorkOrder(WorkOrder order);

  Stream<List<JobChatMessage>> watchJobMessages(String workOrderId);

  Future<void> sendJobMessage({
    required String workOrderId,
    required String message,
    required String senderName,
    required String senderRole,
  });

  Stream<int> watchUnreadJobMessageCount(String workOrderId);

  Stream<int> watchUnreadJobMessageTotal(List<String> workOrderIds);

  Future<void> markJobChatRead(String workOrderId);

  Stream<List<SupportMessage>> watchSupportMessages({int limit = 50});

  Future<List<SupportMessage>> fetchSupportMessages({
    int limit = 50,
    SupportMessage? startAfterMessage,
  });

  Stream<int> watchSupportMessageCount();

  Future<void> sendSupportMessage({
    required String message,
    required String senderName,
    required String senderRole,
    required String senderEmail,
  });

  Future<void> markSupportMessagesRead();

  Future<void> clearLocalCache();
}
