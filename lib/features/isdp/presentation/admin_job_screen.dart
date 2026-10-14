import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/evidence_photo_thumbnail.dart';

Future<void> launchLocationInMaps(double latitude, double longitude) async {
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
  await launchUrl(uri, mode: LaunchMode.platformDefault);
}

class AdminJobScreen extends StatelessWidget {
  const AdminJobScreen({
    super.key,
    required this.order,
    required this.onReview,
    required this.onOpenChat,
    required this.unreadChatStream,
    required this.onDelete,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onReview;
  final VoidCallback onOpenChat;
  final Stream<int> unreadChatStream;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasBefore = order.evidenceSlots.contains('before');
    final hasAfter = order.evidenceSlots.contains('after');

    return AppScrollView(
      children: [
        JobDetailHeader(
          title: 'Job Details',
          order: order,
          onBack: onClose,
          trailing: PopupMenuButton<_AdminJobOption>(
            tooltip: 'Options',
            onSelected: (option) {
              switch (option) {
                case _AdminJobOption.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AdminJobOption.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Delete job'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        JobOverviewPanel(order: order),
        const SizedBox(height: 14),
        _AdminActionPanel(
          onOpenChat: onOpenChat,
          unreadChatStream: unreadChatStream,
          onReview: order.status == 'Submitted' ? onReview : null,
        ),
        const SizedBox(height: 14),
        WorkDurationPanel(order: order),
        const SizedBox(height: 14),
        _JobLocationPanel(order: order),
        const SizedBox(height: 14),
        const SectionTitle('Evidence'),
        const SizedBox(height: 10),
        _AdminEvidenceCard(
          title: 'Before photo',
          detail: 'Photo captured before work started.',
          complete: hasBefore,
          photoData: order.evidencePhotos['before'],
        ),
        _AdminEvidenceCard(
          title: 'After photo',
          detail: 'Photo captured after work was completed.',
          complete: hasAfter,
          photoData: order.evidencePhotos['after'],
        ),
      ],
    );
  }
}

enum _AdminJobOption { delete }

class _AdminActionPanel extends StatelessWidget {
  const _AdminActionPanel({
    required this.onOpenChat,
    required this.unreadChatStream,
    this.onReview,
  });

  final VoidCallback onOpenChat;
  final Stream<int> unreadChatStream;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final chatButton = OutlinedButton.icon(
              onPressed: onOpenChat,
              icon: const Icon(Icons.forum_outlined),
              label: _UnreadChatLabel(stream: unreadChatStream),
            );
            final reviewButton = FilledButton.icon(
              onPressed: onReview,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review Job'),
            );

            final buttons = [chatButton, if (onReview != null) reviewButton];

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    buttons[index],
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: chatButton),
                const SizedBox(width: 10),
                if (onReview != null) Expanded(child: reviewButton),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _JobLocationPanel extends StatelessWidget {
  const _JobLocationPanel({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Job Location History'),
            const SizedBox(height: 10),
            _LocationEntry(
              label: 'Accepted by technician',
              timestamp: order.arrivedAt,
              latitude: order.arrivalLatitude,
              longitude: order.arrivalLongitude,
            ),
            const Divider(height: 20),
            _LocationEntry(
              label: 'Submitted for approval',
              timestamp: order.submittedAt,
              latitude: order.submissionLatitude,
              longitude: order.submissionLongitude,
            ),
            const Divider(height: 20),
            _LocationEntry(
              label: 'Job closed',
              timestamp: order.closedAt,
              latitude: order.closureLatitude,
              longitude: order.closureLongitude,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationEntry extends StatelessWidget {
  const _LocationEntry({
    required this.label,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final DateTime? timestamp;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = latitude != null && longitude != null;
    final timeText = timestamp == null ? 'Not recorded' : timestamp!.toLocal().toString();
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(timeText, style: const TextStyle(color: AppTheme.muted)),
              if (hasCoordinates)
                Text(
                  '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        if (hasCoordinates)
          IconButton(
            tooltip: 'Open in Google Maps',
            onPressed: () => launchLocationInMaps(latitude!, longitude!),
            icon: const Icon(Icons.map_outlined),
          ),
      ],
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

class _AdminEvidenceCard extends StatelessWidget {
  const _AdminEvidenceCard({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EvidencePhotoViewer(
                photoData: photoData,
                complete: complete,
                title: title,
                size: 92,
              ),
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
          ),
        ),
      ),
    );
  }
}
