import 'package:flutter/material.dart';

import '../secure/values.dart';
import '../config/settings.dart';
import '../store/prefs_store.dart';
import '../push/messaging.dart';
import 'backdrop.dart';
import 'buttons.dart';
import 'web_screen.dart';

// ============================================================
// NOTIFY INVITE — push opt-in promo shown before the WebView
// ============================================================
// A painted gradient backdrop (no artwork) carries the headline and
// subline — both revealed from the Rust vault — above the Accept /
// Skip buttons.
//
// Landscape intentionally has NO SafeArea: the camera cutout would
// otherwise shift the horizontal centre and skew the layout. The
// content is centred horizontally in both orientations.
// ============================================================

class NotifyPrompt extends StatefulWidget {
  const NotifyPrompt({
    super.key,
    required this.vault,
    required this.signals,
    required this.destination,
  });

  final PrefsStore vault;
  final Messaging signals;
  final String destination;

  @override
  State<NotifyPrompt> createState() => _NotifyPromptState();
}

class _NotifyPromptState extends State<NotifyPrompt> {
  bool _working = false;

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final bool granted = await widget.signals.requestPermission();
    if (!granted) await widget.vault.snoozeNotifyUntil(_snoozeUntil());
    if (mounted) _advance();
  }

  Future<void> _skip() async {
    if (_working) return;
    await widget.vault.snoozeNotifyUntil(_snoozeUntil());
    if (mounted) _advance();
  }

  int _snoozeUntil() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      AppSettings.notifySnooze.inSeconds;

  void _advance() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebScreen(
          url: widget.destination,
          vault: widget.vault,
          signals: widget.signals,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final Widget copy = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          revealNotifyTitle(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Lilita',
            color: Color(0xFFFFD75A),
            fontSize: 28,
            height: 1.15,
            letterSpacing: 0.5,
            shadows: <Shadow>[
              Shadow(color: Color(0xAA000000), offset: Offset(0, 2), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          revealNotifySubtitle(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.3,
          ),
        ),
      ],
    );

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        PillButton(
          label: revealAcceptLabel(),
          compact: landscape,
          width: landscape ? size.width * 0.34 : size.width * 0.66,
          onTap: _accept,
        ),
        SizedBox(height: landscape ? 10 : 16),
        PillButton.timber(
          label: revealSkipLabel(),
          compact: landscape,
          width: landscape ? size.width * 0.34 : size.width * 0.66,
          onTap: _skip,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF10161C),
      body: Backdrop(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: landscape ? size.width * 0.1 : 28,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Spacer(flex: 3),
              copy,
              const Spacer(flex: 2),
              actions,
              SizedBox(height: size.height * (landscape ? 0.08 : 0.1)),
            ],
          ),
        ),
      ),
    );
  }
}
