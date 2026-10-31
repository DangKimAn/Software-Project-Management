import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/theme/app_colors.dart';
import '../../shared/widgets/app_header_footer.dart';
import '../logging/app_logger.dart';
import '../network/socket_service.dart';
import 'device_token_repository.dart';

/// Top-level background FCM handler invoked by Android/iOS when a push arrives
/// while the application is backgrounded or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Safely ignore if Firebase resources are not bundled for the current build flavor.
  }
}

class PushNotificationTapEvent {
  final String route;
  final String? notificationId;

  const PushNotificationTapEvent({
    required this.route,
    this.notificationId,
  });
}

typedef LocalBannerPresenter = Future<void> Function({
  required int id,
  required String title,
  required String body,
  String? payload,
});

/// Coordinates Android/iOS Firebase Cloud Messaging (FCM) push notifications,
/// Android 13+ notification permissions, foreground heads-up banners via
/// `flutter_local_notifications`, Socket.IO deduplicated fallback banners,
/// device token registration, and tap-to-route navigation.
class PushNotificationService {
  static const String androidChannelId = 'minh_thanh_villa_high_importance';
  static const String androidChannelName = 'Thông báo đặt phòng & tin nhắn';
  static const String androidChannelDescription =
      'Nhận thông báo xác nhận đặt phòng, thanh toán và tin nhắn mới';

  static const Duration _dedupeTtl = Duration(minutes: 2);
  static const int _maxDedupeEntries = 100;

  final DeviceTokenRepository _deviceTokenRepository;
  final SocketService? _socketService;
  final bool _enableNativePlugins;
  final Future<String?> Function()? _tokenProviderOverride;
  final LocalBannerPresenter? _localBannerOverride;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<PushNotificationTapEvent> _tapController =
      StreamController<PushNotificationTapEvent>.broadcast();
  final StreamController<void> _foregroundPushController =
      StreamController<void>.broadcast();

  final Map<String, DateTime> _recentDedupeKeys = <String, DateTime>{};

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  StreamSubscription<Map<String, dynamic>>? _socketNotifSub;
  StreamSubscription<Map<String, dynamic>>? _socketMessageSub;

  PushNotificationTapEvent? _pendingInitialTap;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _fcmAvailable = false;
  bool _localNotificationsReady = false;

  String? _activeUserId;
  String? _currentFcmToken;
  String? _lastSyncedUserId;
  String? _lastSyncedToken;

  PushNotificationService({
    required DeviceTokenRepository deviceTokenRepository,
    SocketService? socketService,
    bool? enableNativePlugins,
    Future<String?> Function()? tokenProviderOverride,
    LocalBannerPresenter? localBannerOverride,
  })  : _deviceTokenRepository = deviceTokenRepository,
        _socketService = socketService,
        _enableNativePlugins = enableNativePlugins ?? _defaultEnableNative(),
        _tokenProviderOverride = tokenProviderOverride,
        _localBannerOverride = localBannerOverride;

  static bool _defaultEnableNative() {
    if (kIsWeb) return false;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return false;
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (bindingName.contains('Test')) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  Stream<PushNotificationTapEvent> get onNotificationTap =>
      _tapController.stream;
  Stream<void> get onForegroundPush => _foregroundPushController.stream;

  /// Consumes any cold-start notification tap captured before the UI listener attached.
  PushNotificationTapEvent? takePendingInitialTap() {
    final pending = _pendingInitialTap;
    _pendingInitialTap = null;
    return pending;
  }

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;
    _isInitialized = true;

    _attachSocketListeners();

    if (!_enableNativePlugins) {
      return;
    }

    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
  }

  void _attachSocketListeners() {
    final socket = _socketService;
    if (socket == null) return;

    _socketNotifSub = socket.onNotificationNew.listen((payload) {
      if (_isDisposed || _activeUserId == null) return;
      final item = AppNotificationItem.fromJson(payload);
      final dedupeKey = item.id.isNotEmpty
          ? 'notif:${item.id}'
          : 'notif:${item.eventType}:${item.targetId ?? ''}:${item.title}';
      if (_markIfDuplicate(dedupeKey)) return;

      final route = item.resolveInternalRoute();
      final encodedPayload = jsonEncode(<String, dynamic>{
        if (route != null && route.isNotEmpty) 'route': route,
        if (item.id.isNotEmpty) 'notificationId': item.id,
      });

      unawaited(
        _showLocalBanner(
          id: _stableNotificationId(dedupeKey),
          title: item.title,
          body: item.body,
          payload: encodedPayload,
        ),
      );
    });

    _socketMessageSub = socket.onMessageNew.listen((payload) {
      if (_isDisposed || _activeUserId == null) return;
      final rawMsg = payload['message'];
      final msgMap = rawMsg is Map
          ? Map<String, dynamic>.from(rawMsg)
          : <String, dynamic>{};
      final senderId = (msgMap['senderUserId'] ??
              msgMap['senderId'] ??
              payload['senderUserId'] ??
              '')
          .toString()
          .trim();
      if (senderId.isNotEmpty && senderId == _activeUserId) {
        return;
      }

      final messageId = (msgMap['messageId'] ?? msgMap['id'] ?? '').toString();
      final convId =
          (payload['conversationId'] ?? msgMap['conversationId'] ?? '')
              .toString()
              .trim();
      final dedupeKey = messageId.isNotEmpty
          ? 'msg:$messageId'
          : 'msg:$convId:${msgMap['content'] ?? ''}';
      if (_markIfDuplicate(dedupeKey)) return;

      final content = (msgMap['content'] ?? msgMap['body'] ?? '').toString();
      final route =
          convId.isNotEmpty ? '/tin-nhan?conversationId=$convId' : '/tin-nhan';
      final encodedPayload = jsonEncode(<String, dynamic>{
        'route': route,
      });

      unawaited(
        _showLocalBanner(
          id: _stableNotificationId(dedupeKey),
          title: 'Tin nhắn mới',
          body: content.isNotEmpty ? content : 'Bạn có một tin nhắn mới.',
          payload: encodedPayload,
        ),
      );
    });
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            androidChannelId,
            androidChannelName,
            description: androidChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
      }

      _localNotificationsReady = true;
    } catch (e) {
      AppLogger.w('Local notifications initialization skipped: $e');
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcmAvailable = true;

      _onMessageSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage);
      _onMessageOpenedSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFcmMessage);
      _onTokenRefreshSub = messaging.onRegistered.listen((registeredFid) {
        _currentFcmToken = registeredFid.trim();
        if (_activeUserId != null && _activeUserId!.isNotEmpty) {
          unawaited(_registerTokenIfNeeded(_activeUserId!, force: true));
        }
      });
      await messaging.register();

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedFcmMessage(initialMessage, isInitialLaunch: true);
      }

      if (_activeUserId != null && _activeUserId!.isNotEmpty) {
        await _registerTokenIfNeeded(_activeUserId!);
      }
    } catch (e) {
      _fcmAvailable = false;
      AppLogger.w('Firebase Cloud Messaging unavailable on this build: $e');
    }
  }

  void _handleForegroundFcmMessage(RemoteMessage message) {
    if (_isDisposed) return;

    if (!_foregroundPushController.isClosed) {
      _foregroundPushController.add(null);
    }

    final data = Map<String, dynamic>.from(message.data);
    final notifId = (data['notificationLogId'] ?? data['id'] ?? '').toString();
    final msgId = (data['messageId'] ?? '').toString();
    final dedupeKey = notifId.isNotEmpty
        ? 'notif:$notifId'
        : msgId.isNotEmpty
            ? 'msg:$msgId'
            : (message.messageId != null && message.messageId!.isNotEmpty)
                ? 'fcm:${message.messageId}'
                : 'fcm:${message.notification?.title ?? ''}:${message.notification?.body ?? ''}';

    if (_markIfDuplicate(dedupeKey)) return;

    // On Android, FCM does not display system banners automatically while the
    // app is in the foreground; show a heads-up banner via local notifications.
    if (defaultTargetPlatform == TargetPlatform.android ||
        _localBannerOverride != null) {
      final title = AppNotificationItem.normalizeBrandText(
        message.notification?.title ??
            data['title']?.toString() ??
            'Thông báo mới',
      );
      final body = AppNotificationItem.normalizeBrandText(
        message.notification?.body ?? data['body']?.toString() ?? '',
      );
      final route = resolveRouteFromPushData(data);
      final encodedPayload = jsonEncode(<String, dynamic>{
        if (route != null && route.isNotEmpty) 'route': route,
        if (notifId.isNotEmpty) 'notificationId': notifId,
      });

      unawaited(
        _showLocalBanner(
          id: _stableNotificationId(dedupeKey),
          title: title,
          body: body,
          payload: encodedPayload,
        ),
      );
    }
  }

  void _handleOpenedFcmMessage(
    RemoteMessage message, {
    bool isInitialLaunch = false,
  }) {
    if (_isDisposed) return;
    final data = Map<String, dynamic>.from(message.data);
    final route = resolveRouteFromPushData(data);
    final notifId = (data['notificationLogId'] ?? data['id'])?.toString();
    if (route == null || route.isEmpty) return;

    final event = PushNotificationTapEvent(
      route: route,
      notificationId: (notifId != null && notifId.trim().isNotEmpty)
          ? notifId.trim()
          : null,
    );

    if (isInitialLaunch && !_tapController.hasListener) {
      _pendingInitialTap = event;
      return;
    }
    if (!_tapController.isClosed) {
      _tapController.add(event);
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (_isDisposed) return;
    final raw = response.payload;
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final candidateRoute = map['route']?.toString().trim() ?? '';
        final notifId = map['notificationId']?.toString().trim();
        if (candidateRoute.isNotEmpty &&
            AppNotificationItem.isSafeInternalRoute(candidateRoute)) {
          if (!_tapController.isClosed) {
            _tapController.add(
              PushNotificationTapEvent(
                route: candidateRoute,
                notificationId:
                    (notifId != null && notifId.isNotEmpty) ? notifId : null,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Ignore malformed notification payload
    }
  }

  Future<void> _showLocalBanner({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final override = _localBannerOverride;
    if (override != null) {
      await override(id: id, title: title, body: body, payload: payload);
      return;
    }
    if (!_localNotificationsReady) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        color: AppColors.primary,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: payload,
      );
    } catch (_) {
      // Never fail foreground UI flow if OS blocks notification banner
    }
  }

  /// Synchronizes the active authenticated user's FCM token with Backend.
  Future<void> syncAuthenticatedUser(String? userId) async {
    if (_isDisposed) return;
    final normalizedUser = userId?.trim();
    if (normalizedUser == null || normalizedUser.isEmpty) {
      _activeUserId = null;
      return;
    }
    _activeUserId = normalizedUser;
    await _registerTokenIfNeeded(normalizedUser);
  }

  Future<void> _registerTokenIfNeeded(
    String userId, {
    bool force = false,
  }) async {
    String? token = _currentFcmToken;
    try {
      final tokenOverride = _tokenProviderOverride;
      if (tokenOverride != null) {
        token = (await tokenOverride())?.trim();
      } else if (_fcmAvailable && (token == null || token.isEmpty)) {
        await FirebaseMessaging.instance.register();
        token = _currentFcmToken;
      }
    } catch (_) {
      return;
    }

    if (token == null || token.isEmpty) return;
    _currentFcmToken = token;

    if (!force && _lastSyncedUserId == userId && _lastSyncedToken == token) {
      return;
    }

    final platformName =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    try {
      await _deviceTokenRepository.registerToken(
        token: token,
        platform: platformName,
        appFlavor: appFlavor,
      );
      _lastSyncedUserId = userId;
      _lastSyncedToken = token;
    } catch (_) {
      // Will automatically retry on next app resume or auth check
    }
  }

  /// Deactivates the current device's FCM token on Backend BEFORE logout clears the JWT,
  /// and purges local notification banners + native FCM token state.
  Future<void> unregisterCurrentDevice() async {
    final token = _currentFcmToken ?? _lastSyncedToken;
    _activeUserId = null;
    _lastSyncedUserId = null;
    _lastSyncedToken = null;
    _currentFcmToken = null;
    _recentDedupeKeys.clear();

    if (token != null && token.trim().isNotEmpty) {
      try {
        await _deviceTokenRepository.unregisterToken(token: token.trim());
      } catch (_) {
        // Never block user logout if network is offline
      }
    }

    await _purgeDeviceNotificationState();
  }

  Future<void> _purgeDeviceNotificationState() async {
    if (_localNotificationsReady) {
      try {
        await _localNotifications.cancelAll();
      } catch (_) {}
    }
    if (_fcmAvailable) {
      try {
        await FirebaseMessaging.instance.unregister();
      } catch (_) {}
    }
  }

  void clearLocalSyncState() {
    _activeUserId = null;
    _lastSyncedUserId = null;
    _lastSyncedToken = null;
  }

  /// Resolves a safe internal GoRouter destination from an incoming FCM `data` map.
  static String? resolveRouteFromPushData(Map<String, dynamic> rawData) {
    Map<String, dynamic>? nestedPayload;
    final rawPayloadJson = rawData['payloadJson'];
    if (rawPayloadJson is String && rawPayloadJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayloadJson);
        if (decoded is Map) {
          nestedPayload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    } else if (rawData['payload'] is Map) {
      nestedPayload = Map<String, dynamic>.from(rawData['payload'] as Map);
    }

    final mergedPayload = <String, dynamic>{
      if (nestedPayload != null) ...nestedPayload,
      ...rawData,
    };

    final item = AppNotificationItem.fromJson(<String, dynamic>{
      'id': rawData['notificationLogId'] ?? rawData['id'] ?? '',
      'eventType': rawData['eventType'] ?? '',
      'targetType': rawData['targetType'],
      'targetId': rawData['targetId'],
      'title': rawData['title'] ?? '',
      'body': rawData['body'] ?? '',
      'actionUrl': rawData['actionUrl'],
      'payload': mergedPayload,
    });

    return item.resolveInternalRoute();
  }

  /// Exposed for unit testing deduplication and local banner triggers.
  @visibleForTesting
  Future<void> handleFcmDataForTesting({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final normalizedTitle = AppNotificationItem.normalizeBrandText(title);
    final normalizedBody = AppNotificationItem.normalizeBrandText(body);
    final notifId = (data['notificationLogId'] ?? data['id'] ?? '').toString();
    final msgId = (data['messageId'] ?? '').toString();
    final dedupeKey = notifId.isNotEmpty
        ? 'notif:$notifId'
        : msgId.isNotEmpty
            ? 'msg:$msgId'
            : 'fcm:$normalizedTitle:$normalizedBody';
    if (_markIfDuplicate(dedupeKey)) return;

    final route = resolveRouteFromPushData(data);
    final encodedPayload = jsonEncode(<String, dynamic>{
      if (route != null && route.isNotEmpty) 'route': route,
      if (notifId.isNotEmpty) 'notificationId': notifId,
    });

    await _showLocalBanner(
      id: _stableNotificationId(dedupeKey),
      title: normalizedTitle,
      body: normalizedBody,
      payload: encodedPayload,
    );
  }

  bool _markIfDuplicate(String key) {
    final now = DateTime.now();
    _recentDedupeKeys.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _dedupeTtl,
    );

    final existing = _recentDedupeKeys[key];
    if (existing != null && now.difference(existing) <= _dedupeTtl) {
      return true;
    }

    if (_recentDedupeKeys.length >= _maxDedupeEntries) {
      _recentDedupeKeys.remove(_recentDedupeKeys.keys.first);
    }
    _recentDedupeKeys[key] = now;
    return false;
  }

  static int _stableNotificationId(String key) {
    var hash = 0x811c9dc5;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  void dispose() {
    _isDisposed = true;
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _socketNotifSub?.cancel();
    _socketMessageSub?.cancel();
    _tapController.close();
    _foregroundPushController.close();
  }
}
