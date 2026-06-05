import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'isdp_mock_data.dart';

class MockIsdpRepository implements IsdpRepository {
  const MockIsdpRepository();

  @override
  List<WorkOrder> getWorkOrders() => workOrders;

  @override
  List<Metric> getDashboardMetrics() => dashboardMetrics;

  @override
  List<JobStep> getJobSteps() => jobSteps;

  @override
  List<MaterialLine> getMaterials() => materials;
}
