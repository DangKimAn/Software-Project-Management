import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/network/socket_service.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? token;

  _FakeSecureStorage([this.token]);

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<void> saveAuthToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAuthToken() async {
    token = null;
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentFrames = <dynamic>[];
  final void Function() onClosed;
  bool isClosed = false;

  _FakeWebSocketSink({required this.onClosed});

  @override
  void add(dynamic data) {
    if (isClosed) return;
    sentFrames.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {
    await for (final item in stream) {
      add(item);
    }
  }

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    if (!isClosed) {
      isClosed = true;
      onClosed();
    }
  }

  @override
  Future<dynamic> get done => Future<void>.value();
}

class _FakeWebSocketChannel implements WebSocketChannel {
  final Uri uri;
  final StreamController<dynamic> serverToClientController =
      StreamController<dynamic>.broadcast();
  late final _FakeWebSocketSink fakeSink;
  final Completer<void> readyCompleter = Completer<void>();

  _FakeWebSocketChannel(this.uri, {bool autoReady = true}) {
    fakeSink = _FakeWebSocketSink(onClosed: () {});
    if (autoReady) {
      readyCompleter.complete();
    }
  }

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => readyCompleter.future;

  @override
  Stream<dynamic> get stream => serverToClientController.stream;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void emitFromServer(String packet) {
    if (!serverToClientController.isClosed) {
      serverToClientController.add(packet);
    }
  }

  void simulateNetworkDrop([Object? error]) {
    if (!serverToClientController.isClosed) {
      if (error != null) {
        serverToClientController.addError(error);
      }
      serverToClientController.close();
    }
  }
}

void main() {
  group('SocketService — Handshake, Security, Lifecycle & Reconnect', () {
    test(
      '1. buildSocketUri excludes token from query URL and buildConnectHandshakePacket strips Bearer prefix',
      () {
        const rawJwt =
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig';
        const cleanJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.sig';
        final storage = _FakeSecureStorage(rawJwt);
        final service = SocketService(secureStorage: storage);

        final httpsUri =
            service.buildSocketUri('https://api.minhthanhvilla.com/api');
        expect(httpsUri.scheme, 'wss');
        expect(httpsUri.host, 'api.minhthanhvilla.com');
        expect(httpsUri.path, '/socket.io/');
        expect(httpsUri.queryParameters, {
          'EIO': '4',
          'transport': 'websocket',
        });
        expect(httpsUri.toString().contains(cleanJwt), isFalse);
        expect(httpsUri.queryParameters.containsKey('token'), isFalse);

        final httpUri = service.buildSocketUri('http://localhost:5000');
        expect(httpUri.scheme, 'ws');
        expect(httpUri.port, 5000);

        final packet = SocketService.buildConnectHandshakePacket(rawJwt);
        expect(packet, '40{"token":"$cleanJwt"}');
        service.dispose();
      },
    );

    test(
      '2. Engine.IO OPEN -> Socket.IO CONNECT handshake -> PING/PONG -> ACK & room join/leave',
      () async {
        final channels = <_FakeWebSocketChannel>[];
        final storage = _FakeSecureStorage('jwt-user-10');
        final service = SocketService(
          secureStorage: storage,
          channelFactory: (uri) {
            final ch = _FakeWebSocketChannel(uri);
            channels.add(ch);
            return ch;
          },
        );

        var connectedEvents = 0;
        final sub = service.onConnected.listen((_) => connectedEvents++);

        // Concurrent connect() calls must coalesce into a single WebSocket channel
        await Future.wait([
          service.connect(),
          service.connect(),
          service.connect(),
        ]);
        expect(channels.length, 1);

        final channel = channels.single;
        service.joinConversation('42');
        expect(service.joinedConversationsForTesting, contains('42'));

        // Server sends Engine.IO OPEN ('0{...}')
        channel.emitFromServer(
          '0{"sid":"engine-1","upgrades":[],"pingInterval":25000,"pingTimeout":20000}',
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          channel.fakeSink.sentFrames,
          contains('40{"token":"jwt-user-10"}'),
        );

        // Server sends Engine.IO PING ('2') -> client replies PONG ('3')
        channel.emitFromServer('2');
        await Future<void>.delayed(Duration.zero);
        expect(channel.fakeSink.sentFrames, contains('3'));

        // Server sends Socket.IO CONNECT ACK ('40{"sid":"socket-1"}')
        channel.emitFromServer('40{"sid":"socket-1"}');
        await Future<void>.delayed(Duration.zero);
        expect(service.isConnected, isTrue);
        expect(connectedEvents, 1);
        expect(
          channel.fakeSink.sentFrames,
          contains('42["conversation:join",{"conversationId":42}]'),
        );

        // Typing indicator emit
        service.sendTyping('42', isTyping: true);
        expect(
          channel.fakeSink.sentFrames,
          contains(
            '42["conversation:typing",{"conversationId":42,"isTyping":true}]',
          ),
        );

        // Leave conversation
        service.leaveConversation('42');
        expect(service.joinedConversationsForTesting, isNot(contains('42')));
        expect(
          channel.fakeSink.sentFrames,
          contains('42["conversation:leave",{"conversationId":42}]'),
        );

        await sub.cancel();
        service.dispose();
      },
    );

    test(
      '3. Token refresh tears down old channel, reconnects with new token, and re-joins rooms; logout clears state',
      () async {
        final channels = <_FakeWebSocketChannel>[];
        final storage = _FakeSecureStorage('jwt-v1');
        final service = SocketService(
          secureStorage: storage,
          channelFactory: (uri) {
            final ch = _FakeWebSocketChannel(uri);
            channels.add(ch);
            return ch;
          },
        );

        service.joinConversation('88');
        await service.connect();
        expect(channels.length, 1);

        channels[0].emitFromServer('0{"sid":"e1"}');
        channels[0].emitFromServer('40{"sid":"s1"}');
        await Future<void>.delayed(Duration.zero);
        expect(service.isConnected, isTrue);
        expect(service.activeTokenForTesting, 'jwt-v1');

        // Rotate token in storage and trigger refreshAuthToken()
        storage.token = 'jwt-v2';
        await service.refreshAuthToken();
        expect(channels[0].fakeSink.isClosed, isTrue);
        expect(channels.length, 2);

        channels[1].emitFromServer('0{"sid":"e2"}');
        channels[1].emitFromServer('40{"sid":"s2"}');
        await Future<void>.delayed(Duration.zero);

        expect(service.isConnected, isTrue);
        expect(service.activeTokenForTesting, 'jwt-v2');
        expect(
          channels[1].fakeSink.sentFrames,
          contains('40{"token":"jwt-v2"}'),
        );
        expect(
          channels[1].fakeSink.sentFrames,
          contains('42["conversation:join",{"conversationId":88}]'),
        );

        // Logout clears token and disconnects
        storage.token = null;
        await service.refreshAuthToken();
        expect(service.isConnected, isFalse);
        expect(service.activeTokenForTesting, isNull);
        expect(service.joinedConversationsForTesting, isEmpty);
        expect(channels[1].fakeSink.isClosed, isTrue);

        service.dispose();
      },
    );

    test(
      '4. 401/Unauthorized Socket.IO CONNECT ERROR (44) stops infinite loop and supports single token refresh recovery',
      () async {
        final channels = <_FakeWebSocketChannel>[];
        final storage = _FakeSecureStorage('expired-jwt');
        var refreshCalls = 0;

        final service = SocketService(
          secureStorage: storage,
          reconnectDelayBuilder: (_) => const Duration(milliseconds: 20),
          onTokenRefreshRequested: () async {
            refreshCalls++;
            if (refreshCalls == 1) {
              // First rejection: refresh fails (returns same expired token)
              return 'expired-jwt';
            }
            storage.token = 'fresh-jwt';
            return 'fresh-jwt';
          },
          channelFactory: (uri) {
            final ch = _FakeWebSocketChannel(uri);
            channels.add(ch);
            return ch;
          },
        );

        final connectErrors = <Map<String, dynamic>>[];
        final errSub = service.onConnectError.listen(connectErrors.add);

        await service.connect();
        expect(channels.length, 1);

        // Server rejects handshake with 44{"message":"Unauthorized"}
        channels[0].emitFromServer('0{"sid":"e1"}');
        channels[0].emitFromServer('44{"message":"Unauthorized"}');
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(service.isConnected, isFalse);
        expect(connectErrors.length, 1);
        expect(connectErrors.first['message'], 'Unauthorized');
        expect(service.lastRejectedTokenForTesting, 'expired-jwt');
        // Must NOT open new channels in an infinite loop with the same rejected token
        expect(channels.length, 1);
        expect(service.hasPendingReconnectForTesting, isFalse);

        // Once a new token is available via refreshAuthToken, connection succeeds
        storage.token = 'fresh-jwt';
        await service.refreshAuthToken();
        expect(channels.length, 2);
        channels[1].emitFromServer('0{"sid":"e2"}');
        channels[1].emitFromServer('40{"sid":"s2"}');
        await Future<void>.delayed(Duration.zero);
        expect(service.isConnected, isTrue);
        expect(service.lastRejectedTokenForTesting, isNull);

        await errSub.cancel();
        service.dispose();
      },
    );

    test(
      '5. Network drop triggers bounded exponential backoff reconnect and re-joins rooms; Forbidden conversation:error removes room',
      () async {
        final channels = <_FakeWebSocketChannel>[];
        final storage = _FakeSecureStorage('valid-jwt');
        final service = SocketService(
          secureStorage: storage,
          maxReconnectAttempts: 3,
          reconnectDelayBuilder: (_) => const Duration(milliseconds: 25),
          channelFactory: (uri) {
            final ch = _FakeWebSocketChannel(uri);
            channels.add(ch);
            return ch;
          },
        );

        final convErrors = <Map<String, dynamic>>[];
        final errSub = service.onConversationError.listen(convErrors.add);

        service.joinConversation('100');
        service.joinConversation('999');
        await service.connect();
        expect(channels.length, 1);

        channels[0].emitFromServer('0{"sid":"e1"}');
        channels[0].emitFromServer('40{"sid":"s1"}');
        await Future<void>.delayed(Duration.zero);
        expect(service.isConnected, isTrue);

        // Server rejects room 999 with Forbidden
        channels[0].emitFromServer(
          '42["conversation:error",{"conversationId":999,"message":"Forbidden"}]',
        );
        await Future<void>.delayed(Duration.zero);
        expect(convErrors.length, 1);
        // Room 999 must be removed so reconnect does not try to join 999 again
        expect(service.joinedConversationsForTesting, contains('100'));
        expect(service.joinedConversationsForTesting, isNot(contains('999')));

        // Simulate network drop on channel 0
        channels[0].simulateNetworkDrop(StateError('Socket closed by peer'));
        for (var i = 0; i < 25 && channels.length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }

        // Reconnect opened channel 1
        expect(channels.length, 2);
        channels[1].emitFromServer('0{"sid":"e2"}');
        channels[1].emitFromServer('40{"sid":"s2"}');
        await Future<void>.delayed(Duration.zero);

        expect(service.isConnected, isTrue);
        expect(
          channels[1].fakeSink.sentFrames,
          contains('42["conversation:join",{"conversationId":100}]'),
        );
        expect(
          channels[1].fakeSink.sentFrames,
          isNot(contains('42["conversation:join",{"conversationId":999}]')),
        );

        await errSub.cancel();
        service.dispose();
      },
    );
  });
}
