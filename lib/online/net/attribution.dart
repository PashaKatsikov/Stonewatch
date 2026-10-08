import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../secure/values.dart';
import '../config/settings.dart';
import 'api_client.dart';

// ============================================================
// INSTALL TRACER — AppsFlyer install + deep-link collector
// ============================================================
// Gathers up to three attribution signals and folds them into the
// verdict body:
//   • onInstallConversionData — install attribution
//   • onDeepLinking           — OneLink / UDL click
//   • onAppOpenAttribution    — returning-user attribution
//
// Organic rescue: AppsFlyer sometimes reports `af_status: Organic`
// on the FIRST callback for a genuinely paid install. When that
// happens we wait, then re-pull from GCD. The rescue overrides the
// initial payload; if it fails we keep Organic (→ safe native path).
//
// Short-circuit: with no dev key sealed yet, the SDK never boots and
// the futures settle immediately with empty maps.
// ============================================================

class Attribution {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _install;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;

  final Completer<void> _installDone = Completer<void>();
  final Completer<void> _deepLinkDone = Completer<void>();

  bool _booted = false;

  /// Boot the SDK and attach callbacks. Idempotent.
  Future<void> ignite() async {
    if (_booted) return;
    _booted = true;

    final String key = AppSettings.devKey;
    if (key.isEmpty) {
      _finishInstall();
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: key,
      appId: AppSettings.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData(_onConversion);
    sdk.onAppOpenAttribution((dynamic raw) => _appOpen = _flatten(raw));
    sdk.onDeepLinking(_onDeepLink);

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall();
      _finishDeepLink();
    }
  }

  Future<void> _onConversion(dynamic raw) async {
    final Map<String, dynamic> payload = _flatten(raw);
    if (payload['af_status']?.toString() == 'Organic') {
      await Future<void>.delayed(AppSettings.organicRescue);
      _install = await _gcdRescue() ?? payload;
    } else {
      _install = payload;
    }
    _finishInstall();
  }

  void _onDeepLink(DeepLinkResult result) {
    final Map<String, dynamic>? click = result.deepLink?.clickEvent;
    if (click != null) _deepLink = Map<String, dynamic>.from(click);
    _finishDeepLink();
  }

  /// Wait (capped) for the install + deep-link callbacks before the
  /// verdict request goes out.
  Future<void> settle({required Duration installWait}) async {
    await Future.wait<void>(<Future<void>>[
      _installDone.future
          .timeout(installWait, onTimeout: _finishInstall),
      _deepLinkDone.future
          .timeout(AppSettings.deepLinkWait, onTimeout: _finishDeepLink),
    ]);
  }

  Future<String?> deviceId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assemble the flat verdict body. Attribution fields pass through
  /// verbatim; the seven device-side fields are added on top.
  Future<Map<String, dynamic>> composeBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (_install != null) body.addAll(_install!);
    _deepLink?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpen?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = AppSettings.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = AppSettings.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = AppSettings.projectNumber;
    if (project.isNotEmpty) body['firebase_project_id'] = project;

    assert(() {
      debugPrint('[net.trace] body ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? uid = await deviceId();
      if (uid == null) return null;
      final String ref = Platform.isIOS
          ? AppSettings.storeNumericId
          : AppSettings.applicationId;
      final String url = revealGcdCallUrl(ref, uid);
      if (url.isEmpty) return null;

      final dynamic res = await apiClient.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${AppSettings.devKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall() {
    if (!_installDone.isCompleted) _installDone.complete();
  }

  void _finishDeepLink() {
    if (!_deepLinkDone.isCompleted) _deepLinkDone.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
