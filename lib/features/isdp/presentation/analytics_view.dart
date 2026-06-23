import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class AnalyticsView extends StatefulWidget {
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
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String? _selectedPerson;

  @override
  Widget build(BuildContext context) {
    final total = widget.workOrders.length;
    final open = widget.workOrders
        .where((job) => job.status != 'Approved')
        .length;
    final urgent = widget.workOrders
        .where((job) => _slaHours(job) <= 12)
        .length;
    final personRows = _personRows();
    final selectedRow = _selectedRow(personRows);

    return AppScrollView(
      children: [
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                selectedRow == null
                    ? _titleForRole(widget.role)
                    : selectedRow.name,
              ),
            ),
            if (selectedRow != null)
              IconButton(
                tooltip: 'Back to people',
                onPressed: () => setState(() => _selectedPerson = null),
                icon: const Icon(Icons.arrow_back),
              ),
            if (widget.onClose != null)
              IconButton(
                tooltip: 'Close analytics',
                onPressed: widget.onClose,
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
        if (selectedRow == null)
          _PeopleOverview(
            rows: personRows,
            onSelect: (row) => setState(() => _selectedPerson = row.name),
          )
        else
          _PersonDrilldown(row: selectedRow),
      ],
    );
  }

  _PersonRow? _selectedRow(List<_PersonRow> rows) {
    final selectedPerson = _selectedPerson;
    if (selectedPerson == null) return null;
    for (final row in rows) {
      if (row.name == selectedPerson) return row;
    }
    return null;
  }

  List<_PersonRow> _personRows() {
    final grouped = <String, List<WorkOrder>>{};
    for (final job in widget.workOrders) {
      for (final person in _peopleFor(job)) {
        grouped.putIfAbsent(person, () => []).add(job);
      }
    }

    final rows = grouped.entries.map((entry) {
      final jobs = entry.value;
      return _PersonRow(
        name: entry.key,
        jobs: jobs,
        total: jobs.length,
        open: jobs.where((job) => job.status != 'Approved').length,
        dispatched: jobs.where((job) => job.status == 'Dispatched').length,
        onSite: jobs.where((job) => job.status == 'On Site').length,
        submitted: jobs.where((job) => job.status == 'Submitted').length,
        approved: jobs.where((job) => job.status == 'Approved').length,
        urgent: jobs.where((job) => _slaHours(job) <= 12).length,
      );
    }).toList();

    rows.sort((a, b) {
      final totalCompare = b.total.compareTo(a.total);
      if (totalCompare != 0) return totalCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return rows;
  }

  List<String> _peopleFor(WorkOrder job) {
    if (job.technicianNames.isNotEmpty) return job.technicianNames;
    if (job.supervisor?.trim().isNotEmpty == true) return [job.supervisor!];
    final creator = displayPersonName(job.createdBy);
    return [creator.isEmpty ? 'Unassigned' : creator];
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

class _PeopleOverview extends StatelessWidget {
  const _PeopleOverview({required this.rows, required this.onSelect});

  final List<_PersonRow> rows;
  final ValueChanged<_PersonRow> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('People'),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _EmptyAnalyticsCard()
        else
          Card(
            child: Column(
              children: [
                for (final row in rows) ...[
                  _PersonAnalyticsRow(row: row, onTap: () => onSelect(row)),
                  if (row != rows.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
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

class _PersonAnalyticsRow extends StatelessWidget {
  const _PersonAnalyticsRow({required this.row, required this.onTap});

  final _PersonRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const IconPill(icon: Icons.person_outline, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${row.open} open | ${row.submitted} submitted | ${row.approved} approved',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            StatusChip(label: '${row.total}', color: AppTheme.primary),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _PersonDrilldown extends StatelessWidget {
  const _PersonDrilldown({required this.row});

  final _PersonRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoChip(icon: Icons.work_outline, label: '${row.total} jobs'),
            InfoChip(icon: Icons.pending_outlined, label: '${row.open} open'),
            InfoChip(
              icon: Icons.outbound,
              label: '${row.dispatched} dispatched',
            ),
            InfoChip(
              icon: Icons.location_on_outlined,
              label: '${row.onSite} on site',
            ),
            InfoChip(icon: Icons.done_all, label: '${row.submitted} submitted'),
            InfoChip(
              icon: Icons.verified_outlined,
              label: '${row.approved} approved',
            ),
            InfoChip(icon: Icons.timer_outlined, label: '${row.urgent} urgent'),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Jobs'),
        const SizedBox(height: 10),
        ...row.jobs.map((job) => _AnalyticsJobCard(job: job)),
      ],
    );
  }
}

class _AnalyticsJobCard extends StatelessWidget {
  const _AnalyticsJobCard({required this.job});

  final WorkOrder job;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconPill(
                icon: Icons.assignment_outlined,
                color: workOrderStatusColor(job.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.site,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(job.id, style: const TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 3),
                    Text(
                      job.sla,
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: job.status,
                color: workOrderStatusColor(job.status),
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
  const _PersonRow({
    required this.name,
    required this.jobs,
    required this.total,
    required this.open,
    required this.dispatched,
    required this.onSite,
    required this.submitted,
    required this.approved,
    required this.urgent,
  });

  final String name;
  final List<WorkOrder> jobs;
  final int total;
  final int open;
  final int dispatched;
  final int onSite;
  final int submitted;
  final int approved;
  final int urgent;
}
