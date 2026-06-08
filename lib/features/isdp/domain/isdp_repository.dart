import 'entities.dart';

abstract class IsdpRepository {
  List<WorkOrder> getWorkOrders();

  Stream<List<WorkOrder>> watchWorkOrders();

  List<Metric> getDashboardMetrics();

  List<JobStep> getJobSteps();

  List<MaterialLine> getMaterials();

  Future<WorkOrder> createWorkOrder(WorkOrder order);

  Future<void> acceptWorkOrder(WorkOrder order);

  Future<void> assignWorkOrder(WorkOrder order);

  Future<void> markOnsite(WorkOrder order);

  Future<void> saveEvidence(WorkOrder order, List<String> evidenceSlots);

  Future<void> submitCompletion(WorkOrder order);

  Future<void> reviewWorkOrder(WorkOrder order);

  Future<void> approveWorkOrder(WorkOrder order);
}
