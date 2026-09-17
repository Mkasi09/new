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
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.workOrders.where(_matchesFilters).toList();

    return AppScrollView(
      children: [
        SectionTitle(_titleFor(widget.role)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final searchField = TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search jobs',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                );
                final statusFilter = DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _filter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All active', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Assigned to Supervisor',
                      child: Text('Routed', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Accepted by Supervisor',
                      child: Text('Accepted', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Dispatched',
                      child: Text('Dispatched', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'On Site',
                      child: Text('On Site', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Submitted',
                      child: Text('Submitted', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Declined',
                      child: Text('Declined', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Approved',
                      child: Text(
                        'Approved (last 14 days)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Closed',
                      child: Text('Closed', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _filter = value);
                  },
                );

                if (compact) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      statusFilter,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: statusFilter),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No jobs match the current filters.'),
            ),
          )
        else
          ...filtered.map(
            (order) => WorkOrderCard(
              order: order,
              onTap: () => widget.onOpenOrder(order),
            ),
          ),
      ],
    );
  }

  bool _matchesFilters(WorkOrder order) {
    final matchesStatus = _filter == 'All'
        ? order.status != 'Approved' &&
              order.status != 'Closed' &&
              order.status != 'Declined - Closed'
        : _filter == 'Closed'
        ? order.status == 'Closed' || order.status == 'Declined - Closed'
        : order.status == _filter;
    if (!matchesStatus) return false;

    final query = _query.toLowerCase();
    if (query.isEmpty) return true;

    return [
      order.id,
      order.site,
      order.address,
      order.scope,
      order.status,
      order.sla,
      order.supervisor ?? '',
      order.technicianLabel ?? '',
    ].any((value) => value.toLowerCase().contains(query));
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
