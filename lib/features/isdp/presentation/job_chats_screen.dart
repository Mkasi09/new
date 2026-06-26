import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'widgets/common.dart';

class JobChatsScreen extends StatelessWidget {
  const JobChatsScreen({
    super.key,
    required this.orders,
    required this.repository,
    required this.onOpenChat,
    required this.onClose,
  });

  final List<WorkOrder> orders;
  final IsdpRepository repository;
  final ValueChanged<WorkOrder> onOpenChat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final activeOrders =
        orders.where((order) => order.status != 'Approved').toList()
          ..sort(_compareChatActivity);

    return AppScrollView(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SectionTitle('Job Chats')),
            _UnreadTotalBadge(repository: repository, orders: activeOrders),
          ],
        ),
        const SizedBox(height: 12),
        if (activeOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No active jobs have chats yet.'),
            ),
          )
        else
          ...activeOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconPill(
                            icon: Icons.forum_outlined,
                            color: workOrderStatusColor(order.status),
                          ),
                          const SizedBox(width: 12),
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
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _chatDetail(order),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _UnreadJobBadge(repository: repository, order: order),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: order.status,
                            color: workOrderStatusColor(order.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => onOpenChat(order),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: _UnreadOpenChatLabel(
                            repository: repository,
                            order: order,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

int _compareChatActivity(WorkOrder a, WorkOrder b) {
  final aTime = a.lastMessageAt;
  final bTime = b.lastMessageAt;
  if (aTime != null && bTime != null) return bTime.compareTo(aTime);
  if (aTime != null) return -1;
  if (bTime != null) return 1;
  return a.site.toLowerCase().compareTo(b.site.toLowerCase());
}

String _chatDetail(WorkOrder order) {
  final message = order.lastMessage?.trim();
  if (message?.isNotEmpty == true) {
    final sender = order.lastMessageBy?.trim();
    return sender?.isNotEmpty == true ? '$sender: $message' : message!;
  }
  return '${order.id} - ${order.scope}';
}

class _UnreadTotalBadge extends StatelessWidget {
  const _UnreadTotalBadge({required this.repository, required this.orders});

  final IsdpRepository repository;
  final List<WorkOrder> orders;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: repository.watchUnreadJobMessageTotal(
        orders.map((order) => order.id).toList(),
      ),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unread'),
            const SizedBox(width: 6),
            UnreadCountBadge(count: count),
          ],
        );
      },
    );
  }
}

class _UnreadJobBadge extends StatelessWidget {
  const _UnreadJobBadge({required this.repository, required this.order});

  final IsdpRepository repository;
  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: repository.watchUnreadJobMessageCount(order.id),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return UnreadCountBadge(count: count);
      },
    );
  }
}

class _UnreadOpenChatLabel extends StatelessWidget {
  const _UnreadOpenChatLabel({required this.repository, required this.order});

  final IsdpRepository repository;
  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: repository.watchUnreadJobMessageCount(order.id),
      initialData: 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const Text('Open Chat');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Open Chat'),
            const SizedBox(width: 8),
            UnreadCountBadge(count: count),
          ],
        );
      },
    );
  }
}
