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
    final chatOrders =
        orders.where((order) => order.status != 'Closed').toList()
          ..sort(_compareChatActivity);
    final activeOrders = chatOrders
        .where((order) => order.status != 'Approved')
        .toList();
    final approvedOrders = chatOrders
        .where((order) => order.status == 'Approved')
        .toList();

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
            _UnreadTotalBadge(repository: repository, orders: chatOrders),
          ],
        ),
        const SizedBox(height: 12),
        if (activeOrders.isEmpty && approvedOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No active jobs have chats yet.'),
            ),
          )
        else ...[
          ...activeOrders.map(
            (order) => _ChatOrderCard(
              order: order,
              repository: repository,
              onOpenChat: onOpenChat,
            ),
          ),
          ...approvedOrders.map(
            (order) => _UnreadApprovedChat(
              order: order,
              repository: repository,
              onOpenChat: onOpenChat,
            ),
          ),
        ],
      ],
    );
  }
}

class _UnreadApprovedChat extends StatelessWidget {
  const _UnreadApprovedChat({
    required this.order,
    required this.repository,
    required this.onOpenChat,
  });

  final WorkOrder order;
  final IsdpRepository repository;
  final ValueChanged<WorkOrder> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: repository.watchUnreadJobMessageCount(order.id),
      builder: (context, snapshot) {
        if ((snapshot.data ?? 0) == 0) return const SizedBox.shrink();
        return _ChatOrderCard(
          order: order,
          repository: repository,
          onOpenChat: onOpenChat,
        );
      },
    );
  }
}

class _ChatOrderCard extends StatelessWidget {
  const _ChatOrderCard({
    required this.order,
    required this.repository,
    required this.onOpenChat,
  });

  final WorkOrder order;
  final IsdpRepository repository;
  final ValueChanged<WorkOrder> onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                          style: const TextStyle(fontWeight: FontWeight.w900),
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
                  label: const Text('Open Chat'),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _UnreadTotalBadge extends StatefulWidget {
  const _UnreadTotalBadge({required this.repository, required this.orders});

  final IsdpRepository repository;
  final List<WorkOrder> orders;

  @override
  State<_UnreadTotalBadge> createState() => _UnreadTotalBadgeState();
}

class _UnreadTotalBadgeState extends State<_UnreadTotalBadge> {
  late Stream<int> _stream;
  late List<String> _ids;

  @override
  void initState() {
    super.initState();
    _ids = _orderIds(widget.orders);
    _stream = widget.repository.watchUnreadJobMessageTotal(_ids);
  }

  @override
  void didUpdateWidget(covariant _UnreadTotalBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _orderIds(widget.orders);
    if (_sameIds(ids, _ids)) return;
    _ids = ids;
    _stream = widget.repository.watchUnreadJobMessageTotal(_ids);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return _UnreadMessageChip(count: count, compact: false);
      },
    );
  }
}

class _UnreadJobBadge extends StatefulWidget {
  const _UnreadJobBadge({required this.repository, required this.order});

  final IsdpRepository repository;
  final WorkOrder order;

  @override
  State<_UnreadJobBadge> createState() => _UnreadJobBadgeState();
}

class _UnreadJobBadgeState extends State<_UnreadJobBadge> {
  late Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchUnreadJobMessageCount(widget.order.id);
  }

  @override
  void didUpdateWidget(covariant _UnreadJobBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id == widget.order.id) return;
    _stream = widget.repository.watchUnreadJobMessageCount(widget.order.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return _UnreadMessageChip(count: count);
      },
    );
  }
}

List<String> _orderIds(List<WorkOrder> orders) =>
    orders.map((order) => order.id).toList();

bool _sameIds(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

class _UnreadMessageChip extends StatelessWidget {
  const _UnreadMessageChip({required this.count, this.compact = true});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: compact ? 14 : 16,
            color: AppTheme.danger,
          ),
          const SizedBox(width: 5),
          Text(
            compact ? label : '$label unread',
            style: TextStyle(
              color: AppTheme.danger,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
