import 'package:flutter/material.dart';

import '../config/gate_settings.dart';
import '../store/vault_box.dart';
import '../push/signal_post.dart';
import 'backdrops.dart';
import 'gate_buttons.dart';
import 'web_host.dart';

// ============================================================
// NOTIFY INVITE — push opt-in promo shown before the WebView
// ============================================================
// The background art already carries the headline ("ALLOW
// NOTIFICATIONS ABOUT BONUSES AND PROMOS / Stay tuned for special
// offers and rewards"), so this screen only overlays the Accept /
// Skip buttons below the signboard.
//
// Landscape intentionally has NO SafeArea: the camera cutout would
// otherwise shift the horizontal centre and skew the buttons. The
// buttons are centred horizontally in both orientations.
// ============================================================

class NotifyInvite extends StatefulWidget {
  const NotifyInvite({
    super.key,
    required this.vault,
    required this.signals,
    required this.destination,
  });

  final VaultBox vault;
  final SignalPost signals;
  final String destination;

  @override
  State<NotifyInvite> createState() => _NotifyInviteState();
}

class _NotifyInviteState extends State<NotifyInvite> {
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
      GateSettings.notifySnooze.inSeconds;

  void _advance() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebHost(
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

    final Widget actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        WardenButton(
          label: 'Accept',
          compact: landscape,
          width: landscape ? size.width * 0.34 : size.width * 0.66,
          onTap: _accept,
        ),
        SizedBox(height: landscape ? 10 : 16),
        WardenButton.timber(
          label: 'Skip',
          compact: landscape,
          width: landscape ? size.width * 0.34 : size.width * 0.66,
          onTap: _skip,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A3C),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            landscape ? Backdrops.notifyLandscape : Backdrops.notifyPortrait,
            fit: BoxFit.cover,
          ),
          // Slight darken toward the bottom so the pills read clearly.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x73000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.07 : 0.06),
            child: Center(child: actions),
          ),
        ],
      ),
    );
  }
}
