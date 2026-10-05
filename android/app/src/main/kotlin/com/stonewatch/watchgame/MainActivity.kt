package com.stonewatch.watchgame

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.WebSettings
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — two bridges
// ============================================================
//  • "stonewatch/shell"   — the native game's in-app info WebView
//     asks us to turn off WebView dark-mode forcing (tuneWebView).
//  • "stonewatch/filegate" — the gateway WebView's <input type=file>
//     hops here to open the native chooser and returns the picked
//     content:// URIs. No file_picker dependency.
//     Keep this string in sync with WebHost._fileGate in Dart.
// ============================================================
class MainActivity : FlutterActivity() {
    private val shellChannel = "stonewatch/shell"
    private val fileGateName = "stonewatch/filegate"
    private val pickRequest = 0x5704
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, shellChannel).setMethodCallHandler { call, result ->
            if (call.method != "tuneWebView") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            window.decorView.post {
                applyChromeDefaults(window.decorView)
                result.success(null)
            }
        }

        MethodChannel(messenger, fileGateName).setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val multiple = call.argument<Boolean>("multiple") ?: false
            val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
            openChooser(multiple, mimes, result)
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

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        pendingPick?.success(emptyList<String>())
        pendingPick = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingPick = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingPick
        pendingPick = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
