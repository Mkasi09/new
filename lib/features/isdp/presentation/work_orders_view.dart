import 'package:flutter/material.dart';

import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class WorkOrdersView extends StatefulWidget {
  const WorkOrdersView({
    super.key,
    required this.role,
    required this.workOrders,
    required this.onOpenOrder,
  });

  final AppRole role;
  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpenOrder;

  @override
  State<WorkOrdersView> createState() => _WorkOrdersViewState();
}

class _WorkOrdersViewState extends State<WorkOrdersView> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? widget.workOrders
        : widget.workOrders.where((order) => order.status == _filter).toList();

    return AppScrollView(
      children: [
        SectionTitle(_titleFor(widget.role)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'All',
                label: Text('All'),
                icon: Icon(Icons.all_inbox),
              ),
              ButtonSegment(
                value: 'Dispatched',
                label: Text('New'),
                icon: Icon(Icons.outbound),
              ),
              ButtonSegment(
                value: 'Onsite',
                label: Text('Onsite'),
                icon: Icon(Icons.location_on),
              ),
              ButtonSegment(
                value: 'Complete',
                label: Text('Done'),
                icon: Icon(Icons.done_all),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (values) =>
                setState(() => _filter = values.first),
          ),
        ),
        const SizedBox(height: 14),
        ...filtered.map(
          (order) => WorkOrderCard(
            order: order,
            onTap: () => widget.onOpenOrder(order),
          ),
        ),
      ],
    );
  }

  String _titleFor(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'Company Jobs';
      case AppRole.supervisor:
        return 'Team Jobs';
      case AppRole.technician:
        return 'My Jobs';
    }
  }
}
