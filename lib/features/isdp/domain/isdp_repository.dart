import 'entities.dart';

abstract class IsdpRepository {
  List<WorkOrder> getWorkOrders();

  List<Metric> getDashboardMetrics();

  List<JobStep> getJobSteps();

  List<MaterialLine> getMaterials();
}
