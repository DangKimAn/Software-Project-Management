import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../security/secure_storage_service.dart';

/// Real-time Socket.IO v4 / Engine.IO v4 client matching `frontend/src/services/socket/socketClient.ts`
/// and `backend/src/socket/socket.ts`.
///
/// Supports:
/// - Handshake authentication with JWT token (`40{"token":"..."}`)
/// - Engine.IO ping (`2`) / pong (`3`) keep-alive
/// - `conversation:join` and `conversation:leave` room events
/// - Incoming `message:new`, `notification:new`, and `conversation:error` events
/// - Automatic reconnect with backoff and clean listener disposal
class SocketService {
  final SecureStorageService _secureStorage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _manuallyDisconnected = false;
  int _reconnectAttempts = 0;
  String? _activeToken;
  final Set<String> _joinedConversations = <String>{};

  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _newNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _conversationErrorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();

  SocketService({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? const SecureStorageService();

  bool get isConnected => _isConnected;
  String? get activeTokenForTesting => _activeToken;
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
    final authPayload = jsonEncode({'token': token});
    return '40$authPayload';
  }

  Future<void> connect() async {
    final rawToken = await _secureStorage.getAuthToken();
    final token = rawToken?.trim();
    if (token == null || token.isEmpty) {
      if (_isConnected || _channel != null || _activeToken != null) {
        disconnect();
      }
      return;
    }

    // If token changed (e.g. account switch or token refresh), tear down old socket first.
    if (_activeToken != null && _activeToken != token) {
      _closeCurrentChannel();
    }

    if (_isConnected || _channel != null) return;
    _manuallyDisconnected = false;
    _activeToken = token;

    try {
      final uri = buildSocketUri();
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      unawaited(
        channel.ready.then(
          (_) {},
          onError: (Object _) {
            _handleDisconnect();
          },
        ),
      );

      _subscription = channel.stream.listen(
        (dynamic raw) {
          if (raw is String) {
            _handlePacket(raw, token);
          }
        },
        onError: (Object _) {
          AppLogger.w('Socket.IO stream disconnected');
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      AppLogger.w('Socket.IO connect failed');
      _scheduleReconnect();
    }
  }

  /// Exposed for unit testing Engine.IO / Socket.IO packet frames without a live WebSocket.
  void handleRawPacketForTesting(String packet, {String token = 'test-token'}) {
    _activeToken = token;
    _handlePacket(packet, token);
  }

  void _handlePacket(String packet, String token) {
    if (packet.isEmpty) return;

    // Engine.IO OPEN ('0{...}') -> send Socket.IO CONNECT ('40{"token":"..."}')
    if (packet.startsWith('0')) {
      _sendRaw(buildConnectHandshakePacket(token));
      return;
    }

    // Engine.IO PING ('2') -> reply PONG ('3')
    if (packet == '2' || packet.startsWith('2')) {
      _sendRaw('3${packet.substring(1)}');
      return;
    }

    // Socket.IO CONNECT ERROR ('44{...}')
    if (packet.startsWith('44')) {
      _isConnected = false;
      return;
    }

    // Socket.IO CONNECT ACK ('40{...}')
    if (packet.startsWith('40')) {
      _isConnected = true;
      _reconnectAttempts = 0;
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
              if (!_conversationErrorController.isClosed) {
                _conversationErrorController.add(payload);
              }
              break;
          }
        }
      } catch (_) {
        // Ignore malformed event frame
      }
    }
  }

  void joinConversation(String conversationId) {
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    _joinedConversations.add(normalized);
    if (_isConnected) {
      final idNum = int.tryParse(normalized);
      _emit('conversation:join', {'conversationId': idNum ?? normalized});
    } else {
      connect();
    }
  }

  void leaveConversation(String conversationId) {
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    _joinedConversations.remove(normalized);
    if (_isConnected) {
      final idNum = int.tryParse(normalized);
      _emit('conversation:leave', {'conversationId': idNum ?? normalized});
    }
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
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _handleDisconnect() {
    _closeCurrentChannel();
    if (!_manuallyDisconnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyDisconnected) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 6);
    final delaySeconds = 1 << _reconnectAttempts; // 2s, 4s, 8s, 16s, 32s, 64s
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_manuallyDisconnected && !_isConnected) {
        connect();
      }
    });
  }

  /// Updates the auth token or reconnects when the session token changes.
  Future<void> refreshAuthToken() async {
    final token = (await _secureStorage.getAuthToken())?.trim();
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }
    if (_activeToken != token) {
      _closeCurrentChannel();
      await connect();
    }
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _activeToken = null;
    _joinedConversations.clear();
    _closeCurrentChannel();
  }

  void dispose() {
    disconnect();
    _newMessageController.close();
    _newNotificationController.close();
    _conversationErrorController.close();
    _connectedController.close();
  }
}
