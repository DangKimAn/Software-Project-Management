import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/animations/source_animations.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_header_footer.dart';
import '../../../../shared/widgets/app_image.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/conversations_repository.dart';

enum _ChatPortalRole { guest, host, admin }

/// Unified Messenger-style chat screen shared across Guest (`/messages`, `/tin-nhan`),
/// Host (`isHostPortal: true`), and Admin (`isAdminPortal: true` / `/admin/tin-nhan`).
class MessagesScreen extends ConsumerStatefulWidget {
  final String? initialConversationId;
  final bool isHostPortal;
  final bool isAdminPortal;

  const MessagesScreen({
    super.key,
    this.initialConversationId,
    this.isHostPortal = false,
    this.isAdminPortal = false,
  });

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const List<String> _messengerReactions = [
    '❤️',
    '😆',
    '😮',
    '😢',
    '😡',
    '👍',
  ];

  static const List<String> _guestQuickReplies = [
    'Dạ căn còn trống lịch này không ạ?',
    'Cho mình hỏi giờ nhận và trả phòng ạ?',
    'Biệt thự có sẵn bếp BBQ và hồ bơi riêng không ạ?',
    'Cảm ơn Chủ nhà nhiều ạ!',
  ];

  static const List<String> _hostQuickReplies = [
    'Dạ vâng, bên em đã nhận thông tin ạ!',
    'Quý khách nhận phòng lúc mấy giờ ạ?',
    'The Palm Villa xin chào bạn! 🌴',
    'Vị trí biệt thự em đã cập nhật trên hệ thống ạ.',
  ];

  static const List<String> _adminQuickReplies = [
    'Chào bạn, Quản trị viên hệ thống hỗ trợ bạn vấn đề gì ạ?',
    'Hệ thống đã tiếp nhận thông tin và đang kiểm tra ạ.',
    'Hồ sơ/bài đăng của bạn đã được cập nhật trạng thái.',
    'Cảm ơn bạn đã phản hồi cho Ban quản trị!',
  ];

  String? _selectedConversationId;
  String? _activeUserId;

  final Map<String, List<ChatMessageItem>> _messagesByConversation = {};
  final Map<String, PaginationMeta> _paginationByConversation = {};
  final Map<String, AppFailure> _messagesErrorByConversation = {};
  final Map<String, bool> _loadingMessagesByConversation = {};
  final Map<String, bool> _loadingHistoryByConversation = {};
  final Map<String, String> _draftsByConversation = {};
  final Map<String, double> _scrollOffsetByConversation = {};
  final Map<String, int> _unreadBelowByConversation = {};
  final Map<String, String> _typingUserByConversation = {};
  final Map<String, Timer> _typingTimers = {};
  final Map<String, DateTime> _lastTypingSentAt = {};
  final Map<String, ConversationItem> _conversationOverrides = {};
  final Map<String, String> _messageReactions = {};
  final Set<String> _expandedTimestampKeys = {};

  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late final AnimationController _timestampDragCtrl;
  double _horizontalDragOffset = 0.0;
  bool _showTimestampsPinned = false;
  String? _reactionActiveMsgKey;
  bool _isRecordingVoice = false;
  int _voiceRecordingSeconds = 0;
  Timer? _voiceTimer;
  String _chatQuickEmoji = '👍';

  bool _isSwitchingConversation = false;
  bool _isUserNearBottom = true;
  int _localMessageSequence = 0;

  bool get _isEmbeddedPortal => widget.isHostPortal || widget.isAdminPortal;

  late final SocketService _socket;
  StreamSubscription<Map<String, dynamic>>? _socketMessageSub;
  StreamSubscription<Map<String, dynamic>>? _socketErrorSub;
  StreamSubscription<Map<String, dynamic>>? _socketTypingSub;
  StreamSubscription<void>? _reconnectSub;

  List<ChatMessageItem> get _activeMessages {
    final id = _selectedConversationId;
    if (id == null || id.isEmpty) return const [];
    return _messagesByConversation[id] ?? const [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timestampDragCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _selectedConversationId = widget.initialConversationId?.trim();
    _inputCtrl.addListener(_onInputChanged);
    _scrollController.addListener(_onScrollChanged);

    _socket = ref.read(socketServiceProvider);
    unawaited(_socket.connect());
    _socketMessageSub = _socket.onMessageNew.listen(_onSocketMessage);
    _socketErrorSub = _socket.onConversationError.listen(_onSocketError);
    _socketTypingSub = _socket.onTyping.listen(_onSocketTyping);
    _reconnectSub = _socket.onConnected.listen((_) => _onSocketReconnected());

    if (_selectedConversationId != null &&
        _selectedConversationId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedConversationId != null) {
          _selectConversation(_selectedConversationId!);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextConvId = widget.initialConversationId?.trim();
    final prevConvId = oldWidget.initialConversationId?.trim();
    if (nextConvId != prevConvId &&
        nextConvId != null &&
        nextConvId.isNotEmpty &&
        _selectedConversationId != nextConvId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectConversation(nextConvId);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(authNotifierProvider).valueOrNull;
      if (user != null) {
        unawaited(ref.read(socketServiceProvider).connect());
        _onSocketReconnected();
      }
    }
  }

  void _onInputChanged() {
    if (_isSwitchingConversation) return;
    final convId = _selectedConversationId;
    if (convId == null || convId.isEmpty) return;
    final currentText = _inputCtrl.text;
    if (currentText.isEmpty) {
      _draftsByConversation.remove(convId);
    } else {
      _draftsByConversation[convId] = currentText;
      _maybeEmitTyping(convId);
    }
  }

  void _maybeEmitTyping(String conversationId) {
    final now = DateTime.now();
    final lastSent = _lastTypingSentAt[conversationId];
    if (lastSent != null &&
        now.difference(lastSent) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSentAt[conversationId] = now;
    ref.read(socketServiceProvider).sendTyping(conversationId, isTyping: true);
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nearBottom = (pos.maxScrollExtent - pos.pixels) <= 120.0;
    final convId = _selectedConversationId;
    if (convId != null && convId.isNotEmpty) {
      _scrollOffsetByConversation[convId] = pos.pixels;
      if (nearBottom && (_unreadBelowByConversation[convId] ?? 0) > 0) {
        setState(() {
          _unreadBelowByConversation[convId] = 0;
        });
      }
    }
    _isUserNearBottom = nearBottom;
  }

  bool get _checkIsNearBottom {
    if (!_scrollController.hasClients) return _isUserNearBottom;
    final pos = _scrollController.position;
    return (pos.maxScrollExtent - pos.pixels) <= 120.0;
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (animate && !disableAnimations) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
      _isUserNearBottom = true;
      final convId = _selectedConversationId;
      if (convId != null) {
        _scrollOffsetByConversation[convId] = target;
        _unreadBelowByConversation[convId] = 0;
      }
    });
  }

  void _restoreOrInitScrollForConversation(
    String conversationId, {
    required bool hadSavedOffset,
    double? savedOffset,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _selectedConversationId != conversationId ||
          !_scrollController.hasClients) {
        return;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (hadSavedOffset && savedOffset != null) {
        final clamped = savedOffset.clamp(0.0, maxExtent);
        _scrollController.jumpTo(clamped);
        _isUserNearBottom = (maxExtent - clamped) <= 120.0;
      } else {
        _scrollController.jumpTo(maxExtent);
        _isUserNearBottom = true;
        _scrollOffsetByConversation[conversationId] = maxExtent;
      }
    });
  }

  void _clearStateForSessionChange() {
    final socket = ref.read(socketServiceProvider);
    if (_selectedConversationId != null &&
        _selectedConversationId!.isNotEmpty) {
      socket.leaveConversation(_selectedConversationId!);
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingUserByConversation.clear();
    _messagesByConversation.clear();
    _paginationByConversation.clear();
    _messagesErrorByConversation.clear();
    _loadingMessagesByConversation.clear();
    _loadingHistoryByConversation.clear();
    _draftsByConversation.clear();
    _scrollOffsetByConversation.clear();
    _unreadBelowByConversation.clear();
    _conversationOverrides.clear();
    _messageReactions.clear();
    _expandedTimestampKeys.clear();
    _reactionActiveMsgKey = null;
    _voiceTimer?.cancel();
    _isRecordingVoice = false;
    _voiceRecordingSeconds = 0;
    _isSwitchingConversation = true;
    _inputCtrl.clear();
    _isSwitchingConversation = false;
    _selectedConversationId = null;
  }

  void _onSocketReconnected() {
    if (!mounted) return;
    ref.invalidate(conversationsListProvider);
    final activeId = _selectedConversationId;
    if (activeId != null && activeId.isNotEmpty) {
      unawaited(_refreshActiveConversationMessages(activeId));
    }
  }

  Future<void> _refreshActiveConversationMessages(String conversationId) async {
    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    if (!_isAuthorizedToAccessConversation(conversationId, currentUserId)) {
      return;
    }

    try {
      final result = await ref
          .read(conversationsRepositoryProvider)
          .getMessagesPaginated(conversationId);
      if (!mounted) return;
      final wasNearBottom =
          _selectedConversationId == conversationId && _checkIsNearBottom;
      setState(() {
        final existing = _messagesByConversation[conversationId] ?? const [];
        _messagesByConversation[conversationId] =
            ChatMessageItem.mergeAndSortMessages(
          existing,
          result.items,
          conversationId: conversationId,
        );
        final prevMeta = _paginationByConversation[conversationId];
        if (prevMeta == null || result.pagination.page >= prevMeta.page) {
          _paginationByConversation[conversationId] = result.pagination;
        }
        _messagesErrorByConversation.remove(conversationId);
      });
      if (_selectedConversationId == conversationId && wasNearBottom) {
        _scrollToBottom(animate: false);
      }
    } catch (_) {
      // Preserve already loaded messages on background reconnect refresh failure
    }
  }

  void _onSocketError(Map<String, dynamic> payload) {
    if (!mounted) return;
    final convId = payload['conversationId']?.toString().trim() ?? '';
    final rawMessage = payload['message']?.toString().trim() ?? '';
    if (convId.isEmpty) return;

    final isForbidden = rawMessage.toLowerCase().contains('forbidden') ||
        rawMessage.toLowerCase().contains('unauthorized');
    if (isForbidden) {
      ref.read(socketServiceProvider).leaveConversation(convId);
      setState(() {
        _messagesByConversation.remove(convId);
        _loadingMessagesByConversation[convId] = false;
        _messagesErrorByConversation[convId] = const AuthFailure(
          'Bạn không có quyền truy cập cuộc trò chuyện này.',
          'FORBIDDEN',
          403,
        );
      });
    }
  }

  void _onSocketTyping(Map<String, dynamic> payload) {
    if (!mounted) return;
    final convId = payload['conversationId']?.toString().trim() ?? '';
    if (convId.isEmpty) return;

    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    final senderId =
        (payload['userId'] ?? payload['senderId'] ?? '').toString().trim();
    if (senderId.isNotEmpty && senderId == currentUserId) return;

    final isTyping = payload['isTyping'] != false;
    final senderName =
        (payload['userName'] ?? payload['fullName'] ?? 'Đối phương')
            .toString()
            .trim();

    _typingTimers[convId]?.cancel();
    if (!isTyping) {
      if (_typingUserByConversation.containsKey(convId)) {
        setState(() {
          _typingUserByConversation.remove(convId);
        });
      }
      return;
    }

    setState(() {
      _typingUserByConversation[convId] =
          senderName.isNotEmpty ? senderName : 'Đối phương';
    });

    _typingTimers[convId] = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _typingUserByConversation.remove(convId);
      });
    });
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
    if (currentUserId.isEmpty) return;

    // Enforce thread authorization: ignore events for conversations belonging to another guest/host pair
    final patchConv = envelope.conversation;
    if (patchConv != null &&
        !patchConv.canAccess(currentUserId,
            isHostPortal: widget.isHostPortal)) {
      return;
    }
    if (envelope.receiverUserId != null &&
        envelope.senderUserId != null &&
        envelope.receiverUserId != currentUserId &&
        envelope.senderUserId != currentUserId) {
      return;
    }
    if (!_isAuthorizedToAccessConversation(convId, currentUserId)) {
      return;
    }

    final isSelectedConv = convId == _selectedConversationId;
    final wasNearBottom = isSelectedConv && _checkIsNearBottom;
    final isFromMe = msg.senderId.isNotEmpty && msg.senderId == currentUserId;

    final existingMsgs = _messagesByConversation[convId] ?? const [];
    final alreadyHadMessage = existingMsgs.any((m) => m.id == msg.id);

    final baseList =
        ref.read(conversationsListProvider).valueOrNull ?? const [];
    final existingConv = _conversationOverrides[convId] ??
        baseList.where((c) => c.id == convId).firstOrNull ??
        patchConv;

    setState(() {
      _typingUserByConversation.remove(convId);
      _messagesByConversation[convId] = ChatMessageItem.mergeAndSortMessages(
        existingMsgs,
        [msg],
        conversationId: convId,
      );

      if (isSelectedConv && !wasNearBottom && !isFromMe && !alreadyHadMessage) {
        _unreadBelowByConversation[convId] =
            (_unreadBelowByConversation[convId] ?? 0) + 1;
      }

      if (existingConv != null) {
        final nextUnread = isSelectedConv
            ? 0
            : (!isFromMe && !alreadyHadMessage
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

    if (isSelectedConv && (wasNearBottom || isFromMe)) {
      _scrollToBottom(animate: true);
    }

    if (isSelectedConv && !isFromMe) {
      unawaited(_markReadQuietly(convId));
    }
    if (existingConv == null) {
      ref.invalidate(conversationsListProvider);
    }
  }

  bool _isAuthorizedToAccessConversation(
    String conversationId,
    String currentUserId,
  ) {
    if (currentUserId.trim().isEmpty) return false;
    final baseList =
        ref.read(conversationsListProvider).valueOrNull ?? const [];
    final known = _conversationOverrides[conversationId] ??
        baseList.where((c) => c.id == conversationId).firstOrNull;
    if (known != null) {
      return known.canAccess(
        currentUserId,
        isHostPortal: widget.isHostPortal,
      );
    }
    return true;
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
      } else {
        ref.invalidate(conversationsListProvider);
      }
    } catch (_) {
      // Non-fatal if read receipt fails
    }
  }

  void _saveDraftAndScrollBeforeLeaving(String? oldConversationId) {
    if (oldConversationId == null || oldConversationId.isEmpty) return;
    final text = _inputCtrl.text;
    if (text.isEmpty) {
      _draftsByConversation.remove(oldConversationId);
    } else {
      _draftsByConversation[oldConversationId] = text;
    }
    if (_scrollController.hasClients) {
      _scrollOffsetByConversation[oldConversationId] =
          _scrollController.position.pixels;
    }
  }

  void _loadDraftForConversation(String? nextConversationId) {
    _isSwitchingConversation = true;
    final draft = nextConversationId != null
        ? (_draftsByConversation[nextConversationId] ?? '')
        : '';
    _inputCtrl.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    _isSwitchingConversation = false;
  }

  void _leaveActiveConversationToInbox() {
    final prevId = _selectedConversationId;
    _saveDraftAndScrollBeforeLeaving(prevId);
    if (prevId != null && prevId.isNotEmpty) {
      ref.read(socketServiceProvider).leaveConversation(prevId);
    }
    setState(() {
      _selectedConversationId = null;
    });
  }

  Future<void> _selectConversation(
    String conversationId, {
    bool forceReload = false,
  }) async {
    final trimmedId = conversationId.trim();
    if (!mounted || trimmedId.isEmpty) return;

    final prevId = _selectedConversationId;
    if (prevId != null && prevId != trimmedId) {
      _saveDraftAndScrollBeforeLeaving(prevId);
      ref.read(socketServiceProvider).leaveConversation(prevId);
    }

    _loadDraftForConversation(trimmedId);
    final hadSavedOffset = _scrollOffsetByConversation.containsKey(trimmedId);
    final savedOffset = _scrollOffsetByConversation[trimmedId];

    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    if (!_isAuthorizedToAccessConversation(trimmedId, currentUserId)) {
      ref.read(socketServiceProvider).leaveConversation(trimmedId);
      setState(() {
        _selectedConversationId = trimmedId;
        _loadingMessagesByConversation[trimmedId] = false;
        _messagesByConversation.remove(trimmedId);
        _messagesErrorByConversation[trimmedId] = const AuthFailure(
          'Bạn không có quyền truy cập cuộc trò chuyện này.',
          'FORBIDDEN',
          403,
        );
      });
      return;
    }

    final existingCached = _messagesByConversation[trimmedId];
    final showFullLoading =
        forceReload || existingCached == null || existingCached.isEmpty;

    setState(() {
      _selectedConversationId = trimmedId;
      _messagesErrorByConversation.remove(trimmedId);
      if (showFullLoading) {
        _loadingMessagesByConversation[trimmedId] = true;
      }
      final baseList =
          ref.read(conversationsListProvider).valueOrNull ?? const [];
      final existingConv = _conversationOverrides[trimmedId] ??
          baseList.where((c) => c.id == trimmedId).firstOrNull;
      if (existingConv != null && existingConv.unreadCount > 0) {
        _conversationOverrides[trimmedId] =
            existingConv.copyWith(unreadCount: 0);
      }
    });

    if (!showFullLoading && existingCached.isNotEmpty) {
      _restoreOrInitScrollForConversation(
        trimmedId,
        hadSavedOffset: hadSavedOffset,
        savedOffset: savedOffset,
      );
    }

    final socket = ref.read(socketServiceProvider);
    socket.joinConversation(trimmedId);

    try {
      final paginated = await ref
          .read(conversationsRepositoryProvider)
          .getMessagesPaginated(trimmedId);
      if (!mounted) return;
      setState(() {
        final currentMsgs = _messagesByConversation[trimmedId] ?? const [];
        _messagesByConversation[trimmedId] =
            ChatMessageItem.mergeAndSortMessages(
          currentMsgs,
          paginated.items,
          conversationId: trimmedId,
        );
        _paginationByConversation[trimmedId] = paginated.pagination;
        _loadingMessagesByConversation[trimmedId] = false;
        _messagesErrorByConversation.remove(trimmedId);
      });
      if (_selectedConversationId == trimmedId) {
        _restoreOrInitScrollForConversation(
          trimmedId,
          hadSavedOffset: hadSavedOffset,
          savedOffset: savedOffset,
        );
      }
      await _markReadQuietly(trimmedId);
    } catch (e) {
      if (!mounted) return;
      final failure = DioClient.handleError(e);
      if (failure is AuthFailure || failure is NotFoundFailure) {
        socket.leaveConversation(trimmedId);
      }
      setState(() {
        _loadingMessagesByConversation[trimmedId] = false;
        _messagesErrorByConversation[trimmedId] = failure;
      });
    }
  }

  Future<void> _loadMoreHistory(String conversationId) async {
    if (_loadingHistoryByConversation[conversationId] == true) return;
    final meta = _paginationByConversation[conversationId];
    if (meta == null || !meta.hasNext) return;

    setState(() {
      _loadingHistoryByConversation[conversationId] = true;
    });

    final beforeMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final beforePixels =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    try {
      final nextPage = meta.page + 1;
      final result =
          await ref.read(conversationsRepositoryProvider).getMessagesPaginated(
                conversationId,
                page: nextPage,
                limit: meta.limit,
              );
      if (!mounted) return;
      setState(() {
        final existing = _messagesByConversation[conversationId] ?? const [];
        _messagesByConversation[conversationId] =
            ChatMessageItem.mergeAndSortMessages(
          existing,
          result.items,
          conversationId: conversationId,
        );
        _paginationByConversation[conversationId] = result.pagination;
        _loadingHistoryByConversation[conversationId] = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _selectedConversationId != conversationId ||
            !_scrollController.hasClients) {
          return;
        }
        final afterMaxExtent = _scrollController.position.maxScrollExtent;
        final delta = math.max(0.0, afterMaxExtent - beforeMaxExtent);
        final target = (beforePixels + delta).clamp(0.0, afterMaxExtent);
        _scrollController.jumpTo(target);
        _scrollOffsetByConversation[conversationId] = target;
      });
    } catch (e) {
      if (!mounted) return;
      final failure = DioClient.handleError(e);
      setState(() {
        _loadingHistoryByConversation[conversationId] = false;
      });
      AppToast.show(context, failure.message, type: AppToastType.error);
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    await _sendDirectContent(text, clearInput: true);
  }

  Future<void> _sendDirectContent(
    String rawContent, {
    bool clearInput = false,
  }) async {
    final convId = _selectedConversationId;
    final text = rawContent.trim();
    if (convId == null || convId.isEmpty || text.isEmpty) return;

    final currentUserId = ref.read(authNotifierProvider).valueOrNull?.id ?? '';
    if (currentUserId.isEmpty) return;

    if (!_isAuthorizedToAccessConversation(convId, currentUserId)) {
      AppToast.show(
        context,
        'Bạn không có quyền gửi tin nhắn trong cuộc trò chuyện này.',
        type: AppToastType.error,
      );
      return;
    }

    final localId =
        'local_${DateTime.now().microsecondsSinceEpoch}_${++_localMessageSequence}';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final pendingMessage = ChatMessageItem(
      id: localId,
      localId: localId,
      conversationId: convId,
      senderId: currentUserId,
      content: text,
      createdAt: nowIso,
      status: MessageDeliveryStatus.sending,
    );

    if (clearInput) {
      _isSwitchingConversation = true;
      _inputCtrl.clear();
      _isSwitchingConversation = false;
      _draftsByConversation.remove(convId);
    }

    setState(() {
      final currentList = _messagesByConversation[convId] ?? const [];
      _messagesByConversation[convId] = ChatMessageItem.mergeAndSortMessages(
        currentList,
        [pendingMessage],
        conversationId: convId,
      );
    });
    _scrollToBottom(animate: true);

    await _dispatchMessageRequest(
      conversationId: convId,
      localId: localId,
      content: text,
    );
  }

  _ChatPortalRole _resolveChatRole(User? user, ConversationItem conv) {
    if (widget.isAdminPortal || (user?.isAdmin ?? false)) {
      return _ChatPortalRole.admin;
    }
    if (widget.isHostPortal) {
      return _ChatPortalRole.host;
    }
    final uid = user?.id.trim() ?? '';
    if (uid.isNotEmpty && conv.hostId.trim().isNotEmpty) {
      return conv.hostId.trim() == uid
          ? _ChatPortalRole.host
          : _ChatPortalRole.guest;
    }
    if (user?.isHost ?? false) {
      return _ChatPortalRole.host;
    }
    return _ChatPortalRole.guest;
  }

  List<String> _quickRepliesForRole(_ChatPortalRole role) {
    switch (role) {
      case _ChatPortalRole.admin:
        return _adminQuickReplies;
      case _ChatPortalRole.host:
        return _hostQuickReplies;
      case _ChatPortalRole.guest:
        return _guestQuickReplies;
    }
  }

  void _applyQuickReply(String text) {
    _inputCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _inputFocusNode.requestFocus();
  }

  Future<void> _openCameraChat() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (!mounted) return;
      if (file != null) {
        await _sendDirectContent('📷 [Ảnh chụp trực tiếp] ${file.name}');
        return;
      }
    } catch (_) {
      if (!mounted) return;
      await _sendDirectContent('📷 [Ảnh chụp trực tiếp từ ứng dụng]');
    }
  }

  Future<void> _pickAndSendChatImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (file != null) {
        await _sendDirectContent('🖼️ [Đã gửi 1 hình ảnh] ${file.name}');
      }
    } catch (_) {
      if (!mounted) return;
      await _sendDirectContent('🖼️ [Đã gửi 1 hình ảnh đính kèm]');
    }
  }

  void _toggleVoiceRecording() {
    if (_isRecordingVoice) {
      final sec = _voiceRecordingSeconds;
      _voiceTimer?.cancel();
      setState(() {
        _isRecordingVoice = false;
        _voiceRecordingSeconds = 0;
      });
      unawaited(
        _sendDirectContent(
          '🎤 Tin nhắn thoại (00:${sec.toString().padLeft(2, '0')})',
        ),
      );
    } else {
      setState(() {
        _isRecordingVoice = true;
        _voiceRecordingSeconds = 0;
      });
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _voiceRecordingSeconds++;
        });
      });
    }
  }

  void _showChatMoreOptions(_ChatPortalRole role, ConversationItem conv) {
    final templates = <({IconData icon, String title, String subtitle, String content})>[
      switch (role) {
        _ChatPortalRole.admin => (
            icon: LucideIcons.shieldCheck,
            title: 'Yêu cầu bổ sung hồ sơ / giấy tờ',
            subtitle: 'Nhắc Chủ nhà hoặc Khách cập nhật thông tin xác minh',
            content:
                '📋 Ban quản trị đề nghị bạn kiểm tra và bổ sung giấy tờ xác minh rõ nét để hệ thống hoàn tất phê duyệt.',
          ),
        _ChatPortalRole.host => (
            icon: LucideIcons.mapPin,
            title: 'Gửi vị trí chỗ nghỉ',
            subtitle: 'Địa chỉ chi tiết và hướng dẫn di chuyển',
            content:
                '📍 Vị trí ${conv.listingTitle}: Đường Thùy Vân, TP. Vũng Tàu (gần bãi tắm Bãi Sau).',
          ),
        _ChatPortalRole.guest => (
            icon: LucideIcons.calendarCheck,
            title: 'Hỏi lịch trống & báo giá',
            subtitle: 'Kiểm tra tình trạng phòng và phụ thu cuối tuần',
            content:
                '📅 Chào Chủ nhà, cho mình hỏi căn còn trống lịch cuối tuần này và giá trọn gói cho đoàn mình nhé ạ?',
          ),
      },
      switch (role) {
        _ChatPortalRole.admin => (
            icon: LucideIcons.clipboardCheck,
            title: 'Thông báo kết quả kiểm duyệt',
            subtitle: 'Cập nhật trạng thái bài đăng hoặc tài khoản',
            content:
                '✅ Quản trị viên đã kiểm tra và cập nhật trạng thái hồ sơ/bài đăng của bạn trên hệ thống.',
          ),
        _ChatPortalRole.host => (
            icon: LucideIcons.clock,
            title: 'Giờ nhận & trả phòng',
            subtitle: 'Check-in: 14:00 • Check-out: 12:00',
            content:
                '⏰ Thời gian nhận phòng: từ 14:00 | Thời gian trả phòng: trước 12:00 ngày hôm sau.',
          ),
        _ChatPortalRole.guest => (
            icon: LucideIcons.clock,
            title: 'Xin nhận phòng sớm / trả phòng muộn',
            subtitle: 'Hỏi hỗ trợ linh hoạt giờ check-in / check-out',
            content:
                '⏰ Đoàn mình dự kiến đến sớm hơn 14:00 một chút, Chủ nhà có thể hỗ trợ gửi hành lý hoặc nhận phòng sớm không ạ?',
          ),
      },
      switch (role) {
        _ChatPortalRole.admin => (
            icon: LucideIcons.lifeBuoy,
            title: 'Hướng dẫn chính sách nền tảng',
            subtitle: 'Giải đáp quy định đặt phòng & phí dịch vụ',
            content:
                'ℹ️ Mọi giao dịch trên hệ thống đều được bảo vệ theo chính sách đặt phòng và hoàn hủy minh bạch của The Palm Villa.',
          ),
        _ChatPortalRole.host => (
            icon: LucideIcons.fileText,
            title: 'Gửi nội quy lưu trú',
            subtitle: 'Giữ gìn vệ sinh, yên tĩnh sau 22:00',
            content:
                '📋 Nội quy lưu trú: Vui lòng giữ gìn tài sản chung và hạn chế tiếng ồn lớn sau 22:00. Chúc quý khách kỳ nghỉ tuyệt vời!',
          ),
        _ChatPortalRole.guest => (
            icon: LucideIcons.flame,
            title: 'Hỏi tiện ích BBQ & hồ bơi',
            subtitle: 'Bếp nướng, than, phao bơi và chỗ đậu xe',
            content:
                '🔥 Biệt thự có sẵn lò nướng BBQ, dụng cụ bếp, hồ bơi riêng và chỗ đậu ô tô trong sân không ạ?',
          ),
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tiện ích mở rộng & Mẫu tin nhanh',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_openCameraChat());
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(LucideIcons.camera, size: 16),
                      label: const Text('Chụp ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_pickAndSendChatImage());
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(LucideIcons.image, size: 16),
                      label: const Text('Thư viện ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _toggleVoiceRecording();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(LucideIcons.mic, size: 16),
                      label: const Text('Tin nhắn thoại'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 6),
                for (final tpl in templates)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(tpl.icon, color: AppColors.primary, size: 20),
                    title: Text(
                      tpl.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textStrong,
                      ),
                    ),
                    subtitle: Text(
                      tpl.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_sendDirectContent(tpl.content));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEmojiSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        const emojis = [
          '😊',
          '🥰',
          '😍',
          '🌴',
          '🏖️',
          '✨',
          '👍',
          '🙏',
          '❤️',
          '🔥',
          '🎉',
          '💯',
          '⭐',
          '🌊',
          '🏡',
          '🔑',
          '☕',
          '🌟',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn biểu tượng cảm xúc',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: emojis.map((e) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        final current = _inputCtrl.text;
                        final next = current.isEmpty ? e : '$current $e';
                        _inputCtrl.value = TextEditingValue(
                          text: next,
                          selection:
                              TextSelection.collapsed(offset: next.length),
                        );
                        _inputFocusNode.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _chooseQuickEmoji() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        const quickOptions = ['👍', '❤️', '😤', '🌴', '🔥', '⭐'];
        return AlertDialog(
          title: const Text('Chọn biểu tượng gửi nhanh'),
          content: Wrap(
            spacing: 14,
            runSpacing: 12,
            children: quickOptions.map((e) {
              return InkWell(
                onTap: () {
                  setState(() => _chatQuickEmoji = e);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _retryFailedMessage(ChatMessageItem failedMsg) async {
    final convId = failedMsg.conversationId;
    final localId = failedMsg.localId ?? failedMsg.id;

    setState(() {
      final currentList = _messagesByConversation[convId] ?? const [];
      _messagesByConversation[convId] = currentList.map((m) {
        if (m.id == failedMsg.id || m.localId == localId) {
          return m.copyWith(
            status: MessageDeliveryStatus.sending,
            clearError: true,
          );
        }
        return m;
      }).toList();
    });

    await _dispatchMessageRequest(
      conversationId: convId,
      localId: localId,
      content: failedMsg.content,
    );
  }

  void _removeFailedMessage(ChatMessageItem failedMsg) {
    final convId = failedMsg.conversationId;
    setState(() {
      final currentList = _messagesByConversation[convId] ?? const [];
      _messagesByConversation[convId] = currentList
          .where((m) => m.id != failedMsg.id && m.localId != failedMsg.id)
          .toList();
    });
  }

  Future<void> _dispatchMessageRequest({
    required String conversationId,
    required String localId,
    required String content,
  }) async {
    try {
      final sent = await ref.read(conversationsRepositoryProvider).sendMessage(
            conversationId: conversationId,
            content: content,
          );
      if (!mounted) return;
      final confirmed = sent.copyWith(
        status: MessageDeliveryStatus.sent,
        localId: localId,
      );
      final baseList =
          ref.read(conversationsListProvider).valueOrNull ?? const [];
      final existing = _conversationOverrides[conversationId] ??
          baseList.where((c) => c.id == conversationId).firstOrNull;
      setState(() {
        final currentList = _messagesByConversation[conversationId] ?? const [];
        _messagesByConversation[conversationId] =
            ChatMessageItem.mergeAndSortMessages(
          currentList,
          [confirmed],
          conversationId: conversationId,
          replaceLocalId: localId,
        );

        if (existing != null) {
          _conversationOverrides[conversationId] = existing.copyWith(
            lastMessage: confirmed.content,
            lastMessageAt: confirmed.createdAt,
            updatedAt: confirmed.createdAt,
            unreadCount: 0,
          );
        }
      });
      if (_selectedConversationId == conversationId && _checkIsNearBottom) {
        _scrollToBottom(animate: false);
      }
      if (existing == null) {
        ref.invalidate(conversationsListProvider);
      }
    } catch (e) {
      if (!mounted) return;
      final failure = DioClient.handleError(e);
      setState(() {
        final currentList = _messagesByConversation[conversationId] ?? const [];
        _messagesByConversation[conversationId] = currentList.map((m) {
          if (m.id == localId || m.localId == localId) {
            return m.copyWith(
              status: MessageDeliveryStatus.failed,
              errorMessage: failure.message,
            );
          }
          return m;
        }).toList();
      });
      AppToast.show(context, failure.message, type: AppToastType.error);
    }
  }

  List<ConversationItem> _effectiveConversations(
    List<ConversationItem> rawList,
    String currentUserId,
  ) {
    final authorized = rawList.where((item) {
      return item.canAccess(
        currentUserId,
        isHostPortal: widget.isHostPortal,
      );
    });

    final merged = authorized.map((item) {
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
      if (tA != null && tB == null) return -1;
      if (tA == null && tB != null) return 1;
      return 0;
    });
    return merged;
  }

  String _errorTitleFor(Object error) {
    if (error is NetworkFailure) return 'Mất kết nối mạng';
    if (error is AuthFailure) {
      return error.statusCode == 403
          ? 'Không có quyền truy cập'
          : 'Phiên đăng nhập hết hạn';
    }
    if (error is NotFoundFailure) return 'Không tìm thấy cuộc trò chuyện';
    if (error is RateLimitFailure) return 'Thao tác quá nhanh';
    if (error is ServerFailure) return 'Lỗi máy chủ';
    if (error is ValidationFailure) return 'Dữ liệu không hợp lệ';
    return 'Đã có lỗi xảy ra';
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
    WidgetsBinding.instance.removeObserver(this);
    if (_selectedConversationId != null &&
        _selectedConversationId!.isNotEmpty) {
      _socket.leaveConversation(_selectedConversationId!);
    }
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _voiceTimer?.cancel();
    _socketMessageSub?.cancel();
    _socketErrorSub?.cancel();
    _socketTypingSub?.cancel();
    _reconnectSub?.cancel();
    _inputCtrl.removeListener(_onInputChanged);
    _scrollController.removeListener(_onScrollChanged);
    _timestampDragCtrl.dispose();
    _inputFocusNode.dispose();
    _inputCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authNotifierProvider, (prev, next) {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;
      if (nextUser == null ||
          (prevUser != null && prevUser.id != nextUser.id)) {
        _clearStateForSessionChange();
      }
    });

    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (!_isEmbeddedPortal)
              const AppSearchHeader(currentPath: '/messages'),
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

    if (_activeUserId != user.id) {
      _activeUserId = user.id;
    }

    final convsAsync = ref.watch(conversationsListProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bodyContent = convsAsync.when(
      skipLoadingOnRefresh: !convsAsync.hasError,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        final failure = DioClient.handleError(err);
        return AppErrorView(
          title: _errorTitleFor(failure),
          message: failure.message,
          onRetry: () {
            ref.invalidate(conversationsListProvider);
            if (_selectedConversationId != null &&
                _selectedConversationId!.isNotEmpty) {
              _selectConversation(_selectedConversationId!, forceReload: true);
            }
          },
        );
      },
      data: (rawConversations) {
        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final isSplitView =
                screenWidth >= 780 && outerConstraints.maxWidth >= 780;
            final conversations =
                _effectiveConversations(rawConversations, user.id);
            final selectedId = _selectedConversationId;

            // Check if selectedId was in rawConversations but unauthorized for this user
            if (selectedId != null && selectedId.isNotEmpty) {
              final rawMatch =
                  rawConversations.where((c) => c.id == selectedId).firstOrNull;
              if (rawMatch != null &&
                  !rawMatch.canAccess(
                    user.id,
                    isHostPortal: widget.isHostPortal,
                  ) &&
                  _messagesErrorByConversation[selectedId] == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _socket.leaveConversation(selectedId);
                  setState(() {
                    _loadingMessagesByConversation[selectedId] = false;
                    _messagesByConversation.remove(selectedId);
                    _messagesErrorByConversation[selectedId] =
                        const AuthFailure(
                      'Bạn không có quyền truy cập cuộc trò chuyện này.',
                      'FORBIDDEN',
                      403,
                    );
                  });
                });
              }
            }

            final activeConv = selectedId != null
                ? conversations.where((c) => c.id == selectedId).firstOrNull
                : null;
            final selectedError = selectedId != null
                ? _messagesErrorByConversation[selectedId]
                : null;
            final selectedLoading = selectedId != null &&
                (_loadingMessagesByConversation[selectedId] ?? false);

            if (conversations.isEmpty &&
                activeConv == null &&
                selectedError == null &&
                !selectedLoading) {
              if (widget.isAdminPortal || user.isAdmin) {
                return AppEmptyView(
                  icon: LucideIcons.messageSquare,
                  title: 'Chưa có cuộc trò chuyện hỗ trợ nào',
                  description:
                      'Các hội thoại hỗ trợ trực tiếp với Chủ nhà và Khách hàng trên hệ thống sẽ hiển thị tại đây.',
                  actionText: GoRouter.maybeOf(context) != null
                      ? 'Quản lý người dùng'
                      : null,
                  onAction: GoRouter.maybeOf(context) != null
                      ? () => context.go('/admin/nguoi-dung')
                      : null,
                );
              }
              if (widget.isHostPortal || user.isHost) {
                return const AppEmptyView(
                  icon: LucideIcons.messageSquare,
                  title: 'Chưa có cuộc trò chuyện nào',
                  description:
                      'Khi khách hàng nhắn tin hỏi phòng hoặc đặt chỗ, hội thoại sẽ hiển thị tại đây.',
                );
              }
              return AppEmptyView(
                icon: LucideIcons.messageSquare,
                title: 'Chưa có cuộc trò chuyện nào',
                description:
                    'Hãy chọn một biệt thự và bấm "Nhắn tin cho Chủ nhà" để bắt đầu trò chuyện.',
                actionText: 'Khám phá biệt thự',
                onAction: () => context.push('/search'),
              );
            }

            // Auto-select first conversation on desktop split view when none is selected
            if (isSplitView &&
                _selectedConversationId == null &&
                conversations.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedConversationId == null) {
                  _selectConversation(conversations.first.id);
                }
              });
            }

            final fallbackConv = (selectedId != null && selectedId.isNotEmpty)
                ? ConversationItem(
                    id: selectedId,
                    listingId: '',
                    listingTitle: 'Trao đổi về chỗ nghỉ',
                    guestId: '',
                    guestName: '',
                    hostId: '',
                    hostName: '',
                  )
                : null;

            final effectiveActiveConv = activeConv ??
                ((selectedError != null || selectedLoading)
                    ? fallbackConv
                    : null);

            if (isSplitView) {
              return Row(
                children: [
                  SizedBox(
                    width: 340,
                    child: _buildConversationList(conversations, user.id),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: effectiveActiveConv == null
                        ? const Center(
                            child: Text('Chọn một hội thoại để xem tin nhắn'),
                          )
                        : _buildChatPane(
                            effectiveActiveConv,
                            user.id,
                            showBackButton: false,
                          ),
                  ),
                ],
              );
            }

            // Mobile view: show either conversation list OR active chat pane
            if (effectiveActiveConv != null) {
              return _buildChatPane(
                effectiveActiveConv,
                user.id,
                showBackButton: true,
              );
            }
            return _buildConversationList(conversations, user.id);
          },
        );
      },
    );

    if (_isEmbeddedPortal) {
      return Material(
        color: AppColors.surfaceBase,
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppSearchHeader(currentPath: '/messages'),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar(String name, String? avatarUrl) {
    final trimmedUrl = avatarUrl?.trim() ?? '';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    if (trimmedUrl.isNotEmpty) {
      return ClipOval(
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
    final totalUnread = conversations.fold<int>(
      0,
      (sum, item) => sum + (item.unreadCount > 0 ? item.unreadCount : 0),
    );

    return Container(
      color: AppColors.surfaceBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalUnread > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    key: const Key('inbox_total_unread_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadii.roundedPill,
                    ),
                    child: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
          ],
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(conversationsListProvider);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: conversations.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final isSelected = conv.id == _selectedConversationId;
                final counterpart = conv.displayNameFor(currentUserId);
                final timeLabel =
                    _formatTimestamp(conv.lastMessageAt ?? conv.updatedAt);
                final savedDraft = _draftsByConversation[conv.id]?.trim() ?? '';
                final hasDraft = savedDraft.isNotEmpty && !isSelected;
                final previewText = hasDraft
                    ? 'Nháp: $savedDraft'
                    : (conv.lastMessage != null &&
                            conv.lastMessage!.trim().isNotEmpty)
                        ? conv.lastMessage!.trim()
                        : 'Chưa có tin nhắn.';

                return InkWell(
                  key: ValueKey<String>('conv_tile_${conv.id}'),
                  onTap: () => _selectConversation(conv.id),
                  child: Container(
                    color: AppColors.surfaceBase,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildParticipantAvatar(
                          counterpart,
                          conv.displayAvatar,
                        ),
                        const SizedBox(width: AppSpacing.s12),
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
                                        color: AppColors.textStrong,
                                        fontWeight: conv.unreadCount > 0
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (timeLabel.isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.s8),
                                    Flexible(
                                      flex: 0,
                                      child: Text(
                                        timeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
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
                                        fontWeight:
                                            (conv.unreadCount > 0 || hasDraft)
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                        color: hasDraft
                                            ? AppColors.primary
                                            : (conv.unreadCount > 0
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                  if (conv.unreadCount > 0) ...[
                                    const SizedBox(width: AppSpacing.s8),
                                    Container(
                                      key: ValueKey<String>(
                                        'unread_badge_${conv.id}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: AppRadii.roundedPill,
                                      ),
                                      child: Text(
                                        conv.unreadCount > 99
                                            ? '99+'
                                            : '${conv.unreadCount}',
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
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final chatRole = _resolveChatRole(user, conv);
    final quickReplies = _quickRepliesForRole(chatRole);
    final counterpart = conv.displayNameFor(currentUserId);
    final convId = conv.id;
    final isLoading = _loadingMessagesByConversation[convId] ?? false;
    final error = _messagesErrorByConversation[convId];
    final isForbidden = error is AuthFailure && error.statusCode == 403;
    final messages = _activeMessages;
    final pagination = _paginationByConversation[convId];
    final hasMoreHistory = pagination != null && pagination.hasNext;
    final isLoadingHistory = _loadingHistoryByConversation[convId] ?? false;
    final typingUser = _typingUserByConversation[convId];
    final unreadBelow = _unreadBelowByConversation[convId] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final paneHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 720.0;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final isCompactHeader = paneWidth < 400 || textScale > 1.25;
        final isCompactComposer = paneWidth < 375 || textScale > 1.22;
        final bubbleMaxWidth =
            math.min(420.0, math.max(190.0, (paneWidth - 48.0) * 0.78));
        final keyboardInset =
            _isEmbeddedPortal ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
        final availableHeight = paneHeight - keyboardInset;
        final showQuickReplies =
            !isForbidden && quickReplies.isNotEmpty && availableHeight >= 380.0;

        return Container(
          color: AppColors.surfaceBase,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Column(
            children: [
              // ── Messenger Chat Header ──
              Container(
                color: AppColors.surfaceBase,
                padding: EdgeInsets.symmetric(
                  horizontal: showBackButton ? AppSpacing.s8 : AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    if (showBackButton)
                      Semantics(
                        button: true,
                        label: 'Quay lại danh sách',
                        child: IconButton(
                          key: const Key('chat_back_button'),
                          onPressed: _leaveActiveConversationToInbox,
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
                      ),
                    _buildParticipantAvatar(counterpart, conv.displayAvatar),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            counterpart,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textStrong,
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
                    if (!isCompactHeader)
                      IconButton(
                        key: const Key('chat_toggle_timestamps_btn'),
                        onPressed: () {
                          setState(() {
                            _showTimestampsPinned = !_showTimestampsPinned;
                            if (_showTimestampsPinned) {
                              _timestampDragCtrl.forward();
                            } else {
                              _timestampDragCtrl.reverse();
                            }
                          });
                        },
                        tooltip: _showTimestampsPinned
                            ? 'Ẩn thời gian'
                            : 'Hiện khung thời gian',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          _showTimestampsPinned
                              ? LucideIcons.clockCheck
                              : LucideIcons.clock,
                          size: 18,
                          color: _showTimestampsPinned
                              ? AppColors.primary
                              : AppColors.iconMuted,
                        ),
                      ),
                    if (conv.listingId.isNotEmpty)
                      isCompactHeader
                          ? Semantics(
                              button: true,
                              label: 'Xem chỗ nghỉ',
                              child: IconButton(
                                key: const Key('view_listing_button'),
                                onPressed: () =>
                                    context.push('/villa/${conv.listingId}'),
                                tooltip: 'Xem chỗ nghỉ',
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const Icon(
                                  LucideIcons.externalLink,
                                  size: 18,
                                  color: AppColors.iconStrong,
                                ),
                              ),
                            )
                          : TextButton(
                              key: const Key('view_listing_button'),
                              onPressed: () =>
                                  context.push('/villa/${conv.listingId}'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                shape: const StadiumBorder(),
                                foregroundColor: AppColors.textStrong,
                              ),
                              child: const Text('Xem chỗ nghỉ'),
                            ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSoft),

              // ── Message Body (Messenger Bubbles + Reactions + Swipe Timestamps) ──
              Expanded(
                child: isLoading && messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : error != null && messages.isEmpty
                        ? SingleChildScrollView(
                            child: AppErrorView(
                              title: _errorTitleFor(error),
                              message: error.message,
                              onRetry: isForbidden
                                  ? null
                                  : () => _selectConversation(
                                        convId,
                                        forceReload: true,
                                      ),
                            ),
                          )
                        : messages.isEmpty
                            ? const Center(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(AppSpacing.s16),
                                  child: Text(
                                    'Hãy gửi tin nhắn đầu tiên để bắt đầu trao đổi.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () {
                                  if (_reactionActiveMsgKey != null) {
                                    setState(
                                      () => _reactionActiveMsgKey = null,
                                    );
                                  }
                                },
                                onHorizontalDragStart: (_) {
                                  _horizontalDragOffset = 0.0;
                                },
                                onHorizontalDragUpdate: (details) {
                                  final dx = details.primaryDelta ?? 0.0;
                                  _horizontalDragOffset += dx;
                                  final progress = (_horizontalDragOffset.abs() /
                                          55.0)
                                      .clamp(0.0, 1.0);
                                  _timestampDragCtrl.value = progress;
                                },
                                onHorizontalDragEnd: (_) {
                                  if (!_showTimestampsPinned) {
                                    _timestampDragCtrl.animateTo(
                                      0.0,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                  _horizontalDragOffset = 0.0;
                                },
                                onHorizontalDragCancel: () {
                                  if (!_showTimestampsPinned) {
                                    _timestampDragCtrl.animateTo(
                                      0.0,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                  _horizontalDragOffset = 0.0;
                                },
                                child: Stack(
                                  children: [
                                    ListView.builder(
                                      key: ValueKey<String>(
                                        'chat_message_list_$convId',
                                      ),
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      itemCount: messages.length +
                                          (hasMoreHistory ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (hasMoreHistory && index == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AppSpacing.s12,
                                            ),
                                            child: Center(
                                              child: OutlinedButton.icon(
                                                key: const Key(
                                                  'load_more_history_button',
                                                ),
                                                onPressed: isLoadingHistory
                                                    ? null
                                                    : () => _loadMoreHistory(
                                                          convId,
                                                        ),
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize:
                                                      const Size(48, 48),
                                                  shape: const StadiumBorder(),
                                                  side: const BorderSide(
                                                    color: AppColors.border,
                                                  ),
                                                  foregroundColor:
                                                      AppColors.textStrong,
                                                ),
                                                icon: isLoadingHistory
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        LucideIcons.clock,
                                                        size: 16,
                                                        color: AppColors
                                                            .iconStrong,
                                                      ),
                                                label: Text(
                                                  isLoadingHistory
                                                      ? 'Đang tải lịch sử...'
                                                      : 'Tải thêm tin nhắn cũ hơn',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        final msgIndex =
                                            hasMoreHistory ? index - 1 : index;
                                        final msg = messages[msgIndex];
                                        final prevSameSender = msgIndex > 0 &&
                                            messages[msgIndex - 1].senderId ==
                                                msg.senderId;
                                        final nextSameSender =
                                            msgIndex < messages.length - 1 &&
                                                messages[msgIndex + 1]
                                                        .senderId ==
                                                    msg.senderId;
                                        final isLastMessage =
                                            msgIndex == messages.length - 1;

                                        return _buildMessageBubble(
                                          msg,
                                          currentUserId: currentUserId,
                                          counterpartName: counterpart,
                                          counterpartAvatar: conv.displayAvatar,
                                          maxBubbleWidth: bubbleMaxWidth,
                                          prevSameSender: prevSameSender,
                                          nextSameSender: nextSameSender,
                                          isLastMessage: isLastMessage,
                                        );
                                      },
                                    ),
                                    if (unreadBelow > 0)
                                      Positioned(
                                        bottom: AppSpacing.s12,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: FilledButton.icon(
                                            key: const Key(
                                              'jump_to_bottom_button',
                                            ),
                                            onPressed: () =>
                                                _scrollToBottom(animate: true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(48, 44),
                                              shape: const StadiumBorder(),
                                            ),
                                            icon: const Icon(
                                              LucideIcons.chevronDown,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            label: Text(
                                              'Tin nhắn mới ($unreadBelow)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
              ),

              // ── Typing Indicator ──
              if (typingUser != null && typingUser.isNotEmpty)
                Container(
                  key: const Key('typing_indicator_banner'),
                  width: double.infinity,
                  color: AppColors.surfaceBase,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s4,
                  ),
                  child: Text(
                    '$typingUser đang nhập tin nhắn...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

              // ── Role-Aware Quick-Reply Chips ──
              if (showQuickReplies)
                Container(
                  key: const Key('chat_quick_replies_bar'),
                  color: AppColors.surfaceBase,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        for (var i = 0; i < quickReplies.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _buildQuickReplyChip(quickReplies[i]),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── Voice Recording Banner ──
              if (!isForbidden && _isRecordingVoice)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFFFFF1F2),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.mic,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang ghi âm... 00:${_voiceRecordingSeconds.toString().padLeft(2, '0')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _voiceTimer?.cancel();
                          setState(() {
                            _isRecordingVoice = false;
                            _voiceRecordingSeconds = 0;
                          });
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 40),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 40),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 0,
                        ),
                        onPressed: _toggleVoiceRecording,
                        icon: const Icon(LucideIcons.send, size: 14),
                        label:
                            const Text('Gửi', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // ── Unified Messenger Bottom Composer Bar ──
              if (!isForbidden)
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBase,
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Nút '+' tiện ích mở rộng tròn màu hồng
                          Semantics(
                            button: true,
                            label: 'Tiện ích mở rộng',
                            child: Tooltip(
                              message: 'Tiện ích mở rộng',
                              child: InkWell(
                                key: const Key('chat_more_features_btn'),
                                onTap: () =>
                                    _showChatMoreOptions(chatRole, conv),
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  width: isCompactComposer ? 40 : 36,
                                  height: 48,
                                  child: Center(
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.plus,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!isCompactComposer) ...[
                            const SizedBox(width: 2),
                            // 2. Nút Máy ảnh (Camera)
                            IconButton(
                              key: const Key('chat_camera_btn'),
                              onPressed: _openCameraChat,
                              tooltip: 'Chụp ảnh',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                LucideIcons.camera,
                                size: 21,
                                color: AppColors.primary,
                              ),
                            ),
                            // 3. Nút Thư viện ảnh (Gallery)
                            IconButton(
                              key: const Key('chat_gallery_btn'),
                              onPressed: _pickAndSendChatImage,
                              tooltip: 'Gửi hình ảnh',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 48,
                              ),
                              icon: const Icon(
                                LucideIcons.image,
                                size: 21,
                                color: AppColors.primary,
                              ),
                            ),
                            // 4. Nút Micro thu âm
                            IconButton(
                              key: const Key('chat_mic_btn'),
                              onPressed: _toggleVoiceRecording,
                              tooltip: _isRecordingVoice
                                  ? 'Dừng ghi âm'
                                  : 'Tin nhắn thoại',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 48,
                              ),
                              icon: Icon(
                                _isRecordingVoice
                                    ? LucideIcons.square
                                    : LucideIcons.mic,
                                size: 21,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),

                          // 5. Ô nhập tin nhắn Messenger bo tròn + nút mặt cười
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: TextField(
                                key: const Key('chat_message_input'),
                                controller: _inputCtrl,
                                focusNode: _inputFocusNode,
                                textInputAction: TextInputAction.send,
                                minLines: 1,
                                maxLines: 4,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: AppColors.textStrong,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Nhắn tin',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 14.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  suffixIcon: IconButton(
                                    key: const Key('chat_input_smile_btn'),
                                    onPressed: _showEmojiSelector,
                                    tooltip: 'Biểu tượng cảm xúc',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    icon: const Icon(
                                      LucideIcons.smile,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // 6. Nút Gửi tin nhắn / Cảm xúc nhanh (luôn >= 48x48)
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _inputCtrl,
                            builder: (context, value, _) {
                              final hasText = value.text.trim().isNotEmpty;
                              return Semantics(
                                button: true,
                                label: hasText
                                    ? 'Gửi tin nhắn'
                                    : 'Gửi biểu tượng nhanh',
                                child: Tooltip(
                                  message: hasText
                                      ? 'Gửi tin nhắn'
                                      : 'Gửi biểu tượng nhanh (nhấn giữ để đổi)',
                                  child: InkWell(
                                    key: const Key('chat_send_button'),
                                    onTap: () {
                                      if (_inputCtrl.text.trim().isNotEmpty) {
                                        _sendMessage();
                                      } else {
                                        _sendDirectContent(_chatQuickEmoji);
                                      }
                                    },
                                    onLongPress:
                                        hasText ? null : _chooseQuickEmoji,
                                    borderRadius: BorderRadius.circular(24),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                        child: hasText
                                            ? const Icon(
                                                LucideIcons.send,
                                                size: 21,
                                                color: AppColors.primary,
                                              )
                                            : Text(
                                                _chatQuickEmoji,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatSmallAvatar({
    required String name,
    String? avatarUrl,
  }) {
    final trimmedUrl = avatarUrl?.trim() ?? '';
    if (trimmedUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 28,
          height: 28,
          child: AppImage(url: trimmedUrl),
        ),
      );
    }
    final trimmed = name.trim();
    final letter = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFE0E7FF),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }

  Widget _buildReactionPicker(String msgKey) {
    return Container(
      key: ValueKey<String>('reaction_picker_$msgKey'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _messengerReactions.map((emoji) {
          final isSelected = _messageReactions[msgKey] == emoji;
          return InkWell(
            key: ValueKey<String>('reaction_${emoji}_$msgKey'),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _messageReactions.remove(msgKey);
                } else {
                  _messageReactions[msgKey] = emoji;
                }
                _reactionActiveMsgKey = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickReplyChip(String text) {
    return InkWell(
      onTap: () => _applyQuickReply(text),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessageItem msg, {
    required String currentUserId,
    required String counterpartName,
    String? counterpartAvatar,
    required double maxBubbleWidth,
    bool prevSameSender = false,
    bool nextSameSender = false,
    bool isLastMessage = false,
  }) {
    final isMe = msg.senderId == currentUserId;
    final timeLabel = _formatTimestamp(msg.createdAt);
    final stableKey = msg.localId ?? msg.id;
    final selectedReaction = _messageReactions[stableKey];
    final showReactionPicker = _reactionActiveMsgKey == stableKey;
    final isTimestampExpanded = _expandedTimestampKeys.contains(stableKey);

    final bubbleRadius = isMe
        ? BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: Radius.circular(prevSameSender ? 6 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: Radius.circular(nextSameSender ? 6 : 4),
          )
        : BorderRadius.only(
            topLeft: Radius.circular(prevSameSender ? 6 : 18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(nextSameSender ? 6 : 4),
            bottomRight: const Radius.circular(18),
          );

    final bgColor = msg.isFailed
        ? AppColors.errorSoft
        : (isMe ? AppColors.primary : const Color(0xFFF1F5F9));
    final textColor = msg.isFailed
        ? AppColors.textStrong
        : (isMe ? Colors.white : AppColors.textStrong);

    return FadeSlideIn(
      key: ValueKey<String>('msg_$stableKey'),
      duration: const Duration(milliseconds: 160),
      beginOffset: const Offset(0, 6),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: selectedReaction != null
              ? 16
              : (nextSameSender ? 3 : 10),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showReactionPicker) _buildReactionPicker(stableKey),
            AnimatedBuilder(
              animation: _timestampDragCtrl,
              builder: (context, child) {
                final dragVal = _timestampDragCtrl.value;
                final showTime =
                    (dragVal > 0.08 || isTimestampExpanded) &&
                        timeLabel.isNotEmpty;
                return Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (showTime)
                      Opacity(
                        opacity: isTimestampExpanded
                            ? 1.0
                            : dragVal.clamp(0.0, 1.0),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: 3,
                            left: isMe ? 0 : 36,
                            right: isMe ? 4 : 0,
                          ),
                          child: Text(
                            timeLabel,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[
                    if (!nextSameSender)
                      _buildChatSmallAvatar(
                        name: counterpartName,
                        avatarUrl: counterpartAvatar,
                      )
                    else
                      const SizedBox(width: 28),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_reactionActiveMsgKey != null) {
                            _reactionActiveMsgKey = null;
                          } else if (_expandedTimestampKeys
                              .contains(stableKey)) {
                            _expandedTimestampKeys.remove(stableKey);
                          } else {
                            _expandedTimestampKeys.add(stableKey);
                          }
                        });
                      },
                      onLongPress: () {
                        setState(() {
                          _reactionActiveMsgKey =
                              _reactionActiveMsgKey == stableKey
                                  ? null
                                  : stableKey;
                        });
                      },
                      onSecondaryTap: () {
                        setState(() {
                          _reactionActiveMsgKey =
                              _reactionActiveMsgKey == stableKey
                                  ? null
                                  : stableKey;
                        });
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints:
                                BoxConstraints(maxWidth: maxBubbleWidth),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: bubbleRadius,
                              border: msg.isFailed
                                  ? Border.all(color: AppColors.error)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (msg.attachments.isNotEmpty) ...[
                                  for (final attachmentUrl in msg.attachments)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.s8,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 180,
                                            maxWidth: 260,
                                          ),
                                          child: AppImage(url: attachmentUrl),
                                        ),
                                      ),
                                    ),
                                ],
                                if (msg.content.isNotEmpty)
                                  Text(
                                    msg.content,
                                    softWrap: true,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.38,
                                      color: textColor,
                                    ),
                                  ),
                                if (msg.isFailed) ...[
                                  const SizedBox(height: AppSpacing.s8),
                                  Wrap(
                                    spacing: AppSpacing.s8,
                                    runSpacing: AppSpacing.s4,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        key: ValueKey<String>(
                                          'retry_msg_$stableKey',
                                        ),
                                        onPressed: () =>
                                            _retryFailedMessage(msg),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(48, 48),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          shape: const StadiumBorder(),
                                          side: const BorderSide(
                                            color: AppColors.textStrong,
                                          ),
                                          foregroundColor: AppColors.textStrong,
                                        ),
                                        icon: const Icon(
                                          LucideIcons.refreshCw,
                                          size: 14,
                                          color: AppColors.iconStrong,
                                        ),
                                        label: const Text(
                                          'Thử lại',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey<String>(
                                          'delete_failed_msg_$stableKey',
                                        ),
                                        onPressed: () =>
                                            _removeFailedMessage(msg),
                                        tooltip: 'Xóa tin nhắn lỗi',
                                        constraints: const BoxConstraints(
                                          minWidth: 48,
                                          minHeight: 48,
                                        ),
                                        icon: const Icon(
                                          LucideIcons.trash2,
                                          size: 16,
                                          color: AppColors.iconStrong,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selectedReaction != null)
                            Positioned(
                              bottom: -11,
                              right: isMe ? 8 : null,
                              left: isMe ? null : 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _messageReactions.remove(stableKey),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    selectedReaction,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isMe && msg.status == MessageDeliveryStatus.sending)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Text(
                  'Đang gửi...',
                  key: ValueKey<String>('msg_status_$stableKey'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            if (isMe && msg.status == MessageDeliveryStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Text(
                  'Gửi thất bại',
                  key: ValueKey<String>('msg_status_$stableKey'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            if (isMe &&
                isLastMessage &&
                msg.status == MessageDeliveryStatus.sent)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(
                      LucideIcons.checkCheck,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Đã gửi',
                      key: ValueKey<String>('msg_status_$stableKey'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Text(
                      ' • Đã xem',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
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
      final failure = DioClient.handleError(e);
      setState(() => _isSending = false);
      AppToast.show(context, failure.message, type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final villaAsync = ref.watch(villaDetailProvider(widget.villaId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const AppSearchHeader(currentPath: '/messages'),
          Expanded(
            child: villaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) {
                final failure = DioClient.handleError(err);
                return AppErrorView(
                  message: failure.message,
                  onRetry: () =>
                      ref.invalidate(villaDetailProvider(widget.villaId)),
                );
              },
              data: (villa) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  context.go('/villa/${widget.villaId}'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                ),
                                minimumSize: const Size(48, 48),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: const StadiumBorder(),
                                foregroundColor: AppColors.textStrong,
                              ),
                              icon: const Icon(
                                LucideIcons.arrowLeft,
                                size: 16,
                                color: AppColors.iconStrong,
                              ),
                              label: const Text(
                                'Quay lại trang biệt thự',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            const Text(
                              'Liên hệ Chủ nhà',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textStrong,
                                letterSpacing: -0.4,
                              ),
                            ),
                            if (villa != null) ...[
                              const SizedBox(height: AppSpacing.s12),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBase,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 64,
                                        height: 52,
                                        child: AppImage(
                                          url: villa.imageUrls.isNotEmpty
                                              ? villa.imageUrls.first
                                              : 'assets/images/NDT05929-HDR1.jpg',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            villa.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textStrong,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Chủ nhà: ${villa.host?.fullName ?? 'Chủ nhà The Palm Villa'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
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
                            const SizedBox(height: AppSpacing.s16),
                            const Text(
                              'Câu hỏi thường gặp cho Chủ nhà:',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textStrong,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Column(
                              children: _quickQuestions.map((q) {
                                final isSelected = _msgCtrl.text.trim() == q;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        _msgCtrl.value = TextEditingValue(
                                          text: q,
                                          selection: TextSelection.collapsed(
                                            offset: q.length,
                                          ),
                                        );
                                      });
                                    },
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.surfaceBase,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.borderSoft,
                                            width: isSelected ? 1.2 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              LucideIcons.messageSquare,
                                              size: 15,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.iconStrong,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                q,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.35,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppColors.textStrong,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            const Text.rich(
                              TextSpan(
                                text: 'Nội dung tin nhắn gửi Chủ nhà ',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textStrong,
                                ),
                                children: [
                                  TextSpan(
                                    text: '*',
                                    style: TextStyle(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            TextField(
                              controller: _msgCtrl,
                              minLines: 3,
                              maxLines: 5,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: AppColors.textStrong,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Nhập câu hỏi của bạn về lịch trống, tiện nghi hoặc yêu cầu đặc biệt...',
                                hintStyle: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: AppColors.textMuted,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceBase,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderSoft,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderFocus,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
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
                                  minimumSize: const Size.fromHeight(48),
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: AppSpacing.s16,
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
