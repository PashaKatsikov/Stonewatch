import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../net/stamped_client.dart';
import '../store/vault_box.dart';

// ============================================================
// SIGNAL POST — Firebase Messaging + local notifications
// ============================================================
// Cold-start taps (app killed) stash the URL in the vault for the
// boot pipeline to pick up next frame. Warm taps (fore/background)
// deliver through [onUrl] and are NOT persisted — they are one-shot.
//
// The Android channel id here MUST equal the manifest's
// `default_notification_channel_id`. It is unique to this build.
// ============================================================

const String signalChannelId = 'stonewatch_signals';
const String signalChannelName = 'Game Updates';
const String _smallIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage message) async {
  // The OS draws the tray notification; the tap is handled on resume.
}

class SignalPost {
  SignalPost(this._vault);

  final VaultBox _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  String? _token;
  bool _ready = false;

  /// Warm-tap URL delivery — the WebView loads this directly.
  void Function(String url)? onUrl;

  /// FCM rotated the token — the warden re-POSTs the verdict.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> ignite() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_onBackground);

      await _initLocal();

      _token = await _fcm!.getToken();
      _fcm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_whileForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_warmTap);

      final RemoteMessage? launched = await _fcm!.getInitialMessage();
      if (launched != null) _coldTap(launched);

      _ready = true;
    } catch (_) {
      // Firebase not configured — push stays dormant.
    }
  }

  Future<void> _initLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? raw = r.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(raw) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? plugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          signalChannelId,
          signalChannelName,
          description: 'Bonuses, promos and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records a hard denial so the invite
  /// stops reappearing after an OS-level "no".
  Future<bool> requestPermission() async {
    final FirebaseMessaging? fcm = _fcm;
    if (fcm == null) return false;
    final NotificationSettings s = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = s.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _vault.setNotifyGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.setNotifyHardDenied();
    }
    return granted;
  }

  Future<void> _whileForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails details;
    final String? image = n.android?.imageUrl;
    final Uint8List? bytes = (image != null && image.isNotEmpty)
        ? await stampedClient.fetchBytes(Uri.parse(image),
            timeout: const Duration(seconds: 10))
        : null;

    if (bytes != null) {
      details = AndroidNotificationDetails(
        signalChannelId,
        signalChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(bytes),
          largeIcon:
              const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      );
    } else {
      details = const AndroidNotificationDetails(
        signalChannelId,
        signalChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
      );
    }

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _coldTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) _vault.stashColdUrl(url);
  }

  void _warmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) onUrl?.call(url);
  }
}
