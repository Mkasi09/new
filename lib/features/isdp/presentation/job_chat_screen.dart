import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/support/support_contact.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'widgets/common.dart';

class JobChatScreen extends StatefulWidget {
  const JobChatScreen({
    super.key,
    required this.order,
    required this.repository,
    required this.userProfile,
    required this.onClose,
  });

  final WorkOrder order;
  final IsdpRepository repository;
  final AppUserProfile? userProfile;
  final VoidCallback onClose;

  @override
  State<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends State<JobChatScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.repository.markJobChatRead(widget.order.id));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onClose,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Job Chat'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              children: [
                _JobChatHeader(order: widget.order),
                Expanded(
                  child: StreamBuilder<List<JobChatMessage>>(
                    stream: widget.repository.watchJobMessages(widget.order.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _ChatNotice(
                          icon: Icons.error_outline,
                          title: 'Could not load messages',
                          detail: supportContactMessage,
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages = snapshot.data ?? const [];
                      if (messages.isNotEmpty) {
                        unawaited(
                          widget.repository.markJobChatRead(widget.order.id),
                        );
                      }
                      if (messages.isEmpty) {
                        return const _ChatNotice(
                          icon: Icons.forum_outlined,
                          title: 'No messages yet',
                          detail: 'Start the job conversation here.',
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          return _MessageBubble(
                            message: message,
                            mine:
                                message.senderId ==
                                widget.userProfile?.uid.trim(),
                          );
                        },
                      );
                    },
                  ),
                ),
                _MessageComposer(
                  controller: _messageController,
                  sending: _sending,
                  onSend: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendJobMessage(
        workOrderId: widget.order.id,
        message: text,
        senderName: widget.userProfile?.name ?? 'ISDP User',
        senderRole: widget.userProfile?.role.label ?? 'User',
      );
      _messageController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send message. $supportContactMessage'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _JobChatHeader extends StatelessWidget {
  const _JobChatHeader({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          children: [
            IconPill(
              icon: Icons.chat_bubble_outline,
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
                  Text(order.id, style: const TextStyle(color: AppTheme.muted)),
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
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final JobChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppTheme.primary : const Color(0xFFEFF4F8);
    final textColor = mine ? Colors.white : AppTheme.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: mine ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.senderName.isEmpty
                        ? 'ISDP User'
                        : message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _messageTime(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(message.message, style: TextStyle(color: textColor)),
            const SizedBox(height: 5),
            Text(
              message.senderRole,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message this job',
                  prefixIcon: Icon(Icons.chat_outlined),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 52,
              child: FilledButton(
                onPressed: sending ? null : onSend,
                child: Icon(sending ? Icons.hourglass_empty : Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.muted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _messageTime(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  final sameDay =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (sameDay) return '$hour:$minute';
  return '${local.day}/${local.month} $hour:$minute';
}
