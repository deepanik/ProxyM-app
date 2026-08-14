package com.proxym.app.engine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.ProxyInfo
import android.net.VpnService
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log

class EnterpriseTunnelService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var proxyBridge: LocalProxyBridge? = null
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    @Volatile private var currentHost: String = ""
    @Volatile private var currentPort: Int = 80
    @Volatile private var currentUser: String? = null
    @Volatile private var currentPass: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        registerNetworkCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP") {
            stopTunnel()
            return START_NOT_STICKY
        }

        currentHost = intent?.getStringExtra("host") ?: ""
        currentPort = intent?.getIntExtra("port", 80) ?: 80
        currentUser = intent?.getStringExtra("username")
        currentPass = intent?.getStringExtra("password")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1001, createNotification(currentHost, currentPort), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1001, createNotification(currentHost, currentPort))
        }
        startTunnel(currentHost, currentPort, currentUser, currentPass)

        return START_STICKY
    }

    @Synchronized
    private fun startTunnel(host: String, port: Int, user: String?, pass: String?) {
        try {
            val resolvedHost = try {
                val addr = java.net.InetAddress.getByName(host)
                addr.hostAddress ?: host
            } catch (_: Exception) {
                host
            }

            // Start local proxy bridge on 127.0.0.1:8888 with resolved host IP
            val localPort = 8888
            if (proxyBridge == null) {
                proxyBridge = LocalProxyBridge(this, localPort, resolvedHost, port, user, pass)
                proxyBridge?.start()
            } else {
                proxyBridge?.updateProxyConfig(resolvedHost, port, user, pass)
            }

            // Close existing VPN interface if updating
            vpnInterface?.close()

            val builder = Builder()
                .addAddress("10.0.0.2", 24)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .setSession("ProxyM Active ($host:$port)")
                .allowBypass()

            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {}

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val proxyInfo = ProxyInfo.buildDirectProxy("127.0.0.1", localPort)
                builder.setHttpProxy(proxyInfo)
            }

            vpnInterface = builder.establish()
            Log.i("EnterpriseTunnelService", "Enterprise VPN Tunnel established successfully for $host:$port")
        } catch (e: Exception) {
            Log.e("EnterpriseTunnelService", "Failed to establish VPN tunnel", e)
        }
    }

    private fun registerNetworkCallback() {
        try {
            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.i("EnterpriseTunnelService", "Network physical interface available: $network")
                    if (currentHost.isNotEmpty()) {
                        startTunnel(currentHost, currentPort, currentUser, currentPass)
                    }
                }

                override fun onLost(network: Network) {
                    Log.w("EnterpriseTunnelService", "Physical network lost: $network")
                }
            }

            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            connectivityManager?.registerNetworkCallback(request, networkCallback!!)
        } catch (e: Exception) {
            Log.e("EnterpriseTunnelService", "Error registering network callback", e)
        }
    }

    private fun stopTunnel() {
        try {
            networkCallback?.let { connectivityManager?.unregisterNetworkCallback(it) }
            networkCallback = null
            proxyBridge?.stop()
            proxyBridge = null
            vpnInterface?.close()
            vpnInterface = null
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.e("EnterpriseTunnelService", "Error stopping tunnel", e)
        }
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "proxym_vpn_channel",
                "ProxyM Active Tunnel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground notification for active proxy tunnel"
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(host: String, port: Int): Notification {
        val title = "ProxyM Tunnel Connected"
        val text = if (host.isNotEmpty()) "Active Proxy: $host:$port" else "Tunnel active"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "proxym_vpn_channel")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }
}
