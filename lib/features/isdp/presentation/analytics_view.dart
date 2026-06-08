import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({
    super.key,
    required this.role,
    required this.workOrders,
    this.onClose,
  });

  final AppRole role;
  final List<WorkOrder> workOrders;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final total = workOrders.length;
    final open = workOrders.where((job) => job.status != 'Approved').length;
    final urgent = workOrders.where((job) => _slaHours(job) <= 12).length;
    final personRows = _personRows();

    return AppScrollView(
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(_titleForRole(role))),
            if (onClose != null)
              IconButton(
                tooltip: 'Close analytics',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryChip(
              icon: Icons.work_outline,
              label: 'Total jobs',
              value: '$total',
              color: AppTheme.primary,
            ),
            _SummaryChip(
              icon: Icons.pending_actions_outlined,
              label: 'Open',
              value: '$open',
              color: AppTheme.warning,
            ),
            _SummaryChip(
              icon: Icons.timer_outlined,
              label: 'Due <= 12h',
              value: '$urgent',
              color: AppTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Per Person'),
        const SizedBox(height: 10),
        if (personRows.isEmpty)
          const _EmptyAnalyticsCard()
        else
          ...personRows.map((row) => _PersonAnalyticsCard(row: row)),
      ],
    );
  }

  List<_PersonRow> _personRows() {
    final grouped = <String, List<WorkOrder>>{};
    for (final job in workOrders) {
      final person = _personFor(job);
      grouped.putIfAbsent(person, () => []).add(job);
    }

    final rows = grouped.entries.map((entry) {
      final jobs = entry.value;
      return _PersonRow(
        entry.key,
        jobs.length,
        jobs.where((job) => job.status != 'Approved').length,
        jobs.where((job) => job.status == 'Dispatched').length,
        jobs.where((job) => job.status == 'On Site').length,
        jobs.where((job) => job.status == 'Submitted').length,
        jobs.where((job) => job.status == 'Approved').length,
        jobs.where((job) => _slaHours(job) <= 12).length,
      );
    }).toList();

    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows;
  }

  String _personFor(WorkOrder job) {
    return job.assignedTo ?? job.supervisor ?? job.createdBy ?? 'Unassigned';
  }

  String _titleForRole(AppRole role) {
    return switch (role) {
      AppRole.admin => 'Company Analytics',
      AppRole.supervisor => 'Team Analytics',
      AppRole.technician => 'My Analytics',
    };
  }

  int _slaHours(WorkOrder job) {
    final match = RegExp(r'\d+').firstMatch(job.sla);
    return int.tryParse(match?.group(0) ?? '') ?? 999;
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconPill(icon: icon, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: const TextStyle(color: AppTheme.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonAnalyticsCard extends StatelessWidget {
  const _PersonAnalyticsCard({required this.row});

  final _PersonRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconPill(
                    icon: Icons.person_outline,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: '${row.total} jobs',
                    color: AppTheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(
                    icon: Icons.pending_outlined,
                    label: '${row.open} open',
                  ),
                  InfoChip(
                    icon: Icons.outbound,
                    label: '${row.dispatched} dispatched',
                  ),
                  InfoChip(
                    icon: Icons.location_on_outlined,
                    label: '${row.onSite} on site',
                  ),
                  InfoChip(
                    icon: Icons.done_all,
                    label: '${row.submitted} submitted',
                  ),
                  InfoChip(
                    icon: Icons.verified_outlined,
                    label: '${row.approved} approved',
                  ),
                  InfoChip(
                    icon: Icons.timer_outlined,
                    label: '${row.urgent} urgent',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAnalyticsCard extends StatelessWidget {
  const _EmptyAnalyticsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('No jobs available for analytics.'),
      ),
    );
  }
}

class _PersonRow {
  const _PersonRow(
    this.name,
    this.total,
    this.open,
    this.dispatched,
    this.onSite,
    this.submitted,
    this.approved,
    this.urgent,
  );

  final String name;
  final int total;
  final int open;
  final int dispatched;
  final int onSite;
  final int submitted;
  final int approved;
  final int urgent;
}
