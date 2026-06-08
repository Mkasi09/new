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
    List<String> evidenceSlots,
  ) async {}

  @override
  Future<void> submitCompletion(WorkOrder order) async {}

  @override
  Future<void> reviewWorkOrder(WorkOrder order) async {}

  @override
  Future<void> approveWorkOrder(WorkOrder order) async {}
}
