package com.proxym.app

import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Base64
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors

class VpnProxyService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile private var isRunning = false
    private var localProxyServer: LocalProxyServer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "STOP") {
            stopVpn()
            return START_NOT_STICKY
        }

        val host = intent?.getStringExtra("host") ?: ""
        val port = intent?.getIntExtra("port", 80) ?: 80
        val username = intent?.getStringExtra("username")
        val password = intent?.getStringExtra("password")

        try {
            stopVpn()

            // 1. Start local proxy server on 127.0.0.1:8888 with auto credential injection
            val localPort = 8888
            localProxyServer = LocalProxyServer(this, localPort, host, port, username, password)
            localProxyServer?.start()

            // 2. Build system VPN interface pointing HTTP proxy to local proxy server
            val builder = Builder()
                .addAddress("10.0.0.2", 24)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("1.1.1.1")
                .setSession("ProxyM Active ($host:$port)")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val proxyInfo = ProxyInfo.buildDirectProxy("127.0.0.1", localPort)
                builder.setHttpProxy(proxyInfo)
            }

            vpnInterface = builder.establish()
            isRunning = true
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return START_STICKY
    }

    private fun stopVpn() {
        isRunning = false
        try {
            localProxyServer?.stop()
            localProxyServer = null
            vpnInterface?.close()
            vpnInterface = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }
}

class LocalProxyServer(
    private val vpnService: VpnService,
    private val localPort: Int,
    private val remoteHost: String,
    private val remotePort: Int,
    private val user: String?,
    private val pass: String?
) {
    private var serverSocket: ServerSocket? = null
    @Volatile private var isRunning = false
    private val executor = Executors.newCachedThreadPool()

    fun start() {
        isRunning = true
        executor.submit {
            try {
                serverSocket = ServerSocket(localPort, 50, InetAddress.getByName("127.0.0.1"))
                while (isRunning) {
                    val clientSocket = serverSocket?.accept() ?: break
                    executor.submit { handleClient(clientSocket) }
                }
            } catch (e: Exception) {
                // Closed
            }
        }
    }

    private fun handleClient(client: Socket) {
        try {
            val remote = Socket()
            vpnService.protect(remote) // Protect outgoing proxy socket from VPN recursion
            remote.connect(java.net.InetSocketAddress(remoteHost, remotePort), 10000)

            val clientIn = client.getInputStream()
            val clientOut = client.getOutputStream()
            val remoteIn = remote.getInputStream()
            val remoteOut = remote.getOutputStream()

            val authHeader = if (!user.isNullOrEmpty() && !pass.isNullOrEmpty()) {
                val creds = Base64.encodeToString("$user:$pass".toByteArray(), Base64.NO_WRAP)
                "Proxy-Authorization: Basic $creds\r\n"
            } else ""

            executor.submit { pipe(clientIn, remoteOut, authHeader) }
            executor.submit { pipe(remoteIn, clientOut, null) }
        } catch (e: Exception) {
            try { client.close() } catch (_: Exception) {}
        }
    }

    private fun pipe(input: InputStream, output: OutputStream, headerToInject: String?) {
        try {
            val buffer = ByteArray(16384)
            var read = input.read(buffer)
            if (read > 0) {
                if (!headerToInject.isNullOrEmpty()) {
                    val req = String(buffer, 0, read)
                    if (req.startsWith("CONNECT ") || req.startsWith("GET ") || req.startsWith("POST ")) {
                        val headerPos = req.indexOf("\r\n")
                        if (headerPos != -1) {
                            val modifiedReq = req.substring(0, headerPos + 2) + headerToInject + req.substring(headerPos + 2)
                            val modifiedBytes = modifiedReq.toByteArray()
                            output.write(modifiedBytes)
                            output.flush()
                        } else {
                            output.write(buffer, 0, read)
                            output.flush()
                        }
                    } else {
                        output.write(buffer, 0, read)
                        output.flush()
                    }
                } else {
                    output.write(buffer, 0, read)
                    output.flush()
                }

                while (isRunning && input.read(buffer).also { read = it } != -1) {
                    output.write(buffer, 0, read)
                    output.flush()
                }
            }
        } catch (_: Exception) {
        } finally {
            try { input.close() } catch (_: Exception) {}
            try { output.close() } catch (_: Exception) {}
        }
    }

    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
        } catch (_: Exception) {}
    }
}
