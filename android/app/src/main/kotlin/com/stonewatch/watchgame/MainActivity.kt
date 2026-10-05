package com.stonewatch.watchgame

import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.WebSettings
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stonewatch/shell")
            .setMethodCallHandler { call, result ->
                if (call.method != "tuneWebView") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                window.decorView.post {
                    applyChromeDefaults(window.decorView)
                    result.success(null)
                }
            }
    }

    private fun applyChromeDefaults(view: View) {
        if (view is WebView) {
            val settings = view.settings
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = true
            settings.domStorageEnabled = true
            settings.javaScriptEnabled = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                @Suppress("DEPRECATION")
                settings.forceDark = WebSettings.FORCE_DARK_OFF
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                settings.isAlgorithmicDarkeningAllowed = false
            }
            view.setBackgroundColor(android.graphics.Color.WHITE)
            return
        }
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                applyChromeDefaults(view.getChildAt(i))
            }
        }
    }
}
