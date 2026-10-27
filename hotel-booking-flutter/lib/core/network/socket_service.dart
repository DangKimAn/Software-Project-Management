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

  static Duration _defaultBackoffDelay(int attempt) {
    final clamped = attempt.clamp(1, 6);
    return Duration(seconds: 1 << clamped); // 2s, 4s, 8s, 16s, 32s, 64s
  }

  /// Normalizes a raw JWT string by stripping any leading `Bearer ` prefix.
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
  static String buildConnectHandshakePacket(String token) {
    final cleanToken = normalizeToken(token);
    final authPayload = jsonEncode({'token': cleanToken});
    return '40$authPayload';
  }

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
  void handleRawPacketForTesting(String packet, {String token = 'test-token'}) {
    if (_isDisposed) return;
    final normalized = normalizeToken(token);
    _activeToken = normalized;
    _handlePacket(packet, normalized);
  }

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
