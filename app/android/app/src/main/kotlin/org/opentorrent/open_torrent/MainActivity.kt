package org.opentorrent.open_torrent

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "org.opentorrent/service"
    private var channel: MethodChannel? = null
    private var pendingUri: String? = null

    companion object {
        private const val MAX_URI_LEN = 8192
        private val ALLOWED_SCHEMES = setOf("magnet", "content", "file", "http", "https")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, DownloadService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    stopService(Intent(this, DownloadService::class.java))
                    result.success(true)
                }
                "getInitialUri" -> {
                    val uri = pendingUri ?: extractUri(intent)
                    pendingUri = null
                    result.success(uri)
                }
                else -> result.notImplemented()
            }
        }
        extractUri(intent)?.let { pendingUri = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractUri(intent)?.let { uri ->
            channel?.invokeMethod("onIncomingUri", uri)
        }
    }

    private fun extractUri(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return null
        val data: Uri? = intent.data
        val raw = when {
            data != null -> data.toString()
            else -> {
                @Suppress("DEPRECATION")
                val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                stream?.toString()
            }
        } ?: return null
        return sanitizeIncomingUri(raw)
    }

    private fun sanitizeIncomingUri(raw: String): String? {
        if (raw.isEmpty() || raw.length > MAX_URI_LEN) return null
        val scheme = raw.substringBefore(':', missingDelimiterValue = "")
            .lowercase()
        if (scheme !in ALLOWED_SCHEMES) return null
        if (scheme == "magnet" && !raw.contains("xt=urn:btih:", ignoreCase = true) &&
            !raw.contains("xt=urn:btmh:", ignoreCase = true)
        ) {
            return null
        }
        return raw
    }
}
