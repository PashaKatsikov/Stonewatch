import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../format.dart';
import 'shell_channel.dart';

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  var _progress = 0;
  var _failed = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            tuneWebView();
            if (!mounted) return;
            setState(() => _failed = false);
          },
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onPageFinished: (_) {
            tuneWebView();
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() => _failed = true);
          },
        ),
      );
    _open();
  }

  Future<void> _open() async {
    final ua = await _controller.getUserAgent();
    if (ua != null && (ua.contains('wv') || ua.contains('Version/4.0'))) {
      final chrome = ua.replaceAll('; wv', '').replaceAll('Version/4.0 ', '');
      await _controller.setUserAgent(chrome);
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B242C),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(fontFamily: displayFont, fontSize: 20),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Stack(
          children: [
            if (_ready) WebViewWidget(controller: _controller),
            if (_progress < 100 && !_failed)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  color: const Color(0xFF1A73E8),
                  backgroundColor: const Color(0xFFE8EAED),
                ),
              ),
            if (_failed)
              ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'This page did not load.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.url,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5F6368),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _failed = false;
                              _progress = 0;
                            });
                            _controller.loadRequest(Uri.parse(widget.url));
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}
