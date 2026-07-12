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
        if (data != null) return data.toString()
        val stream = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        return stream?.toString()
    }
}
