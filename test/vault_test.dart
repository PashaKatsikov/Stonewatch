import 'package:flutter_test/flutter_test.dart';
import 'package:stonewatch/online/secure/values.dart';

// Exercises the gray-part vault end to end: the strings come masked from
// native/stonewatch_core/src/vault.rs and are decoded over the o7s/o7f FFI
// pair. If the Dart selector table or the Rust mask drifts, these break.
void main() {
  group('rust vault', () {
    test('browser-identity fragments decode', () {
      expect(revealUaProduct(), 'Mozilla/5.0');
      expect(revealUaEngineTail(), ' (KHTML, like Gecko)');
      expect(revealWebkitBuild(), '537.36');
    });

    test('gray-surface copy decodes', () {
      expect(revealNotifyTitle(),
          'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS');
      expect(revealNotifySubtitle(), 'Stay tuned for special offers and rewards');
      expect(revealNoSignalTitle(), 'NO INTERNET CONNECTION');
      expect(revealAcceptLabel(), 'Accept');
      expect(revealSkipLabel(), 'Skip');
      expect(revealRetryLabel(), 'Retry');
    });

    test('snooze constant decodes to the sealed value', () {
      expect(revealNotifySnoozeSeconds(), 258864);
    });

    test('firebase options decode and stay internally consistent', () {
      final String api = revealFbApiKey();
      final String app = revealFbAppId();
      final String sender = revealProjectNumber();
      final String project = revealFbProjectId();
      final String bucket = revealFbStorageBucket();
      // Shape checks only — the raw credentials are never spelled out here.
      expect(api.startsWith('AIza'), isTrue);
      expect(api.length, greaterThan(30));
      expect(app.startsWith('1:$sender:android:'), isTrue);
      expect(project, isNotEmpty);
      expect(bucket.startsWith(project), isTrue);
    });

    test('unsealed JS slots reveal as empty', () {
      expect(revealJsViewport(), '');
      expect(revealJsAutoplay(), '');
    });

    test('keyboard enhancer and its seat hook decode together', () {
      final String hook = revealJsSeatHook();
      expect(hook, 'swSeatField');
      final String body = revealJsKeyboard();
      expect(body, isNotEmpty);
      // The body must install the global the host later calls.
      expect(body, contains('w.$hook=function'));
    });
  });
}
