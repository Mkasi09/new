import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'isdp_mock_data.dart';

class MockIsdpRepository implements IsdpRepository {
  const MockIsdpRepository();

  @override
  List<WorkOrder> getWorkOrders() => const [];

  @override
  Stream<List<WorkOrder>> watchWorkOrders() => Stream.value(getWorkOrders());

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream.value(SyncStatus.online);

  @override
  List<Metric> getDashboardMetrics() => dashboardMetrics;

  @override
  List<JobStep> getJobSteps() => jobSteps;

  @override
  List<MaterialLine> getMaterials() => materials;

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
  Future<void> declineWorkOrder(
    WorkOrder order,
    String reason, {
    required bool allowResubmission,
  }) async {}

  @override
  Future<void> closeWorkOrder(WorkOrder order) async {}

  @override
  Future<void> deleteWorkOrder(WorkOrder order) async {}

  @override
  Stream<List<JobChatMessage>> watchJobMessages(String workOrderId) =>
      Stream.value(const []);

  @override
  Future<void> sendJobMessage({
    required String workOrderId,
    required String message,
    required String senderName,
    required String senderRole,
  }) async {}

  @override
  Stream<int> watchUnreadJobMessageCount(String workOrderId) => Stream.value(0);

  @override
  Stream<int> watchUnreadJobMessageTotal(List<String> workOrderIds) =>
      Stream.value(0);

  @override
  Future<void> markJobChatRead(String workOrderId) async {}

  @override
  Stream<List<SupportMessage>> watchSupportMessages({int limit = 50}) =>
      Stream.value(const []);

  @override
  Future<List<SupportMessage>> fetchSupportMessages({
    int limit = 50,
    SupportMessage? startAfterMessage,
  }) async =>
      const [];

  @override
  Stream<int> watchSupportMessageCount() => Stream.value(0);

  @override
  Future<void> sendSupportMessage({
    required String message,
    required String senderName,
    required String senderRole,
    required String senderEmail,
  }) async {}

  @override
  Future<void> markSupportMessagesRead() async {}

  @override
  Future<void> clearLocalCache() async {}
}
