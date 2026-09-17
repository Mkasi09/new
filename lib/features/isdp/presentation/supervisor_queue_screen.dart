import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class SupervisorQueueScreen extends StatelessWidget {
  const SupervisorQueueScreen({
    super.key,
    required this.orders,
    required this.onOpenJob,
    required this.onClose,
  });

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onOpenJob;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final activeJobs = orders
        .where((order) => order.status != 'Approved')
        .toList();

    return AppScrollView(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SectionTitle('Team Queue')),
            StatusChip(
              label: '${activeJobs.length} jobs',
              color: AppTheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeJobs.isEmpty)
          const _EmptySupervisorQueue()
        else
          ...activeJobs.map(
            (order) => _SupervisorQueueCard(
              order: order,
              onTap: () => onOpenJob(order),
            ),
          ),
      ],
    );
  }
}

class _SupervisorQueueCard extends StatelessWidget {
  const _SupervisorQueueCard({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconPill(icon: Icons.work_outline, color: _statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.site,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order.scope,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: order.status,
                      color: workOrderStatusColor(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(icon: Icons.schedule_outlined, label: order.sla),
                    InfoChip(
                      icon: Icons.person_outline,
                      label: order.technicianLabel ?? 'No technician',
                    ),
                    InfoChip(icon: Icons.place_outlined, label: order.address),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    if (order.status == 'Submitted') return AppTheme.success;
    if (order.status == 'On Site') return AppTheme.primary;
    if (order.priority == Priority.critical) return AppTheme.danger;
    return AppTheme.warning;
  }
}

class _EmptySupervisorQueue extends StatelessWidget {
  const _EmptySupervisorQueue();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No active jobs are assigned to this supervisor.'),
      ),
    );
  }
}
