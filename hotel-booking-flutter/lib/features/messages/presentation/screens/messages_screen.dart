import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/source_animations.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/conversations_repository.dart';

/// Complete port of `Source goc/frontend/src/views/pages/Messages/MessagesPage.tsx` and `Host/TinNhan/index.tsx`.
class MessagesScreen extends ConsumerStatefulWidget {
  final String? initialConversationId;
  final bool isHostPortal;

  const MessagesScreen({
    super.key,
    this.initialConversationId,
    this.isHostPortal = false,
  });

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String? _selectedConversationId;
  List<ChatMessageItem> _messages = const [];
  final Map<String, ConversationItem> _conversationOverrides = {};
  bool _isLoadingMessages = false;
  bool _isSending = false;
  final TextEditingController _inputCtrl = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    _selectedConversationId = widget.initialConversationId;
    final socket = ref.read(socketServiceProvider);
    socket.connect();
    _socketSub = socket.onMessageNew.listen(_onSocketMessage);
    _reconnectSub = socket.onConnected.listen((_) => _onSocketReconnected());
    if (_selectedConversationId != null &&
        _selectedConversationId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectConversation(_selectedConversationId!);
        }
      });
    }
  }

  void _onSocketReconnected() {
    if (!mounted) return;
    ref.invalidate(conversationsListProvider);
    final activeId = _selectedConversationId;
    if (activeId != null && activeId.isNotEmpty) {
      _refreshActiveConversationMessages(activeId);
    }
  }

  Future<void> _refreshActiveConversationMessages(String conversationId) async {
    try {
      final msgs = await ref
          .read(conversationsRepositoryProvider)
          .getMessages(conversationId);
      if (!mounted || _selectedConversationId != conversationId) return;
      setState(() {
        _messages = ChatMessageItem.mergeAndSortMessages(
          _messages,
          msgs,
          conversationId: conversationId,
        );
      });
    } catch (_) {
      // Keep existing messages on background refresh failure
    }
  }

  void _onSocketMessage(Map<String, dynamic> payload) {
    if (!mounted) return;
    final envelope = SocketMessageEnvelope.fromJson(payload);
    final msg = envelope.message;
    if (msg == null || msg.id.isEmpty) return;

    final convId = envelope.conversationId.isNotEmpty
        ? envelope.conversationId
        : msg.conversationId;
    if (convId.isEmpty) return;

    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    final isSelectedConv = convId == _selectedConversationId;

    setState(() {
      if (isSelectedConv) {
        _messages = ChatMessageItem.mergeAndSortMessages(
          _messages,
          [msg],
          conversationId: convId,
        );
      }

      final baseList =
          ref.read(conversationsListProvider).valueOrNull ?? const [];
      final existingConv = _conversationOverrides[convId] ??
          baseList.where((c) => c.id == convId).firstOrNull;
      if (existingConv != null) {
        final nextUnread = isSelectedConv
            ? 0
            : (msg.senderId.isNotEmpty && msg.senderId != currentUserId
                ? existingConv.unreadCount + 1
                : existingConv.unreadCount);
        _conversationOverrides[convId] = existingConv.copyWith(
          lastMessage: msg.content,
          lastMessageAt: msg.createdAt,
          updatedAt: msg.createdAt,
          unreadCount: nextUnread,
        );
      }
    });

    if (isSelectedConv &&
        msg.senderId.isNotEmpty &&
        msg.senderId != currentUserId) {
      _markReadQuietly(convId);
    }
    ref.invalidate(conversationsListProvider);
  }

  Future<void> _markReadQuietly(String conversationId) async {
    try {
      final res = await ref
          .read(conversationsRepositoryProvider)
          .markConversationRead(conversationId);
      if (!mounted) return;
      final baseList =
          ref.read(conversationsListProvider).valueOrNull ?? const [];
      final existing = _conversationOverrides[conversationId] ??
          baseList.where((c) => c.id == conversationId).firstOrNull;
      if (existing != null) {
        setState(() {
          _conversationOverrides[conversationId] = existing.copyWith(
            unreadCount: res.unreadCount,
          );
        });
      }
      ref.invalidate(conversationsListProvider);
    } catch (_) {
      // Non-fatal if read receipt fails
    }
  }

  Future<void> _selectConversation(String conversationId) async {
    if (!mounted || conversationId.isEmpty) return;
    final socket = ref.read(socketServiceProvider);
    if (_selectedConversationId != null &&
        _selectedConversationId != conversationId) {
      socket.leaveConversation(_selectedConversationId!);
    }
    setState(() {
      _selectedConversationId = conversationId;
      _isLoadingMessages = true;
    });
    socket.joinConversation(conversationId);
    try {
      final msgs = await ref
          .read(conversationsRepositoryProvider)
          .getMessages(conversationId);
      if (!mounted || _selectedConversationId != conversationId) return;
      setState(() {
        _messages = ChatMessageItem.mergeAndSortMessages(
          const [],
          msgs,
          conversationId: conversationId,
        );
        _isLoadingMessages = false;
      });
      await _markReadQuietly(conversationId);
    } catch (_) {
      if (!mounted || _selectedConversationId != conversationId) return;
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final convId = _selectedConversationId;
    final text = _inputCtrl.text.trim();
    if (convId == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _inputCtrl.clear();

    try {
      final sent = await ref.read(conversationsRepositoryProvider).sendMessage(
            conversationId: convId,
            content: text,
          );
      if (!mounted) return;
      setState(() {
        if (_selectedConversationId == convId) {
          _messages = ChatMessageItem.mergeAndSortMessages(
            _messages,
            [sent],
            conversationId: convId,
          );
        }
        final baseList =
            ref.read(conversationsListProvider).valueOrNull ?? const [];
        final existing = _conversationOverrides[convId] ??
            baseList.where((c) => c.id == convId).firstOrNull;
        if (existing != null) {
          _conversationOverrides[convId] = existing.copyWith(
            lastMessage: sent.content,
            lastMessageAt: sent.createdAt,
            updatedAt: sent.createdAt,
            unreadCount: 0,
          );
        }
        _isSending = false;
      });
      ref.invalidate(conversationsListProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  List<ConversationItem> _effectiveConversations(
    List<ConversationItem> rawList,
  ) {
    final merged = rawList.map((item) {
      final override = _conversationOverrides[item.id];
      if (override == null) return item;
      return item.copyWith(
        lastMessage: override.lastMessage ?? item.lastMessage,
        lastMessageAt: override.lastMessageAt ?? item.lastMessageAt,
        updatedAt: override.updatedAt ?? item.updatedAt,
        unreadCount: override.unreadCount,
        otherParticipantName:
            item.otherParticipantName ?? override.otherParticipantName,
        otherParticipantAvatar:
            item.otherParticipantAvatar ?? override.otherParticipantAvatar,
      );
    }).toList();

    merged.sort((a, b) {
      final tA = DateTime.tryParse(a.lastMessageAt ?? a.updatedAt ?? '');
      final tB = DateTime.tryParse(b.lastMessageAt ?? b.updatedAt ?? '');
      if (tA != null && tB != null) {
        return tB.compareTo(tA);
      }
      return 0;
    });
    return merged;
  }

  String _formatTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw.trim())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
    }
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  @override
  void dispose() {
    if (_selectedConversationId != null) {
      ref
          .read(socketServiceProvider)
          .leaveConversation(_selectedConversationId!);
    }
    _socketSub?.cancel();
    _reconnectSub?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (!widget.isHostPortal)
              const AppTopHeader(currentPath: '/messages'),
            Expanded(
              child: AppEmptyView(
                icon: LucideIcons.messageSquare,
                title: 'Đăng nhập để xem tin nhắn',
                description:
                    'Trao đổi trực tiếp với Chủ nhà Vũng Tàu về lịch phòng, tiện nghi và ưu đãi.',
                actionText: 'Đăng nhập ngay',
                onAction: () => context.push('/dang-nhap'),
              ),
            ),
          ],
        ),
      );
    }

    final convsAsync = ref.watch(conversationsListProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSplitView = screenWidth >= 780;

    final bodyContent = convsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => AppErrorView(
        message: err.toString(),
        onRetry: () => ref.invalidate(conversationsListProvider),
      ),
      data: (rawConversations) {
        final conversations = _effectiveConversations(rawConversations);
        if (conversations.isEmpty) {
          return AppEmptyView(
            icon: LucideIcons.messageSquare,
            title: 'Chưa có cuộc trò chuyện nào',
            description:
                'Hãy chọn một biệt thự và bấm "Nhắn tin cho Chủ nhà" để bắt đầu trò chuyện.',
            actionText: 'Khám phá biệt thự',
            onAction: () => context.push('/search'),
          );
        }

        // Auto-select first conversation on desktop split view
        if (isSplitView &&
            _selectedConversationId == null &&
            conversations.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedConversationId == null) {
              _selectConversation(conversations.first.id);
            }
          });
        }

        final activeConv = conversations
            .where((c) => c.id == _selectedConversationId)
            .firstOrNull;

        if (isSplitView) {
          return Row(
            children: [
              SizedBox(
                width: 340,
                child: _buildConversationList(conversations, user.id),
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(
                child: activeConv == null
                    ? const Center(
                        child: Text('Chọn một hội thoại để xem tin nhắn'),
                      )
                    : _buildChatPane(
                        activeConv,
                        user.id,
                        showBackButton: false,
                      ),
              ),
            ],
          );
        }

        // Mobile view: show either conversation list OR active chat pane
        if (activeConv != null) {
          return _buildChatPane(activeConv, user.id, showBackButton: true);
        }
        return _buildConversationList(conversations, user.id);
      },
    );

    if (widget.isHostPortal) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/messages'),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar(String name, String? avatarUrl) {
    final trimmedUrl = avatarUrl?.trim() ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    if (trimmedUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: AppImage(url: trimmedUrl),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildConversationList(
    List<ConversationItem> conversations,
    String currentUserId,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Hộp thư tin nhắn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final isSelected = conv.id == _selectedConversationId;
                final counterpart = conv.displayNameFor(currentUserId);
                final timeLabel =
                    _formatTimestamp(conv.lastMessageAt ?? conv.updatedAt);
                final previewText = (conv.lastMessage != null &&
                        conv.lastMessage!.trim().isNotEmpty)
                    ? conv.lastMessage!.trim()
                    : 'Chưa có tin nhắn.';

                return InkWell(
                  onTap: () => _selectConversation(conv.id),
                  child: Container(
                    color:
                        isSelected ? AppColors.surfaceWarmSand : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParticipantAvatar(
                          counterpart,
                          conv.displayAvatar,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      counterpart,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: conv.unreadCount > 0
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (timeLabel.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      timeLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                conv.listingTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      previewText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: conv.unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: conv.unreadCount > 0
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (conv.unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${conv.unreadCount}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPane(
    ConversationItem conv,
    String currentUserId, {
    required bool showBackButton,
  }) {
    final counterpart = conv.displayNameFor(currentUserId);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: () =>
                      setState(() => _selectedConversationId = null),
                  tooltip: 'Quay lại danh sách',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    size: 20,
                    color: AppColors.iconStrong,
                  ),
                ),
              _buildParticipantAvatar(counterpart, conv.displayAvatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counterpart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      conv.listingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (conv.listingId.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/villa/${conv.listingId}'),
                  child: const Text('Xem chỗ nghỉ'),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Hãy gửi tin nhắn đầu tiên để bắt đầu trao đổi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderId == currentUserId;
                        final timeLabel = _formatTimestamp(msg.createdAt);
                        return FadeSlideIn(
                          key: ValueKey<String>('msg_${msg.id}'),
                          duration: const Duration(milliseconds: 180),
                          beginOffset: const Offset(0, 8),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 420),
                              decoration: BoxDecoration(
                                color:
                                    isMe ? AppColors.textPrimary : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: isMe
                                    ? null
                                    : Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (timeLabel.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe
                                            ? Colors.white70
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập nội dung tin nhắn...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon: const Icon(
                  LucideIcons.send,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text('Gửi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(84, 48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Complete port of `Source goc/frontend/src/views/pages/HostMessage/HostMessagePage.tsx` (`/villa/:villaId/nhan-tin-host`).
class HostMessageScreen extends ConsumerStatefulWidget {
  final String villaId;

  const HostMessageScreen({
    super.key,
    required this.villaId,
  });

  @override
  ConsumerState<HostMessageScreen> createState() => _HostMessageScreenState();
}

class _HostMessageScreenState extends ConsumerState<HostMessageScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isSending = false;

  static const List<String> _quickQuestions = [
    'Chào Chủ nhà, biệt thự còn trống lịch cuối tuần này không ạ?',
    'Hồ bơi của biệt thự là nước ngọt hay nước mặn và có phao bơi không ạ?',
    'Biệt thự có sẵn lò nướng BBQ, than và dụng cụ bếp đầy đủ không ạ?',
    'Đoàn mình muốn nhận phòng sớm hơn 14:00 có được hỗ trợ không ạ?',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _startConversationAndSend() async {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) {
      await context.push('/dang-nhap');
      return;
    }

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(conversationsRepositoryProvider);
      final conv = await repo.getOrCreateConversation(widget.villaId);
      await repo.sendMessage(conversationId: conv.id, content: text);
      ref.invalidate(conversationsListProvider);
      if (!mounted) return;
      setState(() => _isSending = false);
      context.go('/messages?conversationId=${conv.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final villaAsync = ref.watch(villaDetailProvider(widget.villaId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppTopHeader(currentPath: '/messages'),
          Expanded(
            child: villaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => AppErrorView(message: err.toString()),
              data: (villa) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  context.go('/villa/${widget.villaId}'),
                              icon: const Icon(
                                LucideIcons.arrowLeft,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
                              label: const Text('Quay lại trang biệt thự'),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Liên hệ Chủ nhà',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (villa != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 72,
                                        height: 56,
                                        child: AppImage(
                                          url: villa.imageUrls.isNotEmpty
                                              ? villa.imageUrls.first
                                              : 'assets/images/NDT05929-HDR1.jpg',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            villa.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Chủ nhà: ${villa.host?.fullName ?? 'Chủ nhà VungTau Stay'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text(
                              'Câu hỏi thường gặp cho Chủ nhà:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _quickQuestions.map((q) {
                                return ActionChip(
                                  label: Text(
                                    q,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    setState(() => _msgCtrl.text = q);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _msgCtrl,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Nội dung tin nhắn gửi Chủ nhà *',
                                hintText:
                                    'Nhập câu hỏi của bạn về lịch trống, tiện nghi hoặc yêu cầu đặc biệt...',
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSending
                                    ? null
                                    : _startConversationAndSend,
                                icon: const Icon(
                                  LucideIcons.send,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _isSending
                                      ? 'Đang gửi tin nhắn...'
                                      : 'Gửi tin nhắn & Mở phòng chat',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
