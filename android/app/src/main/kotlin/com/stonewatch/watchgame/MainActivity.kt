package com.stonewatch.watchgame

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

// ============================================================
// MainActivity — three bridges + edge-to-edge window handling
// ============================================================
//  • "stonewatch/shell"   — the native game's in-app info WebView asks us to
//    turn off WebView dark-mode forcing (tuneWebView).
//  • "stonewatch/filegate" — the gateway WebView's <input type=file> hops here
//    to open the native chooser and returns the picked content:// URIs.
//  • "stonewatch/surface"  — reports the live display-cutout insets and the
//    soft-keyboard height so the gateway WebView can pad only for the cutout
//    and lift the focused field in-page (the window itself never resizes).
//    Keep these strings in sync with the Dart MethodChannel names.
//
// The window is edge-to-edge with SOFT_INPUT_ADJUST_NOTHING: the IME overlays
// the content instead of resizing/panning it. Both system bars are hidden; a
// swipe (or the IME) reveals them transiently without adding a layout inset.
// While the keyboard is up the nav bar is left visible so it overlays the
// WebView — it is never a persistent inset.
// ============================================================
class MainActivity : FlutterActivity() {
    private val shellChannel = "sw/host"
    private val fileGateName = "sw/upload"
    private val surfaceName = "sw/metrics"
    private val pickRequest = 0x5704

    private var pendingPick: MethodChannel.Result? = null
    private var surface: MethodChannel? = null
    private var lastIme = -1.0

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING)
        WindowInsetsControllerCompat(window, window.decorView).systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        tuckBars()
        observeKeyboard()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) tuckBars()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        window.decorView.post {
            tuckBars()
            surface?.invokeMethod("insetPulse", sample())
        }
    }

    // Hide both bars when the keyboard is down; when it is up, keep the nav bar
    // so it can overlay the WebView (never inset). Status bar stays hidden.
    private fun tuckBars() {
        val root = window.decorView
        val insets = ViewCompat.getRootWindowInsets(root)
        val imeUp = insets != null && insets.isVisible(WindowInsetsCompat.Type.ime())
        val target = if (imeUp) {
            WindowInsetsCompat.Type.statusBars()
        } else {
            WindowInsetsCompat.Type.statusBars() or WindowInsetsCompat.Type.navigationBars()
        }
        val settled = insets != null &&
            !insets.isVisible(WindowInsetsCompat.Type.statusBars()) &&
            (imeUp || !insets.isVisible(WindowInsetsCompat.Type.navigationBars()))
        if (settled) return
        WindowInsetsControllerCompat(window, root).hide(target)
    }

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

        surface = MethodChannel(messenger, surfaceName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "probeInsets" -> result.success(sample())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun toDip(px: Int): Double {
        val density = resources.displayMetrics.density.toDouble()
        return if (density <= 0.0) 0.0 else px / density
    }

    // Current keyboard height, display-cutout insets (logical px) and the
    // orientation the sample was taken in, so the Dart side can cache the
    // cutout per orientation and apply it synchronously on rotation.
    private fun sample(): HashMap<String, Any> {
        val insets = ViewCompat.getRootWindowInsets(window.decorView)
        val ime = insets?.getInsets(WindowInsetsCompat.Type.ime())?.bottom ?: 0
        val cut = insets?.getInsets(WindowInsetsCompat.Type.displayCutout())
        val land =
            resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        return hashMapOf(
            "ime" to toDip(ime),
            "cutL" to toDip(cut?.left ?: 0),
            "cutT" to toDip(cut?.top ?: 0),
            "cutR" to toDip(cut?.right ?: 0),
            "land" to land,
        )
    }

    // Push a fresh sample when the keyboard finishes animating (open or close).
    private fun observeKeyboard() {
        val host = findViewById<View>(android.R.id.content) ?: return
        ViewCompat.setWindowInsetsAnimationCallback(
            host,
            object : WindowInsetsAnimationCompat.Callback(
                WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE,
            ) {
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: MutableList<WindowInsetsAnimationCompat>,
                ): WindowInsetsCompat = insets

                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    tuckBars()
                    val pane = sample()
                    val ime = pane["ime"] as? Double ?: 0.0
                    if (abs(ime - lastIme) < 1.0) return
                    lastIme = ime
                    runOnUiThread { surface?.invokeMethod("insetPulse", pane) }
                }
            },
        )
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
