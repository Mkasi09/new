import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities.dart';

class AppScrollView extends StatelessWidget {
  const AppScrollView({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
            children: children,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class JobDetailHeader extends StatelessWidget {
  const JobDetailHeader({
    super.key,
    required this.title,
    required this.order,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final WorkOrder order;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.id} - ${order.siteCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(
                        label: order.status,
                        color: workOrderStatusColor(order.status),
                      ),
                      StatusChip(
                        label: order.priority.label,
                        color: priorityColor(order.priority),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class IconPill extends StatelessWidget {
  const IconPill({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class UnreadCountBadge extends StatelessWidget {
  const UnreadCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class JobOverviewPanel extends StatelessWidget {
  const JobOverviewPanel({
    super.key,
    required this.order,
    this.onTap,
    this.trailing,
  });

  final WorkOrder order;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final progress = workOrderProgress(order);
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconPill(
                icon: Icons.work_outline,
                color: workOrderStatusColor(order.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.site,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      order.id,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  StatusChip(
                    label: order.status,
                    color: workOrderStatusColor(order.status),
                  ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFFE9EEF5),
              color: workOrderStatusColor(order.status),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${workOrderStageLabel(order)} - ${(progress * 100).round()}%',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            order.scope,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, color: AppTheme.muted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.address,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(icon: Icons.schedule_outlined, label: order.sla),
              InfoChip(icon: Icons.badge_outlined, label: order.siteCode),
              InfoChip(icon: Icons.priority_high, label: order.priority.label),
              if (order.supervisor != null)
                InfoChip(
                  icon: Icons.supervisor_account_outlined,
                  label: order.supervisor!,
                ),
              if (order.technicianLabel != null)
                InfoChip(
                  icon: Icons.person_outline,
                  label: order.technicianLabel!,
                ),
              if (_workDurationText(order) != null)
                InfoChip(
                  icon: Icons.timer_outlined,
                  label: _workDurationText(order)!,
                ),
            ],
          ),
        ],
      ),
    );

    return Card(
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

String? _workDurationText(WorkOrder order) {
  final arrivedAt = order.arrivedAt;
  if (arrivedAt == null) return null;

  final endAt = order.submittedAt;
  final duration = (endAt ?? DateTime.now()).difference(arrivedAt);
  final prefix = endAt == null ? 'Working' : 'Worked';
  return '$prefix ${_formatDuration(duration)}';
}

String _formatDuration(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final days = safeDuration.inDays;
  final hours = safeDuration.inHours.remainder(24);
  final minutes = safeDuration.inMinutes.remainder(60);

  if (days > 0) {
    final dayText = days == 1 ? '1d' : '${days}d';
    return '$dayText ${hours}h ${minutes}m';
  }
  if (safeDuration.inHours > 0) {
    return '${safeDuration.inHours}h ${minutes}m';
  }
  return '${safeDuration.inMinutes}m';
}

class WorkDurationPanel extends StatelessWidget {
  const WorkDurationPanel({super.key, required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final arrivedAt = order.arrivedAt;
    final submittedAt = order.submittedAt;
    final color = submittedAt == null ? AppTheme.primary : AppTheme.success;
    final title = _workDurationText(order) ?? 'Not started';
    final detail = arrivedAt == null
        ? 'Technician has not scanned the site QR yet.'
        : submittedAt == null
        ? 'Counting from QR scan until technician submits the job.'
        : 'Measured from QR scan to job submission.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconPill(icon: Icons.timer_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time worked',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(detail, style: const TextStyle(color: AppTheme.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkOrderCard extends StatelessWidget {
  const WorkOrderCard({super.key, required this.order, this.onTap});

  final WorkOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: onTap == null
            ? _content()
            : InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: _content(),
              ),
      ),
    );
  }

  Widget _content() {
    final statusColor = workOrderStatusColor(order.status);

    return Padding(
      padding: const EdgeInsets.all(0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.site,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${order.id} - ${order.siteCode}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(label: order.status, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      order.scope,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        InfoChip(
                          icon: Icons.flag_outlined,
                          label: workOrderStageLabel(order),
                        ),
                        InfoChip(icon: Icons.schedule, label: order.sla),
                        InfoChip(
                          icon: Icons.priority_high,
                          label: order.priority.label,
                        ),
                        if (order.supervisor != null)
                          InfoChip(
                            icon: Icons.supervisor_account_outlined,
                            label: order.supervisor!,
                          ),
                        if (order.technicianLabel != null)
                          InfoChip(
                            icon: Icons.person_outline,
                            label: order.technicianLabel!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color priorityColor(Priority priority) {
  switch (priority) {
    case Priority.critical:
      return AppTheme.danger;
    case Priority.high:
      return AppTheme.warning;
    case Priority.low:
      return AppTheme.secondary;
  }
}

double workOrderProgress(WorkOrder order) {
  if (order.status == 'Approved') return 1;
  if (order.status == 'Submitted') return 0.88;
  if (order.evidenceSlots.contains('after')) return 0.76;
  if (order.evidenceSlots.contains('before')) return 0.62;
  if (order.arrivalVerified || order.status == 'On Site') return 0.5;
  if (order.status == 'Dispatched') return 0.38;
  if (order.technicianLabel != null) return 0.28;
  if (order.status == 'Accepted by Supervisor' || order.status == 'Accepted') {
    return 0.2;
  }
  return 0.1;
}

String workOrderStageLabel(WorkOrder order) {
  if (order.status == 'Approved') return 'Approved';
  if (order.status == 'Declined') return 'Correction required';
  if (order.status == 'Declined - Closed') return 'Declined and closed';
  if (order.status == 'Closed') return 'Closed';
  if (order.status == 'Submitted') return 'Awaiting review';
  if (order.evidenceSlots.contains('after')) return 'Ready to submit';
  if (order.evidenceSlots.contains('before')) return 'Work in progress';
  if (order.arrivalVerified || order.status == 'On Site') return 'On site';
  if (order.status == 'Dispatched') return 'Dispatched';
  if (order.technicianLabel != null) return 'Technician assigned';
  if (order.status == 'Accepted by Supervisor' || order.status == 'Accepted') {
    return 'Accepted';
  }
  if (order.status == 'Assigned to Supervisor') return 'Supervisor review';
  return 'New job';
}

Color workOrderStatusColor(String status) {
  switch (status) {
    case 'Assigned to Supervisor':
    case 'New':
      return AppTheme.warning;
    case 'Accepted by Supervisor':
    case 'Accepted':
      return AppTheme.secondary;
    case 'Submitted':
    case 'Complete':
      return AppTheme.success;
    case 'Approved':
      return AppTheme.success;
    case 'Declined':
    case 'Declined - Closed':
      return AppTheme.danger;
    case 'Closed':
      return AppTheme.muted;
    case 'On Site':
    case 'Onsite':
      return AppTheme.secondary;
    case 'Dispatched':
      return AppTheme.primary;
    default:
      return AppTheme.warning;
  }
}
