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
    this.onOpenJob,
    this.onClose,
  });

  final AppRole role;
  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder>? onOpenJob;
  final VoidCallback? onClose;

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  final _searchController = TextEditingController();
  String? _selectedPerson;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.workOrders.length;
    final inProgress = widget.workOrders
        .where((job) => job.status != 'Submitted' && job.status != 'Approved')
        .length;
    final awaitingReview = widget.workOrders
        .where((job) => job.status == 'Submitted')
        .length;
    final urgent = widget.workOrders
        .where((job) => job.status != 'Approved' && _slaHours(job) <= 12)
        .length;
    final allPersonRows = _personRows();
    final selectedRow = _selectedRow(allPersonRows);
    final matchingPersonRows = allPersonRows
        .where((row) => _matchesPersonRow(row, _query))
        .toList();
    final personRows = selectedRow == null
        ? _query.isEmpty
              ? matchingPersonRows.take(5).toList()
              : matchingPersonRows
        : allPersonRows;

    return AppScrollView(
      children: [
        _AnalyticsHeader(
          title: selectedRow == null
              ? _titleForRole(widget.role)
              : selectedRow.name,
          subtitle: selectedRow == null
              ? 'Workload, review pressure, and field activity by person.'
              : 'Jobs and status breakdown for this person.',
          onBack: selectedRow == null
              ? null
              : () => setState(() => _selectedPerson = null),
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14),
        _SummaryGrid(
          items: [
            _SummaryMetric(
              icon: Icons.work_outline,
              label: 'Total',
              value: '$total',
              color: AppTheme.primary,
            ),
            _SummaryMetric(
              icon: Icons.pending_actions_outlined,
              label: 'In progress',
              value: '$inProgress',
              color: AppTheme.warning,
            ),
            _SummaryMetric(
              icon: Icons.rate_review_outlined,
              label: 'Awaiting review',
              value: '$awaitingReview',
              color: AppTheme.secondary,
            ),
            _SummaryMetric(
              icon: Icons.timer_outlined,
              label: 'Due in less than 12h',
              value: '$urgent',
              color: AppTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (selectedRow == null)
          _PeopleOverview(
            rows: personRows,
            searchController: _searchController,
            query: _query,
            onSearchChanged: (value) => setState(() => _query = value.trim()),
            onClearSearch: _query.isEmpty
                ? null
                : () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
            onSelect: (row) {
              _searchController.clear();
              setState(() {
                _query = '';
                _selectedPerson = row.name;
              });
            },
          )
        else
          _PersonDrilldown(
            row: selectedRow,
            query: _query,
            onOpenJob: widget.onOpenJob,
          ),
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
        open: jobs
            .where((job) => job.status != 'Approved' && job.status != 'Closed')
            .length,
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

  bool _matchesPersonRow(_PersonRow row, String query) {
    if (query.isEmpty) return true;
    final value = query.toLowerCase();
    return row.name.toLowerCase().contains(value) ||
        row.jobs.any((job) => _matchesJob(job, value));
  }
}

class _PeopleOverview extends StatelessWidget {
  const _PeopleOverview({
    required this.rows,
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelect,
  });

  final List<_PersonRow> rows;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearSearch;
  final ValueChanged<_PersonRow> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('People'),
        const SizedBox(height: 10),
        _AnalyticsSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          _EmptyAnalyticsCard(
            message: query.isEmpty
                ? 'No jobs available for analytics.'
                : 'No people match this search.',
          )
        else
          Column(
            children: [
              for (final row in rows)
                _PersonAnalyticsRow(row: row, onTap: () => onSelect(row)),
            ],
          ),
      ],
    );
  }
}

class _AnalyticsSearchField extends StatelessWidget {
  const _AnalyticsSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Search people or jobs',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconPill(
              icon: onBack == null
                  ? Icons.analytics_outlined
                  : Icons.person_search_outlined,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(title),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onBack != null)
              IconButton(
                tooltip: 'Back to people',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            if (onClose != null)
              IconButton(
                tooltip: 'Close analytics',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryMetric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? items.length
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        final spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                height: 104,
                child: _SummaryCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryMetric item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconPill(icon: item.icon, color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final activeShare = row.total == 0 ? 0.0 : row.open / row.total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconPill(
                  icon: Icons.person_outline,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: activeShare,
                          minHeight: 7,
                          backgroundColor: AppTheme.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniMetric(
                            label: 'active',
                            value: row.open,
                            color: AppTheme.warning,
                          ),
                          _MiniMetric(
                            label: 'review',
                            value: row.submitted,
                            color: AppTheme.secondary,
                          ),
                          if (row.urgent > 0)
                            _MiniMetric(
                              label: 'urgent',
                              value: row.urgent,
                              color: AppTheme.danger,
                            ),
                          _MiniMetric(label: 'total', value: row.total),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _WorkloadBadge(count: row.open),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    this.color = AppTheme.muted,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value $label',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    );
  }
}

class _WorkloadBadge extends StatelessWidget {
  const _WorkloadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 999 ? '999+' : '$count',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PersonDrilldown extends StatelessWidget {
  const _PersonDrilldown({
    required this.row,
    required this.query,
    required this.onOpenJob,
  });

  final _PersonRow row;
  final String query;
  final ValueChanged<WorkOrder>? onOpenJob;

  @override
  Widget build(BuildContext context) {
    final activeShare = row.total == 0 ? 0.0 : row.open / row.total;
    final matchingJobs = query.isEmpty
        ? row.jobs
        : row.jobs
              .where((job) => _matchesJob(job, query.toLowerCase()))
              .toList();
    final visibleJobs = [
      ...matchingJobs.where((job) => job.status != 'Approved'),
      ...matchingJobs.where((job) => job.status == 'Approved'),
    ].take(12).toList();
    final hiddenJobs = matchingJobs.length - visibleJobs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconPill(
                      icon: Icons.insights_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${row.open} active jobs',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _WorkloadBadge(count: row.open),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: activeShare,
                    minHeight: 8,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: '${row.open} active',
                      color: AppTheme.warning,
                    ),
                    StatusChip(
                      label: '${row.submitted} awaiting review',
                      color: AppTheme.secondary,
                    ),
                    if (row.urgent > 0)
                      StatusChip(
                        label: '${row.urgent} urgent',
                        color: AppTheme.danger,
                      ),
                    InfoChip(
                      icon: Icons.history_outlined,
                      label: '${row.total} total',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Jobs Needing Attention'),
        const SizedBox(height: 10),
        if (visibleJobs.isEmpty)
          const _EmptyAnalyticsCard(message: 'No jobs match this search.')
        else
          ...visibleJobs.map(
            (job) => _AnalyticsJobCard(
              job: job,
              onTap: onOpenJob == null ? null : () => onOpenJob!(job),
            ),
          ),
        if (hiddenJobs > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$hiddenJobs older completed jobs hidden',
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnalyticsJobCard extends StatelessWidget {
  const _AnalyticsJobCard({required this.job, required this.onTap});

  final WorkOrder job;
  final VoidCallback? onTap;

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        job.id,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
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
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppTheme.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAnalyticsCard extends StatelessWidget {
  const _EmptyAnalyticsCard({
    this.message = 'No jobs available for analytics.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

bool _matchesJob(WorkOrder job, String query) {
  if (query.isEmpty) return true;
  final values = [
    job.id,
    job.site,
    job.address,
    job.scope,
    job.status,
    job.sla,
    job.supervisor,
    job.assignedTo,
    ...job.technicianNames,
  ];
  return values.whereType<String>().any(
    (value) => value.toLowerCase().contains(query),
  );
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
