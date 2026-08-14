package com.proxym.app

import android.content.Intent
import android.net.VpnService
import com.proxym.app.engine.EnterpriseTunnelService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private final val CHANNEL = "com.proxym/vpn"
    private var pendingProxyHost: String? = null
    private var pendingProxyPort: Int = 80
    private var pendingUser: String? = null
    private var pendingPass: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 80
                    val username = call.argument<String>("username")
                    val password = call.argument<String>("password")

                    pendingProxyHost = host
                    pendingProxyPort = port
                    pendingUser = username
                    pendingPass = password

                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, 0x123)
                        result.success(true)
                    } else {
                        startVpnService(host, port, username, password)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "isPrepared" -> {
                    val intent = VpnService.prepare(this)
                    result.success(intent == null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVpnService(host: String, port: Int, user: String?, pass: String?) {
        val intent = Intent(this, EnterpriseTunnelService::class.java).apply {
            putExtra("host", host)
            putExtra("port", port)
            putExtra("username", user)
            putExtra("password", pass)
        }
        startForegroundServiceIfSupported(intent)
    }

    private fun startForegroundServiceIfSupported(intent: Intent) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopVpnService() {
        val intent = Intent(this, EnterpriseTunnelService::class.java).apply {
            action = "STOP"
        }
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 0x123 && resultCode == RESULT_OK) {
            pendingProxyHost?.let { host ->
                startVpnService(host, pendingProxyPort, pendingUser, pendingPass)
            }
        }
    }
}
