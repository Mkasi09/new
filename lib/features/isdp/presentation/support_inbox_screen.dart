import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/support/support_contact.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'widgets/common.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({
    super.key,
    required this.repository,
    required this.onClose,
  });

  final IsdpRepository repository;
  final VoidCallback onClose;

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  static const _pageSize = 50;

  final _scrollController = ScrollController();
  StreamSubscription<List<SupportMessage>>? _liveSubscription;
  List<SupportMessage>? _liveMessages;
  final List<SupportMessage> _olderMessages = [];
  Object? _loadError;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearBottom);
    _liveSubscription = widget.repository
        .watchSupportMessages(limit: _pageSize)
        .listen(_syncLiveMessages, onError: _setLoadError);
  }

  @override
  void dispose() {
    _markReadOnce();
    _scrollController
      ..removeListener(_loadMoreNearBottom)
      ..dispose();
    unawaited(_liveSubscription?.cancel());
    super.dispose();
  }

  void _syncLiveMessages(List<SupportMessage> messages) {
    final liveIds = messages.map((message) => message.id).toSet();
    setState(() {
      _loadError = null;
      _liveMessages = messages;
      _olderMessages.removeWhere((message) => liveIds.contains(message.id));
      if (messages.length < _pageSize && _olderMessages.isEmpty) {
        _hasMoreOlder = false;
      }
    });
  }

  void _setLoadError(Object error) {
    setState(() => _loadError = error);
  }

  void _loadMoreNearBottom() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 420) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _loadOlderMessages() async {
    final messages = _visibleMessages;
    if (_loadingOlder || !_hasMoreOlder || messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await widget.repository.fetchSupportMessages(
        limit: _pageSize,
        startAfterMessage: messages.last,
      );
      final knownIds = messages.map((message) => message.id).toSet();
      setState(() {
        _olderMessages.addAll(
          older.where((message) => !knownIds.contains(message.id)),
        );
        _hasMoreOlder = older.length == _pageSize;
        _loadError = null;
      });
    } catch (error) {
      setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  List<SupportMessage> get _visibleMessages => [
    ...?_liveMessages,
    ..._olderMessages,
  ];

  @override
  Widget build(BuildContext context) {
    final messages = _visibleMessages;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                _SupportInboxHeader(onClose: _closeInbox),
                const SizedBox(height: 14),
                Expanded(child: _buildInboxBody(messages)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInboxBody(List<SupportMessage> messages) {
    if (_loadError != null && _liveMessages == null) {
      return const SingleChildScrollView(
        child: _SupportInboxNotice(
          icon: Icons.error_outline,
          title: 'Could not load support messages',
          detail: supportContactMessage,
          action: 'Check the network connection, then reopen Support Inbox.',
        ),
      );
    }
    if (_liveMessages == null) return const _SupportInboxLoading();
    if (messages.isEmpty) {
      return const SingleChildScrollView(
        child: _SupportInboxNotice(
          icon: Icons.support_agent_outlined,
          title: 'No support messages',
          detail: 'Messages sent from Account > Support will appear here.',
          action: 'New requests will be labelled Via Support for admin review.',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return _SupportMessageCard(message: messages[index]);
        }
        return _SupportInboxFooter(
          loadedCount: messages.length,
          loading: _loadingOlder,
          hasMore: _hasMoreOlder,
          hasError: _loadError != null,
          onLoadMore: _loadOlderMessages,
        );
      },
    );
  }

  void _closeInbox() {
    _markReadOnce();
    widget.onClose();
  }

  void _markReadOnce() {
    if (_markedRead) return;
    _markedRead = true;
    unawaited(widget.repository.markSupportMessagesRead());
  }
}

class _SupportInboxHeader extends StatelessWidget {
  const _SupportInboxHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const IconPill(
              icon: Icons.support_agent_outlined,
              color: AppTheme.secondary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Inbox',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Messages sent via in-app support.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportMessageCard extends StatelessWidget {
  const _SupportMessageCard({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final sender = message.senderName.isEmpty ? 'ISDP User' : message.senderName;
    final senderMeta = [
      message.senderRole,
      if (message.senderEmail.isNotEmpty) message.senderEmail,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.12),
                child: Text(
                  sender.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _supportMessageTime(message.createdAt),
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      senderMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: message.sentViaSupport
                              ? 'Via Support'
                              : 'Admin Message',
                          color: AppTheme.secondary,
                        ),
                        if (message.status == 'new')
                          const StatusChip(
                            label: 'New',
                            color: AppTheme.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            message.message,
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
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

class _SupportInboxNotice extends StatelessWidget {
  const _SupportInboxNotice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: const TextStyle(color: AppTheme.muted)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 17,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            action,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

class _SupportInboxLoading extends StatelessWidget {
  const _SupportInboxLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loading support inbox',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Checking latest in-app support messages.',
                    style: TextStyle(color: AppTheme.muted),
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

class _SupportInboxFooter extends StatelessWidget {
  const _SupportInboxFooter({
    required this.loadedCount,
    required this.loading,
    required this.hasMore,
    required this.hasError,
    required this.onLoadMore,
  });

  final int loadedCount;
  final bool loading;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 10),
            Text(
              'Loading older messages...',
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (!hasMore && !hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Showing $loadedCount support messages',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: OutlinedButton.icon(
        onPressed: onLoadMore,
        icon: Icon(hasError ? Icons.refresh : Icons.expand_more),
        label: Text(hasError ? 'Retry loading messages' : 'Load older messages'),
      ),
    );
  }
}

String _supportMessageTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
