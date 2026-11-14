import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../security/secure_storage_service.dart';

typedef SocketChannelFactory = WebSocketChannel Function(Uri uri);
typedef ReconnectDelayBuilder = Duration Function(int attempt);

/// Real-time Socket.IO v4 / Engine.IO v4 client matching `frontend/src/services/socket/socketClient.ts`
/// and `backend/src/socket/socket.ts`.
///
/// Supports:
/// - Handshake authentication with JWT token (`40{"token":"..."}`) without leaking token in URL/logs
/// - Engine.IO ping (`2`) / pong (`3`) keep-alive
/// - `conversation:join`, `conversation:leave`, and `conversation:typing` room events
/// - Incoming `message:new`, `notification:new`, `conversation:error`, and `conversation:typing` events
/// - Single-flight connection guard, token refresh reconnection, and bounded exponential backoff
/// Dịch vụ kết nối thời gian thực theo giao thức Engine.IO v4 / Socket.IO v4 đồng bộ với máy chủ Backend.
///
/// Đảm nhiệm bắt tay xác thực JWT qua gói tin `40{"token":"..."}`, duy trì nhịp tim `2`/`3`, quản lý phòng hội thoại
/// và tự động kết nối lại theo cấp số nhân có giới hạn.
class SocketService {
  final SecureStorageService _secureStorage;
  final SocketChannelFactory _channelFactory;
  final Future<String?> Function()? _onTokenRefreshRequested;
  final int maxReconnectAttempts;
  final ReconnectDelayBuilder _reconnectDelayBuilder;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Future<void>? _connectingFuture;

  bool _isConnected = false;
  bool _manuallyDisconnected = false;
  bool _isDisposed = false;
  bool _isRefreshingToken = false;
  int _reconnectAttempts = 0;
  int _connectionEpoch = 0;
  String? _activeToken;
  String? _lastRejectedToken;
  final Set<String> _joinedConversations = <String>{};

  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _newNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationErrorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _connectErrorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();

  SocketService({
    SecureStorageService? secureStorage,
    SocketChannelFactory? channelFactory,
    Future<String?> Function()? onTokenRefreshRequested,
    this.maxReconnectAttempts = 6,
    ReconnectDelayBuilder? reconnectDelayBuilder,
  })  : _secureStorage = secureStorage ?? const SecureStorageService(),
        _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _onTokenRefreshRequested = onTokenRefreshRequested,
        _reconnectDelayBuilder = reconnectDelayBuilder ?? _defaultBackoffDelay;

  /// Tính độ trễ kết nối lại mặc định theo lũy thừa cơ số 2: `2^clamp(attempt, 1, 6)` giây (`2s, 4s, 8s, 16s, 32s, 64s`).
  static Duration _defaultBackoffDelay(int attempt) {
    final clamped = attempt.clamp(1, 6);
    return Duration(seconds: 1 << clamped); // 2s, 4s, 8s, 16s, 32s, 64s
  }

  /// Normalizes a raw JWT string by stripping any leading `Bearer ` prefix.
  /// Chuẩn hóa chuỗi JWT đầu vào bằng cách cắt khoảng trắng và loại bỏ tiền tố `Bearer ` không phân biệt hoa thường.
  static String normalizeToken(String? rawToken) {
    if (rawToken == null) return '';
    return rawToken
        .trim()
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  bool get isConnected => _isConnected;
  bool get isDisposed => _isDisposed;
  int get reconnectAttemptsForTesting => _reconnectAttempts;
  bool get hasPendingReconnectForTesting => _reconnectTimer?.isActive ?? false;
  String? get activeTokenForTesting => _activeToken;
  String? get lastRejectedTokenForTesting => _lastRejectedToken;
  Set<String> get joinedConversationsForTesting =>
      Set<String>.unmodifiable(_joinedConversations);

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageNew => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onNewNotification =>
      _newNotificationController.stream;
  Stream<Map<String, dynamic>> get onNotificationNew =>
      _newNotificationController.stream;
  Stream<Map<String, dynamic>> get onConversationError =>
      _conversationErrorController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onConnectError =>
      _connectErrorController.stream;
  Stream<void> get onConnected => _connectedController.stream;

  /// Builds the Engine.IO v4 WebSocket URI WITHOUT placing the JWT in the URL query string.
  /// Authentication is performed exclusively via the Socket.IO CONNECT handshake packet (`40{"token":"..."}`).
  /// Xây dựng `Uri` kết nối WebSocket chuẩn Engine.IO v4 (`/socket.io/?EIO=4&transport=websocket`), tuyệt đối không gắn JWT lên chuỗi truy vấn URL để chống lộ token trong nhật ký mạng.
  Uri buildSocketUri([String? overrideBaseUrl]) {
    final baseUri = Uri.tryParse(overrideBaseUrl ?? AppConfig.apiBaseUrl);
    final isSecure = baseUri?.scheme == 'https';
    final wsScheme = isSecure ? 'wss' : 'ws';
    final host = (baseUri != null && baseUri.host.isNotEmpty)
        ? baseUri.host
        : 'localhost';
    final port = baseUri?.hasPort == true ? baseUri!.port : null;

    return Uri(
      scheme: wsScheme,
      host: host,
      port: port,
      path: '/socket.io/',
      queryParameters: const {
        'EIO': '4',
        'transport': 'websocket',
      },
    );
  }

  /// Builds the Socket.IO v4 CONNECT packet carrying the handshake auth payload (`40{"token":"..."}`).
  /// Đóng gói khung tin bắt tay xác thực không gian tên gốc của Socket.IO v4 (`40{"token":"..."}`).
  static String buildConnectHandshakePacket(String token) {
    final cleanToken = normalizeToken(token);
    final authPayload = jsonEncode({'token': cleanToken});
    return '40$authPayload';
  }

  /// Mở kết nối WebSocket với khóa hợp nhất đơn luồng (`_connectingFuture`) nhằm ngăn mở trùng nhiều kênh song song.
  Future<void> connect({bool isAutoReconnect = false}) async {
    if (_isDisposed) return;
    if (_connectingFuture != null) {
      return _connectingFuture;
    }

    final future = _connectInternal(isAutoReconnect: isAutoReconnect);
    _connectingFuture = future;
    try {
      await future;
    } finally {
      if (identical(_connectingFuture, future)) {
        _connectingFuture = null;
      }
    }
  }

  /// Giải thuật thiết lập vòng đời phiên WebSocket nội bộ (`_connectInternal`):
  /// 1. Đọc JWT từ `SecureStorageService` và đối chiếu `_connectionEpoch`; nếu không có token thì ngắt kết nối sạch.
  /// 2. Chốt chặn chống lặp vô hạn: từ chối kết nối lại nếu `token` trùng khớp với `_lastRejectedToken` vừa bị máy chủ từ chối xác thực.
  /// 3. Nếu người dùng vừa đổi tài khoản hoặc xoay vòng token mới (`_activeToken != token`), đóng kênh cũ và đặt lại bộ đếm thử lại về `0`.
  /// 4. Tăng `_connectionEpoch`, khởi tạo kênh WebSocket và lắng nghe luồng khung tin văn bản chuyển cho `_handlePacket`.
  Future<void> _connectInternal({required bool isAutoReconnect}) async {
    if (_isDisposed) return;

    final epochAtStart = _connectionEpoch;
    final rawToken = await _secureStorage.getAuthToken();
    if (_isDisposed || epochAtStart != _connectionEpoch) return;

    final token = normalizeToken(rawToken);
    if (token.isEmpty) {
      if (_isConnected || _channel != null || _activeToken != null) {
        disconnect();
      }
      return;
    }

    // Prevent infinite reconnect loops with a token that was already rejected by the server.
    if (_lastRejectedToken != null && _lastRejectedToken == token) {
      return;
    }

    // If token changed (e.g. account switch or token refresh), tear down old socket first.
    if (_activeToken != null && _activeToken != token) {
      _closeCurrentChannel();
      _lastRejectedToken = null;
      _reconnectAttempts = 0;
    }

    if (_isConnected || _channel != null) return;

    if (!isAutoReconnect) {
      _reconnectAttempts = 0;
    }
    _manuallyDisconnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _activeToken = token;

    final channelEpoch = ++_connectionEpoch;

    try {
      final uri = buildSocketUri();
      final channel = _channelFactory(uri);
      _channel = channel;

      unawaited(
        channel.ready.then(
          (_) {},
          onError: (Object _) {
            if (channelEpoch == _connectionEpoch) {
              _handleDisconnect();
            }
          },
        ),
      );

      _subscription = channel.stream.listen(
        (dynamic raw) {
          if (channelEpoch != _connectionEpoch || _isDisposed) return;
          if (raw is String) {
            _handlePacket(raw, token);
          }
        },
        onError: (Object _) {
          if (channelEpoch != _connectionEpoch || _isDisposed) return;
          AppLogger.w('Socket.IO stream disconnected');
          _handleDisconnect();
        },
        onDone: () {
          if (channelEpoch != _connectionEpoch || _isDisposed) return;
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      AppLogger.w('Socket.IO connect failed');
      _handleDisconnect();
    }
  }

  /// Exposed for unit testing Engine.IO / Socket.IO packet frames without a live WebSocket.
  /// Điểm vào kiểm thử đơn vị cho phép bơm trực tiếp khung tin thô Engine.IO / Socket.IO mà không cần mở kết nối mạng thực.
  void handleRawPacketForTesting(String packet, {String token = 'test-token'}) {
    if (_isDisposed) return;
    final normalized = normalizeToken(token);
    _activeToken = normalized;
    _handlePacket(packet, normalized);
  }

  /// Giải thuật phân tích khung tin giao thức Engine.IO v4 / Socket.IO v4 (`_handlePacket`):
  /// 1. Khung `0...` (Engine.IO OPEN): Ngay khi mở kênh vận chuyển thành công, gửi trả gói bắt tay xác thực Socket.IO `40{"token":"..."}`.
  /// 2. Khung `1` (Engine.IO CLOSE): Máy chủ đóng kênh vận chuyển, chuyển sang `_handleDisconnect()` để dọn tài nguyên và xét lịch kết nối lại.
  /// 3. Khung `2...` / `3...` (Engine.IO PING / PONG): Phản hồi tức thì gói `3` giữ nhịp tim sống (heartbeat keep-alive) kèm tải trọng đối xứng nếu có.
  /// 4. Khung `41...` (Socket.IO SERVER DISCONNECT): Máy chủ ngắt không gian tên, hạ cờ `_isConnected` và đóng kênh hiện tại.
  /// 5. Khung `44...` (Socket.IO CONNECT ERROR): Ghi nhận `_lastRejectedToken` để chặn lặp kết nối mù, phát lỗi ra `onConnectError`, đóng kênh và kích hoạt `_handleAuthRejection` để xin làm mới JWT.
  /// 6. Khung `40...` (Socket.IO CONNECT ACK): Xác nhận kết nối thành công (`_isConnected = true`), đặt lại `_reconnectAttempts = 0` và tự động phát lại `conversation:join` cho toàn bộ phòng hội thoại đang theo dõi.
  /// 7. Khung `42["eventName", payload]` (Socket.IO EVENT): Giải mã mảng JSON hai phần tử và định tuyến sự kiện về các luồng phát sóng tương ứng (`message:new`, `notification:new`, `conversation:error` tự gỡ phòng bị từ chối quyền, `conversation:typing`).
  void _handlePacket(String packet, String token) {
    if (packet.isEmpty || _isDisposed) return;

    // Engine.IO OPEN ('0{...}') -> send Socket.IO CONNECT ('40{"token":"..."}')
    if (packet.startsWith('0')) {
      _sendRaw(buildConnectHandshakePacket(token));
      return;
    }

    // Engine.IO CLOSE ('1')
    if (packet == '1') {
      _handleDisconnect();
      return;
    }

    // Engine.IO PING ('2') -> reply PONG ('3')
    if (packet == '2' || packet.startsWith('2')) {
      _sendRaw('3${packet.substring(1)}');
      return;
    }

    // Engine.IO PONG ('3') -> keep-alive ack
    if (packet == '3' || packet.startsWith('3')) {
      return;
    }

    // Socket.IO SERVER DISCONNECT ('41')
    if (packet.startsWith('41')) {
      _isConnected = false;
      _closeCurrentChannel();
      return;
    }

    // Socket.IO CONNECT ERROR ('44{...}') e.g. Unauthorized / expired JWT
    if (packet.startsWith('44')) {
      _isConnected = false;
      _lastRejectedToken = token;
      Map<String, dynamic> errorPayload = <String, dynamic>{
        'message': 'Unauthorized',
      };
      final rawJson = packet.substring(2).trim();
      if (rawJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is Map) {
            errorPayload = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
      if (!_connectErrorController.isClosed) {
        _connectErrorController.add(errorPayload);
      }
      _closeCurrentChannel();
      unawaited(_handleAuthRejection(token));
      return;
    }

    // Socket.IO CONNECT ACK ('40{...}')
    if (packet.startsWith('40')) {
      _isConnected = true;
      _reconnectAttempts = 0;
      _lastRejectedToken = null;
      for (final convId in _joinedConversations) {
        final idNum = int.tryParse(convId);
        _emit('conversation:join', {'conversationId': idNum ?? convId});
      }
      if (!_connectedController.isClosed) {
        _connectedController.add(null);
      }
      return;
    }

    // Socket.IO EVENT ('42["eventName", payload]')
    if (packet.startsWith('42')) {
      final jsonPart = packet.substring(2);
      try {
        final decoded = jsonDecode(jsonPart);
        if (decoded is List && decoded.isNotEmpty) {
          final eventName = decoded[0]?.toString() ?? '';
          final payload = decoded.length > 1 && decoded[1] is Map
              ? Map<String, dynamic>.from(decoded[1] as Map)
              : <String, dynamic>{};

          switch (eventName) {
            case 'message:new':
              if (!_newMessageController.isClosed) {
                _newMessageController.add(payload);
              }
              break;
            case 'notification:new':
              if (!_newNotificationController.isClosed) {
                _newNotificationController.add(payload);
              }
              break;
            case 'conversation:error':
              final errorConvId =
                  payload['conversationId']?.toString().trim() ?? '';
              final errorMsg =
                  payload['message']?.toString().toLowerCase() ?? '';
              if (errorConvId.isNotEmpty &&
                  (errorMsg.contains('forbidden') ||
                      errorMsg.contains('invalid') ||
                      errorMsg.contains('unauthorized'))) {
                _joinedConversations.remove(errorConvId);
              }
              if (!_conversationErrorController.isClosed) {
                _conversationErrorController.add(payload);
              }
              break;
            case 'conversation:typing':
            case 'typing':
              if (!_typingController.isClosed) {
                _typingController.add(payload);
              }
              break;
          }
        }
      } catch (_) {
        // Ignore malformed event frame
      }
    }
  }

  /// Giải thuật phục hồi khi máy chủ từ chối JWT lúc bắt tay (`_handleAuthRejection`):
  /// Dùng cờ `_isRefreshingToken` đảm bảo chỉ gọi làm mới một lần, xin token mới qua `_onTokenRefreshRequested` (hoặc đọc lại kho bảo mật),
  /// và chỉ kết nối lại khi nhận được token mới khác với `rejectedToken`.
  Future<void> _handleAuthRejection(String rejectedToken) async {
    if (_isDisposed || _manuallyDisconnected || _isRefreshingToken) return;
    _isRefreshingToken = true;
    try {
      String? refreshedToken;
      final refreshCallback = _onTokenRefreshRequested;
      if (refreshCallback != null) {
        refreshedToken = normalizeToken(await refreshCallback());
      } else {
        refreshedToken = normalizeToken(await _secureStorage.getAuthToken());
      }
      if (_isDisposed || _manuallyDisconnected) return;
      if (refreshedToken.isNotEmpty && refreshedToken != rejectedToken) {
        _lastRejectedToken = null;
        await connect();
      }
    } catch (_) {
      // Do not loop when token refresh fails
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// Đăng ký tham gia phòng hội thoại `conversationId` (lưu vào `_joinedConversations` để tự động tham gia lại sau khi rớt mạng) và phát sự kiện `conversation:join`.
  void joinConversation(String conversationId) {
    if (_isDisposed) return;
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    final idNum = int.tryParse(normalized);
    if (idNum != null && idNum < 1) return;

    _joinedConversations.add(normalized);
    if (_isConnected) {
      _emit('conversation:join', {'conversationId': idNum ?? normalized});
    } else if (!_manuallyDisconnected) {
      unawaited(connect());
    }
  }

  /// Rời khỏi phòng hội thoại `conversationId`, xóa khỏi danh sách theo dõi và phát sự kiện `conversation:leave` nếu đang kết nối.
  void leaveConversation(String conversationId) {
    if (_isDisposed) return;
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    _joinedConversations.remove(normalized);
    if (_isConnected) {
      final idNum = int.tryParse(normalized);
      _emit('conversation:leave', {'conversationId': idNum ?? normalized});
    }
  }

  /// Phát trạng thái đang gõ phím (`conversation:typing`) vào phòng hội thoại `conversationId` khi kênh đang kết nối.
  void sendTyping(String conversationId, {required bool isTyping}) {
    if (_isDisposed || !_isConnected) return;
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    final idNum = int.tryParse(normalized);
    _emit('conversation:typing', {
      'conversationId': idNum ?? normalized,
      'isTyping': isTyping,
    });
  }

  void _emit(String event, Map<String, dynamic> data) {
    final encoded = jsonEncode([event, data]);
    _sendRaw('42$encoded');
  }

  void _sendRaw(String frame) {
    try {
      _channel?.sink.add(frame);
    } catch (_) {
      // Ignore sink errors when disconnected
    }
  }

  void _closeCurrentChannel() {
    _isConnected = false;
    final sub = _subscription;
    _subscription = null;
    sub?.cancel();
    final ch = _channel;
    _channel = null;
    try {
      ch?.sink.close();
    } catch (_) {}
  }

  void _handleDisconnect() {
    _closeCurrentChannel();
    if (!_manuallyDisconnected && !_isDisposed) {
      _scheduleReconnect();
    }
  }

  /// Giải thuật lên lịch kết nối lại tự động theo cấp số nhân (`_scheduleReconnect`):
  /// Hủy lịch nếu người dùng đã ngắt thủ công, đối tượng đã hủy, token đang bị từ chối hoặc số lần thử đã chạm trần `maxReconnectAttempts`;
  /// ngược lại tăng `_reconnectAttempts` và đặt hẹn giờ theo `_reconnectDelayBuilder`.
  void _scheduleReconnect() {
    if (_manuallyDisconnected || _isDisposed) return;
    if (_activeToken != null && _activeToken == _lastRejectedToken) {
      return;
    }
    if (_reconnectAttempts >= maxReconnectAttempts) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectAttempts = _reconnectAttempts + 1;
    final delay = _reconnectDelayBuilder(_reconnectAttempts);
    _reconnectTimer = Timer(delay, () {
      if (!_manuallyDisconnected && !_isConnected && !_isDisposed) {
        unawaited(connect(isAutoReconnect: true));
      }
    });
  }

  /// Updates the auth token or reconnects when the session token changes.
  /// Đồng bộ JWT mới sau khi làm mới phiên: nếu token trống thì ngắt kết nối, nếu token thay đổi hoặc kênh đang đóng thì mở lại kết nối mới.
  Future<void> refreshAuthToken([String? newToken]) async {
    if (_isDisposed) return;
    final rawToken = newToken ?? await _secureStorage.getAuthToken();
    final token = normalizeToken(rawToken);
    if (token.isEmpty) {
      disconnect();
      return;
    }
    _lastRejectedToken = null;
    _reconnectAttempts = 0;
    if (_activeToken != token || !_isConnected) {
      _closeCurrentChannel();
      await connect();
    }
  }

  /// Ngắt kết nối chủ động khi đăng xuất: tăng `_connectionEpoch`, hủy hẹn giờ thử lại, xóa danh sách phòng hội thoại và đóng kênh WebSocket.
  void disconnect() {
    _connectionEpoch++;
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _activeToken = null;
    _lastRejectedToken = null;
    _joinedConversations.clear();
    _closeCurrentChannel();
  }

  /// Giải phóng vĩnh viễn dịch vụ Socket, ngắt kết nối hiện tại và đóng toàn bộ các `StreamController` phát sự kiện.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _newMessageController.close();
    _newNotificationController.close();
    _conversationErrorController.close();
    _typingController.close();
    _connectErrorController.close();
    _connectedController.close();
  }
}
