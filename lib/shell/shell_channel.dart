import 'package:flutter/services.dart';

const _channel = MethodChannel('sw/host');

Future<void> tuneWebView() async {
  try {
    await _channel.invokeMethod<void>('tuneWebView');
  } on PlatformException {
    // The page still loads; this only turns off WebView darkening.
  } on MissingPluginException {
    return;
  }
}
