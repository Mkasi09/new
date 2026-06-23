import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

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
    this.onAddUser,
    required this.onOpenTeamQueue,
    required this.onOpenSupervisorJob,
    required this.onAcceptOrder,
    required this.onOpenReviewOrder,
    required this.onAssignOrder,
    required this.onScanArrival,
    required this.onUploadEvidence,
    required this.onOpenCompletionDetails,
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
  final VoidCallback? onAddUser;
  final VoidCallback onOpenTeamQueue;
  final ValueChanged<WorkOrder> onOpenSupervisorJob;
  final Future<void> Function(WorkOrder) onAcceptOrder;
  final ValueChanged<WorkOrder> onOpenReviewOrder;
  final Future<void> Function(WorkOrder) onAssignOrder;
  final Future<bool?> Function(WorkOrder) onScanArrival;
  final Future<List<String>?> Function(WorkOrder, String?) onUploadEvidence;
  final ValueChanged<WorkOrder> onOpenCompletionDetails;
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
        onAddUser: widget.onAddUser,
        onOpenReviewOrder: widget.onOpenReviewOrder,
      ),
      AppRole.supervisor => _SupervisorHome(
        workOrders: widget.workOrders,
        selectedOrder: widget.selectedOrder,
        onOpenTeamQueue: widget.onOpenTeamQueue,
        onOpenSupervisorJob: widget.onOpenSupervisorJob,
        onAcceptOrder: widget.onAcceptOrder,
        onAssignOrder: widget.onAssignOrder,
      ),
      AppRole.technician => _TechnicianHome(
        order: widget.selectedOrder,
        pendingJobs: _pendingTechnicianJobs(widget.workOrders),
        jobSteps: widget.jobSteps,
        materials: widget.materials,
        arrivalVerified: arrivalVerified,
        evidenceUploaded: evidenceUploaded,
        evidenceSlots: _evidenceSlots,
        onScanSiteQr: _scanSiteQr,
        onUploadImages: _uploadImages,
        onOpenOrder: widget.onOpenOrder,
        onOpenCompletionDetails: widget.onOpenCompletionDetails,
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

  Future<void> _uploadImages(BuildContext context, String slot) async {
    final evidenceSlots = await widget.onUploadEvidence(
      widget.selectedOrder,
      slot,
    );

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

  int _pendingTechnicianJobs(List<WorkOrder> orders) {
    return orders
        .where(
          (order) => order.status != 'Submitted' && order.status != 'Approved',
        )
        .length;
  }
}

class _AdminHome extends StatelessWidget {
  const _AdminHome({
    required this.workOrders,
    required this.onOpenOrder,
    required this.onCreateJob,
    required this.onOpenAnalytics,
    required this.onOpenReviewQueue,
    this.onAddUser,
    required this.onOpenReviewOrder,
  });

  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpenOrder;
  final VoidCallback onCreateJob;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenReviewQueue;
  final VoidCallback? onAddUser;
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
            _RoleAction(
              Icons.fact_check_outlined,
              'Review',
              onOpenReviewQueue,
              badgeCount: unreviewed,
            ),
            _RoleAction(Icons.analytics_outlined, 'Analytics', onOpenAnalytics),
            if (onAddUser != null)
              _RoleAction(
                Icons.person_add_alt_1_outlined,
                'Add User',
                onAddUser!,
              ),
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
  });

  final List<WorkOrder> workOrders;
  final WorkOrder selectedOrder;
  final VoidCallback onOpenTeamQueue;
  final ValueChanged<WorkOrder> onOpenSupervisorJob;
  final Future<void> Function(WorkOrder) onAcceptOrder;
  final Future<void> Function(WorkOrder) onAssignOrder;

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
                      label: selectedOrder.technicianLabel ?? 'No technician',
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
      ],
    );
  }
}

class _TechnicianHome extends StatelessWidget {
  const _TechnicianHome({
    required this.order,
    required this.pendingJobs,
    required this.jobSteps,
    required this.materials,
    required this.arrivalVerified,
    required this.evidenceUploaded,
    required this.evidenceSlots,
    required this.onScanSiteQr,
    required this.onUploadImages,
    required this.onOpenOrder,
    required this.onOpenCompletionDetails,
    required this.onSubmitCompletion,
  });

  final WorkOrder order;
  final int pendingJobs;
  final List<JobStep> jobSteps;
  final List<MaterialLine> materials;
  final bool arrivalVerified;
  final bool evidenceUploaded;
  final List<String> evidenceSlots;
  final ValueChanged<BuildContext> onScanSiteQr;
  final void Function(BuildContext, String) onUploadImages;
  final ValueChanged<WorkOrder> onOpenOrder;
  final ValueChanged<WorkOrder> onOpenCompletionDetails;
  final Future<void> Function(WorkOrder) onSubmitCompletion;

  @override
  Widget build(BuildContext context) {
    final submitted = order.status == 'Submitted' || order.status == 'Approved';
    final beforeUploaded = evidenceSlots.contains('before');
    final afterUploaded = evidenceSlots.contains('after');
    final completionReady =
        order.technicianNotes?.trim().isNotEmpty == true &&
        order.customerName?.trim().isNotEmpty == true &&
        order.customerSignature?.isNotEmpty == true;
    final progress = _technicianProgress(
      arrivalVerified: arrivalVerified,
      beforeUploaded: beforeUploaded,
      afterUploaded: afterUploaded,
      completionReady: completionReady,
      submitted: submitted,
    );

    return AppScrollView(
      children: [
        _TodaySummaryCard(
          order: order,
          pendingJobs: pendingJobs,
          progress: progress,
          arrivalVerified: arrivalVerified,
        ),
        const SizedBox(height: 12),
        _TodayActionPanel(
          progress: progress,
          arrivalVerified: arrivalVerified,
          beforeUploaded: beforeUploaded,
          afterUploaded: afterUploaded,
          completionReady: completionReady,
          submitted: submitted,
          onScanSiteQr: arrivalVerified ? null : () => onScanSiteQr(context),
          onUploadBefore: beforeUploaded
              ? null
              : () => onUploadImages(context, 'before'),
          onUploadAfter: afterUploaded
              ? null
              : () => onUploadImages(context, 'after'),
          onCompletionDetails: submitted
              ? null
              : () => onOpenCompletionDetails(order),
          onSubmitCompletion: submitted
              ? null
              : !completionReady
              ? null
              : () => onSubmitCompletion(order),
        ),
        const SizedBox(height: 12),
        _TechnicianJobDetails(order: order, onTap: () => onOpenOrder(order)),
      ],
    );
  }

  double _technicianProgress({
    required bool arrivalVerified,
    required bool beforeUploaded,
    required bool afterUploaded,
    required bool completionReady,
    required bool submitted,
  }) {
    final completed = [
      arrivalVerified,
      beforeUploaded,
      afterUploaded,
      completionReady,
      submitted,
    ].where((done) => done).length;
    return completed / 5;
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.order,
    required this.pendingJobs,
    required this.progress,
    required this.arrivalVerified,
  });

  final WorkOrder order;
  final int pendingJobs;
  final double progress;
  final bool arrivalVerified;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconPill(
                  icon: Icons.route_outlined,
                  color: workOrderStatusColor(order.status),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Job',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.site,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(
                  label: order.status,
                  color: workOrderStatusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(icon: Icons.badge_outlined, label: order.id),
                InfoChip(
                  icon: Icons.pending_actions_outlined,
                  label: pendingJobs == 1
                      ? '1 pending job'
                      : '$pendingJobs pending jobs',
                ),
                InfoChip(icon: Icons.schedule_outlined, label: order.sla),
                InfoChip(
                  icon: Icons.priority_high,
                  label: order.priority.label,
                ),
                _CountdownChip(order: order, arrivalVerified: arrivalVerified),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.order, required this.arrivalVerified});

  final WorkOrder order;
  final bool arrivalVerified;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'Submitted' || order.status == 'Approved') {
      return InfoChip(
        icon: Icons.done_all,
        label: order.status == 'Approved' ? 'Approved' : 'Submitted',
      );
    }

    final dueAt = order.dueAt;
    if (dueAt == null) {
      return InfoChip(icon: Icons.schedule_outlined, label: 'Due not set');
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (tick) => tick),
      builder: (context, snapshot) {
        final remaining = dueAt.difference(DateTime.now());
        final late = remaining.isNegative;
        final displayDuration = late ? remaining.abs() : remaining;

        return InfoChip(
          icon: late
              ? Icons.warning_amber_outlined
              : arrivalVerified
              ? Icons.timer_outlined
              : Icons.qr_code_scanner,
          label: late
              ? 'Late ${_formatLongDuration(displayDuration)}'
              : arrivalVerified
              ? 'Time left ${_formatClock(displayDuration)}'
              : 'Due in ${_formatDueCountdown(displayDuration)}',
        );
      },
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

String _formatDueCountdown(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final parts = <String>[];

  if (days > 0) parts.add(days == 1 ? '1 day' : '$days days');
  if (hours > 0) parts.add(hours == 1 ? '1 hour' : '$hours hours');
  if (minutes > 0) parts.add(minutes == 1 ? '1 min' : '$minutes mins');
  if (parts.isEmpty) {
    parts.add(seconds == 1 ? '1 sec' : '$seconds secs');
  }

  return parts.join(' ');
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

class _TodayActionPanel extends StatelessWidget {
  const _TodayActionPanel({
    required this.progress,
    required this.arrivalVerified,
    required this.beforeUploaded,
    required this.afterUploaded,
    required this.completionReady,
    required this.submitted,
    required this.onScanSiteQr,
    required this.onUploadBefore,
    required this.onUploadAfter,
    required this.onCompletionDetails,
    required this.onSubmitCompletion,
  });

  final double progress;
  final bool arrivalVerified;
  final bool beforeUploaded;
  final bool afterUploaded;
  final bool completionReady;
  final bool submitted;
  final VoidCallback? onScanSiteQr;
  final VoidCallback? onUploadBefore;
  final VoidCallback? onUploadAfter;
  final VoidCallback? onCompletionDetails;
  final VoidCallback? onSubmitCompletion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Next Steps',
              trailing: '${(progress * 100).round()}% complete',
            ),
            const SizedBox(height: 12),
            _CompactWorkActionRow(
              icon: Icons.qr_code_scanner,
              title: 'Confirm arrival',
              complete: arrivalVerified,
              enabled: true,
              buttonLabel: 'Scan QR',
              onTap: onScanSiteQr,
            ),
            const Divider(height: 18),
            _CompactWorkActionRow(
              icon: Icons.photo_camera_outlined,
              title: 'Upload before photo',
              complete: beforeUploaded,
              enabled: arrivalVerified,
              buttonLabel: 'Upload Before',
              onTap: onUploadBefore,
            ),
            const Divider(height: 18),
            _CompactWorkActionRow(
              icon: Icons.photo_library_outlined,
              title: 'Upload after photo',
              complete: afterUploaded,
              enabled: arrivalVerified && beforeUploaded,
              buttonLabel: 'Upload After',
              onTap: onUploadAfter,
            ),
            const Divider(height: 18),
            _CompactWorkActionRow(
              icon: Icons.draw_outlined,
              title: 'Notes and customer sign-off',
              complete: completionReady,
              enabled: arrivalVerified,
              buttonLabel: completionReady ? 'Edit' : 'Complete',
              onTap: onCompletionDetails,
            ),
            const Divider(height: 18),
            _CompactWorkActionRow(
              icon: Icons.outbox_outlined,
              title: 'Submit job',
              complete: submitted,
              enabled:
                  arrivalVerified &&
                  beforeUploaded &&
                  afterUploaded &&
                  completionReady,
              buttonLabel: 'Submit',
              onTap: onSubmitCompletion,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactWorkActionRow extends StatelessWidget {
  const _CompactWorkActionRow({
    required this.icon,
    required this.title,
    required this.complete,
    required this.enabled,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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

    return Row(
      children: [
        IconPill(
          icon: complete ? Icons.check_circle_outline : icon,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        if (complete)
          const StatusChip(label: 'Done', color: AppTheme.success)
        else
          FilledButton(
            onPressed: enabled ? onTap : null,
            child: Text(buttonLabel),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: AppTheme.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnicianJobDetails extends StatelessWidget {
  const _TechnicianJobDetails({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JobOverviewPanel(order: order, onTap: onTap);
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
