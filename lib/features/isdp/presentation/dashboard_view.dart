import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

void _showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.role,
    required this.selectedOrder,
    required this.workOrders,
    required this.jobSteps,
    required this.materials,
    required this.onOpenOrder,
    required this.onCreateJob,
    required this.onOpenAnalytics,
    required this.onOpenReviewQueue,
    required this.onOpenTeamQueue,
    required this.onOpenSupervisorJob,
    required this.onAcceptOrder,
    required this.onOpenReviewOrder,
    required this.onAssignOrder,
    required this.onMessageOrder,
    required this.onFollowUpOrder,
    required this.onScanArrival,
    required this.onUploadEvidence,
    required this.onSubmitCompletion,
  });

  final AppRole role;
  final WorkOrder selectedOrder;
  final List<WorkOrder> workOrders;
  final List<JobStep> jobSteps;
  final List<MaterialLine> materials;
  final ValueChanged<WorkOrder> onOpenOrder;
  final VoidCallback onCreateJob;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenReviewQueue;
  final VoidCallback onOpenTeamQueue;
  final ValueChanged<WorkOrder> onOpenSupervisorJob;
  final Future<void> Function(WorkOrder) onAcceptOrder;
  final ValueChanged<WorkOrder> onOpenReviewOrder;
  final Future<void> Function(WorkOrder) onAssignOrder;
  final ValueChanged<WorkOrder> onMessageOrder;
  final ValueChanged<WorkOrder> onFollowUpOrder;
  final Future<bool?> Function(WorkOrder) onScanArrival;
  final Future<List<String>?> Function(WorkOrder) onUploadEvidence;
  final Future<void> Function(WorkOrder) onSubmitCompletion;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _arrivalVerified = false;
  bool _evidenceUploaded = false;
  List<String> _evidenceSlots = const [];

  @override
  void initState() {
    super.initState();
    _syncSavedProgress();
  }

  @override
  void didUpdateWidget(covariant DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOrder.id != widget.selectedOrder.id ||
        oldWidget.selectedOrder.arrivalVerified !=
            widget.selectedOrder.arrivalVerified ||
        oldWidget.selectedOrder.evidenceUploaded !=
            widget.selectedOrder.evidenceUploaded ||
        oldWidget.selectedOrder.evidenceSlots !=
            widget.selectedOrder.evidenceSlots) {
      _syncSavedProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final arrivalVerified =
        _arrivalVerified || widget.selectedOrder.arrivalVerified;
    final evidenceUploaded =
        _evidenceUploaded ||
        widget.selectedOrder.evidenceUploaded ||
        _hasAllEvidenceSlots(_evidenceSlots);

    return switch (widget.role) {
      AppRole.admin => _AdminHome(
        workOrders: widget.workOrders,
        onOpenOrder: widget.onOpenOrder,
        onCreateJob: widget.onCreateJob,
        onOpenAnalytics: widget.onOpenAnalytics,
        onOpenReviewQueue: widget.onOpenReviewQueue,
        onOpenReviewOrder: widget.onOpenReviewOrder,
      ),
      AppRole.supervisor => _SupervisorHome(
        workOrders: widget.workOrders,
        selectedOrder: widget.selectedOrder,
        onOpenTeamQueue: widget.onOpenTeamQueue,
        onOpenSupervisorJob: widget.onOpenSupervisorJob,
        onAcceptOrder: widget.onAcceptOrder,
        onAssignOrder: widget.onAssignOrder,
        onMessageOrder: widget.onMessageOrder,
        onFollowUpOrder: widget.onFollowUpOrder,
      ),
      AppRole.technician => _TechnicianHome(
        order: widget.selectedOrder,
        jobSteps: widget.jobSteps,
        materials: widget.materials,
        arrivalVerified: arrivalVerified,
        evidenceUploaded: evidenceUploaded,
        evidenceSlots: _evidenceSlots,
        onScanSiteQr: _scanSiteQr,
        onUploadImages: _uploadImages,
        onOpenOrder: widget.onOpenOrder,
        onSubmitCompletion: widget.onSubmitCompletion,
      ),
    };
  }

  void _syncSavedProgress() {
    _arrivalVerified = widget.selectedOrder.arrivalVerified;
    _evidenceSlots = widget.selectedOrder.evidenceSlots;
    _evidenceUploaded =
        widget.selectedOrder.evidenceUploaded ||
        _hasAllEvidenceSlots(_evidenceSlots);
  }

  Future<void> _scanSiteQr(BuildContext context) async {
    final matched = await widget.onScanArrival(widget.selectedOrder);

    if (!context.mounted || matched == null) return;

    setState(() => _arrivalVerified = matched);
    if (matched) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR code does not match this job.')),
    );
  }

  Future<void> _uploadImages(BuildContext context) async {
    final evidenceSlots = await widget.onUploadEvidence(widget.selectedOrder);

    if (!context.mounted || evidenceSlots == null) return;

    final complete = _hasAllEvidenceSlots(evidenceSlots);
    setState(() {
      _evidenceSlots = evidenceSlots;
      _evidenceUploaded = complete;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          complete
              ? 'Evidence pack complete for ${widget.selectedOrder.site}.'
              : 'Evidence progress saved. Continue with the next photo after the next step.',
        ),
      ),
    );
  }

  bool _hasAllEvidenceSlots(List<String> slots) {
    return const ['before', 'after'].every(slots.contains);
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({
    required this.workOrders,
    required this.onOpenOrder,
    required this.onCreateJob,
    required this.onOpenAnalytics,
    required this.onOpenReviewQueue,
    required this.onOpenReviewOrder,
  });

  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpenOrder;
  final VoidCallback onCreateJob;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenReviewQueue;
  final ValueChanged<WorkOrder> onOpenReviewOrder;

  @override
  Widget build(BuildContext context) {
    final open = workOrders.where((order) => order.status != 'Approved').length;
    final done = workOrders
        .where((order) => order.status == 'Submitted')
        .length;
    final approvalQueue = workOrders
        .where((order) => order.status == 'Submitted')
        .toList();
    final unreviewed = approvalQueue.where((order) => !order.reviewed).length;

    return AppScrollView(
      children: [
        const _RoleHero(
          icon: Icons.approval_outlined,
          title: 'Admin Control',
          subtitle:
              'Create jobs, route them to the supervisor, and approve submitted jobs.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricTile(value: '$open', label: 'Open jobs'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(value: '$done', label: 'Submitted'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('admin-create-job-button'),
          onPressed: onCreateJob,
          icon: const Icon(Icons.add_task),
          label: const Text('Create Job'),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Admin Tools'),
        const SizedBox(height: 10),
        _ActionGrid(
          actions: [
            _RoleAction(Icons.add_task, 'Create job', onCreateJob),
            _RoleAction(
              Icons.fact_check_outlined,
              'Review',
              onOpenReviewQueue,
              badgeCount: unreviewed,
            ),
            _RoleAction(Icons.analytics_outlined, 'Analytics', onOpenAnalytics),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Needs Approval'),
        const SizedBox(height: 10),
        if (approvalQueue.isEmpty)
          const _EmptyRoleCard(
            icon: Icons.verified_outlined,
            title: 'No jobs waiting',
            detail:
                'Submitted completion packs from technicians will appear here.',
          )
        else
          ...approvalQueue.map(
            (order) => _ApprovalCard(
              order: order,
              onTap: () => onOpenOrder(order),
              onReview: () => onOpenReviewOrder(order),
            ),
          ),
      ],
    );
  }
}

class _SupervisorHome extends StatelessWidget {
  const _SupervisorHome({
    required this.workOrders,
    required this.selectedOrder,
    required this.onOpenTeamQueue,
    required this.onOpenSupervisorJob,
    required this.onAcceptOrder,
    required this.onAssignOrder,
    required this.onMessageOrder,
    required this.onFollowUpOrder,
  });

  final List<WorkOrder> workOrders;
  final WorkOrder selectedOrder;
  final VoidCallback onOpenTeamQueue;
  final ValueChanged<WorkOrder> onOpenSupervisorJob;
  final Future<void> Function(WorkOrder) onAcceptOrder;
  final Future<void> Function(WorkOrder) onAssignOrder;
  final ValueChanged<WorkOrder> onMessageOrder;
  final ValueChanged<WorkOrder> onFollowUpOrder;

  @override
  Widget build(BuildContext context) {
    final activeJobs = workOrders.where((order) => order.status != 'Approved');
    final awaitingAcceptance = selectedOrder.status == 'Assigned to Supervisor';

    return AppScrollView(
      children: [
        const _RoleHero(
          icon: Icons.groups_2_outlined,
          title: 'Supervisor Desk',
          subtitle:
              'Accept routed jobs, dispatch technicians, and monitor field progress.',
        ),
        const SizedBox(height: 18),
        const SectionTitle('Team'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const IconPill(
                  icon: Icons.work_outline,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${activeJobs.length} active jobs',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onOpenTeamQueue,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Team Queue'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Selected Job'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedOrder.site,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedOrder.scope,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: selectedOrder.status,
                      color: workOrderStatusColor(selectedOrder.status),
                    ),
                    InfoChip(
                      icon: Icons.person_outline,
                      label: selectedOrder.assignedTo ?? 'No technician',
                    ),
                    InfoChip(
                      icon: Icons.schedule_outlined,
                      label: selectedOrder.sla,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: awaitingAcceptance
                            ? () => onAcceptOrder(selectedOrder)
                            : () => onAssignOrder(selectedOrder),
                        icon: Icon(
                          awaitingAcceptance
                              ? Icons.assignment_turned_in_outlined
                              : Icons.person_add_alt,
                        ),
                        label: Text(
                          awaitingAcceptance
                              ? 'Accept Job'
                              : 'Assign Technician',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onOpenSupervisorJob(selectedOrder),
                        icon: const Icon(Icons.timeline_outlined),
                        label: const Text('View Progress'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Supervisor Actions'),
        const SizedBox(height: 10),
        _ActionGrid(
          actions: [
            _RoleAction(
              Icons.message_outlined,
              'Message',
              () => onMessageOrder(selectedOrder),
            ),
            _RoleAction(
              Icons.call_outlined,
              'Follow up',
              () => onFollowUpOrder(selectedOrder),
            ),
            _RoleAction(
              Icons.timer_outlined,
              'Due',
              () => _showInfo(
                context,
                '${selectedOrder.id}: ${selectedOrder.sla}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TechnicianHome extends StatelessWidget {
  const _TechnicianHome({
    required this.order,
    required this.jobSteps,
    required this.materials,
    required this.arrivalVerified,
    required this.evidenceUploaded,
    required this.evidenceSlots,
    required this.onScanSiteQr,
    required this.onUploadImages,
    required this.onOpenOrder,
    required this.onSubmitCompletion,
  });

  final WorkOrder order;
  final List<JobStep> jobSteps;
  final List<MaterialLine> materials;
  final bool arrivalVerified;
  final bool evidenceUploaded;
  final List<String> evidenceSlots;
  final ValueChanged<BuildContext> onScanSiteQr;
  final ValueChanged<BuildContext> onUploadImages;
  final ValueChanged<WorkOrder> onOpenOrder;
  final Future<void> Function(WorkOrder) onSubmitCompletion;

  @override
  Widget build(BuildContext context) {
    final submitted = order.status == 'Submitted' || order.status == 'Approved';
    final evidenceStep = _nextEvidenceStep(evidenceSlots);

    return AppScrollView(
      children: [
        _TechnicianHero(order: order),
        const SizedBox(height: 14),
        _CountdownCard(order: order, arrivalVerified: arrivalVerified),
        const SizedBox(height: 14),
        const SectionTitle('Next Steps'),
        const SizedBox(height: 10),
        _WorkActionCard(
          step: 1,
          title: 'Confirm arrival',
          detail: 'Scan the site QR when you arrive.',
          complete: arrivalVerified,
          enabled: true,
          buttonLabel: 'Scan QR',
          onTap: arrivalVerified ? null : () => onScanSiteQr(context),
        ),
        _WorkActionCard(
          step: 2,
          title: evidenceStep.title,
          detail: evidenceStep.detail,
          complete: evidenceUploaded,
          enabled: arrivalVerified,
          buttonLabel: evidenceStep.buttonLabel,
          onTap: evidenceUploaded ? null : () => onUploadImages(context),
        ),
        _WorkActionCard(
          step: 3,
          title: 'Submit job',
          detail: 'Send the completed job pack for approval.',
          complete: submitted,
          enabled: arrivalVerified && evidenceUploaded,
          buttonLabel: 'Submit',
          onTap: submitted ? null : () => onSubmitCompletion(order),
        ),
        const SizedBox(height: 14),
        _TechnicianJobDetails(order: order, onTap: () => onOpenOrder(order)),
      ],
    );
  }

  _EvidenceStep _nextEvidenceStep(List<String> uploadedSlots) {
    if (!uploadedSlots.contains('before')) {
      return const _EvidenceStep(
        'Upload before photo',
        'Capture the site or issue before starting the work.',
        'Upload Before',
      );
    }
    if (!uploadedSlots.contains('after')) {
      return const _EvidenceStep(
        'Upload after photo',
        'Capture the completed work after the job is done.',
        'Upload After',
      );
    }
    return const _EvidenceStep(
      'Evidence complete',
      'Before and after photos are saved.',
      'Done',
    );
  }
}

class _EvidenceStep {
  const _EvidenceStep(this.title, this.detail, this.buttonLabel);

  final String title;
  final String detail;
  final String buttonLabel;
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.order, required this.arrivalVerified});

  final WorkOrder order;
  final bool arrivalVerified;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'Submitted' || order.status == 'Approved') {
      return _CountdownFrame(
        icon: Icons.done_all,
        color: AppTheme.success,
        title: order.status == 'Approved'
            ? 'Job approved'
            : 'Submitted for approval',
        detail: order.status == 'Approved'
            ? 'This job is complete.'
            : 'Waiting for admin review and approval.',
      );
    }

    final dueAt = order.dueAt;
    if (dueAt == null) {
      return _CountdownFrame(
        icon: Icons.schedule_outlined,
        color: AppTheme.warning,
        title: 'Due time not set',
        detail: order.sla,
      );
    }

    if (!arrivalVerified) {
      return _CountdownFrame(
        icon: Icons.qr_code_scanner,
        color: AppTheme.muted,
        title: 'Scan QR to start countdown',
        detail: 'Due by ${_formatDateTime(dueAt)}',
      );
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (tick) => tick),
      builder: (context, snapshot) {
        final remaining = dueAt.difference(DateTime.now());
        final late = remaining.isNegative;
        final displayDuration = late ? remaining.abs() : remaining;

        return _CountdownFrame(
          icon: late ? Icons.warning_amber_outlined : Icons.timer_outlined,
          color: late ? AppTheme.danger : AppTheme.primary,
          title: late
              ? 'Late by ${_formatLongDuration(displayDuration)}'
              : 'Time left ${_formatClock(displayDuration)}',
          detail: 'Due by ${_formatDateTime(dueAt)}',
        );
      },
    );
  }
}

class _CountdownFrame extends StatelessWidget {
  const _CountdownFrame({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconPill(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
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

String _formatClock(Duration duration) {
  final totalHours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${_twoDigits(totalHours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

String _formatLongDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final dayText = days == 1 ? '1 day' : '$days days';
  if (days > 0) {
    return '$dayText ${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

String _formatDateTime(DateTime value) {
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)} '
      '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianHero extends StatelessWidget {
  const _TechnicianHero({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Job',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.site,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${order.address} - ${order.sla}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianJobDetails extends StatelessWidget {
  const _TechnicianJobDetails({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Job Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: order.status,
                    color: workOrderStatusColor(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                order.scope,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(icon: Icons.badge_outlined, label: order.id),
                  if (order.supervisor != null)
                    InfoChip(
                      icon: Icons.supervisor_account_outlined,
                      label: order.supervisor!,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.order,
    required this.onTap,
    required this.onReview,
  });

  final WorkOrder order;
  final VoidCallback onTap;
  final VoidCallback onReview;

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
                    const IconPill(
                      icon: Icons.verified_outlined,
                      color: AppTheme.success,
                    ),
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
                            '${order.id} - Review before and after evidence',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: order.reviewed ? 'Reviewed' : 'Needs review',
                      color: order.reviewed
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onReview,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_RoleAction> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = width >= 720 ? (width - 64) / actions.length : 158.0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (action) => SizedBox(
              width: itemWidth.clamp(118.0, 220.0),
              height: 78,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: action.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, color: AppTheme.primary),
                        const SizedBox(height: 5),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text(
                              action.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (action.badgeCount > 0)
                              Positioned(
                                right: -18,
                                top: -12,
                                child: _CountBadge(count: action.badgeCount),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RoleAction {
  const _RoleAction(this.icon, this.label, this.onTap, {this.badgeCount = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

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
        '$count',
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

class _EmptyRoleCard extends StatelessWidget {
  const _EmptyRoleCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            IconPill(icon: icon, color: AppTheme.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
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

class _WorkActionCard extends StatelessWidget {
  const _WorkActionCard({
    required this.step,
    required this.title,
    required this.detail,
    required this.complete,
    required this.enabled,
    required this.buttonLabel,
    required this.onTap,
  });

  final int step;
  final String title;
  final String detail;
  final bool complete;
  final bool enabled;
  final String buttonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = complete
        ? AppTheme.success
        : enabled
        ? AppTheme.primary
        : AppTheme.muted;
    final actionButton = complete
        ? const Text(
            'Done',
            style: TextStyle(
              color: AppTheme.success,
              fontWeight: FontWeight.w800,
            ),
          )
        : FilledButton(
            onPressed: enabled ? onTap : null,
            child: Text(buttonLabel),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled && !complete ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(step: step, complete: complete, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                actionButton,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.step,
    required this.complete,
    required this.color,
  });

  final int step;
  final bool complete;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: complete
            ? Icon(Icons.check, color: color)
            : Text(
                '$step',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}
