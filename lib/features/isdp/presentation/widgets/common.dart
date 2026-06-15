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
              InfoChip(icon: Icons.priority_high, label: order.priority.label),
              if (order.supervisor != null)
                InfoChip(
                  icon: Icons.supervisor_account_outlined,
                  label: order.supervisor!,
                ),
              if (order.assignedTo != null)
                InfoChip(icon: Icons.person_outline, label: order.assignedTo!),
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.site,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              StatusChip(
                label: order.status,
                color: workOrderStatusColor(order.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.scope,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(order.id, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 4),
          Text(order.address, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(icon: Icons.schedule, label: order.sla),
              if (order.supervisor != null)
                InfoChip(
                  icon: Icons.supervisor_account_outlined,
                  label: order.supervisor!,
                ),
              if (order.assignedTo != null)
                InfoChip(icon: Icons.person_outline, label: order.assignedTo!),
            ],
          ),
        ],
      ),
    );
  }
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
    case 'On Site':
    case 'Onsite':
      return AppTheme.secondary;
    case 'Dispatched':
      return AppTheme.primary;
    default:
      return AppTheme.warning;
  }
}
