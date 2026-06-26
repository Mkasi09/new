import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/evidence_photo_thumbnail.dart';

class SupervisorJobScreen extends StatelessWidget {
  const SupervisorJobScreen({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onAssign,
    required this.onOpenChat,
    required this.unreadChatStream,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onAccept;
  final VoidCallback onAssign;
  final VoidCallback onOpenChat;
  final Stream<int> unreadChatStream;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final awaitingAcceptance = order.status == 'Assigned to Supervisor';

    return AppScrollView(
      children: [
        JobDetailHeader(title: 'Job Progress', order: order, onBack: onClose),
        const SizedBox(height: 12),
        JobOverviewPanel(order: order),
        const SizedBox(height: 14),
        _SupervisorActionPanel(
          awaitingAcceptance: awaitingAcceptance,
          onAccept: onAccept,
          onAssign: onAssign,
          onOpenChat: onOpenChat,
          unreadChatStream: unreadChatStream,
        ),
        const SizedBox(height: 14),
        _SupervisorProgress(order: order),
        const SizedBox(height: 14),
        _SupervisorEvidence(order: order),
      ],
    );
  }
}

class _SupervisorActionPanel extends StatelessWidget {
  const _SupervisorActionPanel({
    required this.awaitingAcceptance,
    required this.onAccept,
    required this.onAssign,
    required this.onOpenChat,
    required this.unreadChatStream,
  });

  final bool awaitingAcceptance;
  final VoidCallback onAccept;
  final VoidCallback onAssign;
  final VoidCallback onOpenChat;
  final Stream<int> unreadChatStream;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final primaryButton = FilledButton.icon(
              onPressed: awaitingAcceptance ? onAccept : onAssign,
              icon: Icon(
                awaitingAcceptance
                    ? Icons.assignment_turned_in_outlined
                    : Icons.person_add_alt,
              ),
              label: Text(
                awaitingAcceptance ? 'Accept Job' : 'Assign Technician',
              ),
            );
            final chatButton = OutlinedButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.forum_outlined),
              label: _UnreadChatLabel(stream: unreadChatStream),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primaryButton,
                  const SizedBox(height: 10),
                  chatButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: primaryButton),
                const SizedBox(width: 10),
                Expanded(child: chatButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UnreadChatLabel extends StatelessWidget {
  const _UnreadChatLabel({required this.stream});

  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const Text('Job Chat');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Job Chat'),
            const SizedBox(width: 8),
            Text(
              count > 99 ? '99+ unread' : '$count unread',
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SupervisorEvidence extends StatelessWidget {
  const _SupervisorEvidence({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final beforeSaved = order.evidenceSlots.contains('before');
    final afterSaved = order.evidenceSlots.contains('after');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evidence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _EvidenceRow(
              title: 'Before photo',
              detail: 'Captured before work started.',
              complete: beforeSaved,
              photoData: order.evidencePhotos['before'],
            ),
            const SizedBox(height: 10),
            _EvidenceRow(
              title: 'After photo',
              detail: 'Captured after work was completed.',
              complete: afterSaved,
              photoData: order.evidencePhotos['after'],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.title,
    required this.detail,
    required this.complete,
    required this.photoData,
  });

  final String title;
  final String detail;
  final bool complete;
  final String? photoData;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.warning;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EvidencePhotoViewer(
          photoData: photoData,
          complete: complete,
          title: title,
          size: 82,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: complete ? 'Photo visible' : 'Missing',
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupervisorProgress extends StatelessWidget {
  const _SupervisorProgress({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final beforeSaved = order.evidenceSlots.contains('before');
    final afterSaved = order.evidenceSlots.contains('after');
    final submitted = order.status == 'Submitted' || order.status == 'Approved';
    final approved = order.status == 'Approved';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProgressChip(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Accepted',
                  complete:
                      order.status != 'Assigned to Supervisor' ||
                      order.technicianLabel != null,
                ),
                _ProgressChip(
                  icon: Icons.person_outline,
                  label: 'Assigned',
                  complete: order.technicianLabel != null,
                ),
                _ProgressChip(
                  icon: Icons.qr_code_scanner,
                  label: 'Arrived',
                  complete: order.arrivalVerified,
                ),
                _ProgressChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Before',
                  complete: beforeSaved,
                ),
                _ProgressChip(
                  icon: Icons.photo_library_outlined,
                  label: 'After',
                  complete: afterSaved,
                ),
                _ProgressChip(
                  icon: Icons.done_all,
                  label: 'Submitted',
                  complete: submitted,
                ),
                _ProgressChip(
                  icon: Icons.verified_outlined,
                  label: 'Approved',
                  complete: approved,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _progressDetail,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  String get _progressDetail {
    if (order.status == 'Approved') return 'Job approved and completed.';
    if (order.status == 'Submitted') {
      return order.reviewed
          ? 'Technician submitted the job. Admin has reviewed it.'
          : 'Technician submitted the job. Waiting for admin review.';
    }
    if (order.evidenceSlots.contains('after')) {
      return 'After photo saved. Technician can submit the job.';
    }
    if (order.evidenceSlots.contains('before')) {
      return 'Before photo saved. Waiting for after photo.';
    }
    if (order.arrivalVerified) {
      return 'Arrival confirmed. Waiting for evidence upload.';
    }
    if (order.technicianLabel != null) {
      return 'Technician assigned. Waiting for arrival scan.';
    }
    return 'Accept the job, then assign a technician.';
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.icon,
    required this.label,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_outline : icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
