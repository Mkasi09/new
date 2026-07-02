import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'widgets/common.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.role,
    required this.selectedOrder,
    required this.workOrders,
    required this.repository,
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
    required this.onOpenJobChat,
    required this.onOpenJobChats,
  });

  final AppRole role;
  final WorkOrder selectedOrder;
  final List<WorkOrder> workOrders;
  final IsdpRepository repository;
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
  final ValueChanged<WorkOrder> onOpenJobChat;
  final VoidCallback onOpenJobChats;

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
        onOpenJobChat: widget.onOpenJobChat,
        onOpenJobChats: widget.onOpenJobChats,
        repository: widget.repository,
      ),
      AppRole.supervisor => _SupervisorHome(
        workOrders: widget.workOrders,
        selectedOrder: widget.selectedOrder,
        onOpenTeamQueue: widget.onOpenTeamQueue,
        onOpenSupervisorJob: widget.onOpenSupervisorJob,
        onAcceptOrder: widget.onAcceptOrder,
        onAssignOrder: widget.onAssignOrder,
        onOpenJobChat: widget.onOpenJobChat,
        repository: widget.repository,
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
        onOpenJobChat: widget.onOpenJobChat,
        repository: widget.repository,
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
    required this.onOpenJobChat,
    required this.onOpenJobChats,
    required this.repository,
  });

  final List<WorkOrder> workOrders;
  final ValueChanged<WorkOrder> onOpenOrder;
  final VoidCallback onCreateJob;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenReviewQueue;
  final VoidCallback? onAddUser;
  final ValueChanged<WorkOrder> onOpenReviewOrder;
  final ValueChanged<WorkOrder> onOpenJobChat;
  final VoidCallback onOpenJobChats;
  final IsdpRepository repository;

  @override
  Widget build(BuildContext context) {
    final inProgress = workOrders
        .where(
          (order) => order.status != 'Submitted' && order.status != 'Approved',
        )
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
        _MetricStrip(
          metrics: [
            _MetricData(
              icon: Icons.timelapse_outlined,
              value: '$inProgress',
              label: 'In progress',
              color: AppTheme.primary,
            ),
            _MetricData(
              icon: Icons.rate_review_outlined,
              value: '${approvalQueue.length}',
              label: 'Awaiting review',
              color: AppTheme.warning,
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
            _RoleAction(
              Icons.forum_outlined,
              'Job Chats',
              onOpenJobChats,
              badgeStream: repository.watchUnreadJobMessageTotal(
                workOrders.map((order) => order.id).toList(),
              ),
            ),
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
    required this.onOpenJobChat,
    required this.repository,
  });

  final List<WorkOrder> workOrders;
  final WorkOrder selectedOrder;
  final VoidCallback onOpenTeamQueue;
  final ValueChanged<WorkOrder> onOpenSupervisorJob;
  final Future<void> Function(WorkOrder) onAcceptOrder;
  final Future<void> Function(WorkOrder) onAssignOrder;
  final ValueChanged<WorkOrder> onOpenJobChat;
  final IsdpRepository repository;

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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenJobChat(selectedOrder),
                    icon: const Icon(Icons.forum_outlined),
                    label: _ChatButtonLabel(
                      text: 'Job Chat',
                      stream: repository.watchUnreadJobMessageCount(
                        selectedOrder.id,
                      ),
                    ),
                  ),
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
    required this.onOpenJobChat,
    required this.repository,
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
  final ValueChanged<WorkOrder> onOpenJobChat;
  final IsdpRepository repository;

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
          onOpenJobChat: () => onOpenJobChat(order),
          unreadJobChatStream: repository.watchUnreadJobMessageCount(order.id),
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
    required this.onOpenJobChat,
    required this.unreadJobChatStream,
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
  final VoidCallback onOpenJobChat;
  final Stream<int> unreadJobChatStream;

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
            const Divider(height: 18),
            _CompactWorkActionRow(
              icon: Icons.forum_outlined,
              title: 'Job communication',
              complete: false,
              enabled: true,
              buttonLabel: 'Open Chat',
              onTap: onOpenJobChat,
              badgeStream: unreadJobChatStream,
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
    this.badgeStream,
  });

  final IconData icon;
  final String title;
  final bool complete;
  final bool enabled;
  final String buttonLabel;
  final VoidCallback? onTap;
  final Stream<int>? badgeStream;

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
            child: badgeStream == null
                ? Text(buttonLabel)
                : _ChatButtonLabel(text: buttonLabel, stream: badgeStream!),
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

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 360 ? metrics.length : 1;
        final spacing = 10.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                height: 104,
                child: _MetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconPill(icon: metric.icon, color: metric.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    metric.label,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? actions.length : 2;
        final spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  height: 78,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: action.onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(action.icon, color: AppTheme.primary),
                                  const SizedBox(height: 5),
                                  Text(
                                    action.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _ActionBadge(action: action),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});

  final _RoleAction action;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 2,
      top: 2,
      child: action.badgeStream == null
          ? _ActionBadgeValue(count: action.badgeCount)
          : StreamBuilder<int>(
              stream: action.badgeStream,
              builder: (context, snapshot) {
                return _ActionBadgeValue(
                  count: snapshot.data ?? action.badgeCount,
                );
              },
            ),
    );
  }
}

class _ActionBadgeValue extends StatelessWidget {
  const _ActionBadgeValue({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return _CountBadge(count: count);
  }
}

class _RoleAction {
  const _RoleAction(
    this.icon,
    this.label,
    this.onTap, {
    this.badgeCount = 0,
    this.badgeStream,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final Stream<int>? badgeStream;
}

class _ChatButtonLabel extends StatelessWidget {
  const _ChatButtonLabel({required this.text, required this.stream});

  final String text;
  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return Text(text);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text),
            const SizedBox(width: 8),
            _InlineUnreadChip(count: count),
          ],
        );
      },
    );
  }
}

class _InlineUnreadChip extends StatelessWidget {
  const _InlineUnreadChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      count > 99 ? '99+ unread' : '$count unread',
      style: const TextStyle(
        color: AppTheme.danger,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return UnreadCountBadge(count: count);
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
