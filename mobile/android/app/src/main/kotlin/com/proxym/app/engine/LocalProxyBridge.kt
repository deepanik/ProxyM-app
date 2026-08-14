package com.proxym.app.engine

import android.net.VpnService
import android.util.Base64
import android.util.Log
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class LocalProxyBridge(
    private val vpnService: VpnService,
    private val localPort: Int,
    private var remoteHost: String,
    private var remotePort: Int,
    private var username: String?,
    private var password: String?
) {
    private var serverSocket: ServerSocket? = null
    @Volatile private var isRunning = false
    private var executor: ExecutorService? = null

    fun updateProxyConfig(host: String, port: Int, user: String?, pass: String?) {
        this.remoteHost = host
        this.remotePort = port
        this.username = user
        this.password = pass
    }

    fun start() {
        if (isRunning) return
        isRunning = true
        executor = Executors.newFixedThreadPool(8)
        executor?.submit {
            try {
                serverSocket = ServerSocket(localPort, 32, InetAddress.getByName("127.0.0.1"))
                Log.i("LocalProxyBridge", "Local Proxy Bridge running on 127.0.0.1:$localPort -> $remoteHost:$remotePort")
                while (isRunning) {
                    val clientSocket = serverSocket?.accept() ?: break
                    executor?.submit { handleClientConnection(clientSocket) }
                }
            } catch (e: Exception) {
                if (isRunning) Log.e("LocalProxyBridge", "Server socket error", e)
            }
        }
    }

    private fun handleClientConnection(client: Socket) {
        var remote: Socket? = null
        try {
            client.soTimeout = 15000

            val clientIn = client.getInputStream()
            val clientOut = client.getOutputStream()

            val initialBuffer = ByteArray(8192)
            val bytesRead = clientIn.read(initialBuffer)
            if (bytesRead <= 0) {
                client.close()
                return
            }

            val requestText = String(initialBuffer, 0, bytesRead)
            val isConnectMethod = requestText.startsWith("CONNECT ")

            remote = Socket()
            vpnService.protect(remote)
            remote.soTimeout = 15000

            val remoteInetAddr = InetAddress.getByName(remoteHost)
            remote.connect(InetSocketAddress(remoteInetAddr, remotePort), 5000)

            val remoteIn = remote.getInputStream()
            val remoteOut = remote.getOutputStream()

            val authHeader = if (!username.isNullOrEmpty() && !password.isNullOrEmpty()) {
                val creds = Base64.encodeToString("$username:$password".toByteArray(), Base64.NO_WRAP)
                "Proxy-Authorization: Basic $creds\r\n"
            } else ""

            if (isConnectMethod) {
                val firstLineEnd = requestText.indexOf("\r\n")
                val modifiedReq = if (firstLineEnd != -1 && authHeader.isNotEmpty()) {
                    requestText.substring(0, firstLineEnd + 2) + authHeader + requestText.substring(firstLineEnd + 2)
                } else {
                    requestText
                }

                remoteOut.write(modifiedReq.toByteArray())
                remoteOut.flush()

                val respBuf = ByteArray(2048)
                val respLen = remoteIn.read(respBuf)
                if (respLen > 0) {
                    val respText = String(respBuf, 0, respLen)
                    if (respText.contains("200")) {
                        clientOut.write("HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray())
                        clientOut.flush()

                        val r1 = remote
                        val c1 = client
                        executor?.submit { relayStream(clientIn, remoteOut, c1, r1) }
                        relayStream(remoteIn, clientOut, client, remote)
                    } else {
                        clientOut.write(respBuf, 0, respLen)
                        clientOut.flush()
                        client.close()
                        remote.close()
                    }
                } else {
                    client.close()
                    remote.close()
                }
            } else {
                val firstLineEnd = requestText.indexOf("\r\n")
                val modifiedReq = if (firstLineEnd != -1 && authHeader.isNotEmpty()) {
                    requestText.substring(0, firstLineEnd + 2) + authHeader + requestText.substring(firstLineEnd + 2)
                } else {
                    requestText
                }

                remoteOut.write(modifiedReq.toByteArray())
                remoteOut.flush()

                val r1 = remote
                val c1 = client
                executor?.submit { relayStream(clientIn, remoteOut, c1, r1) }
                relayStream(remoteIn, clientOut, client, remote)
            }
        } catch (e: Exception) {
            try { client.close() } catch (_: Exception) {}
            try { remote?.close() } catch (_: Exception) {}
        }
    }

    private fun relayStream(input: InputStream, output: OutputStream, client: Socket, remote: Socket) {
        try {
            val buffer = ByteArray(8192)
            var len = 0
            while (isRunning && input.read(buffer).also { len = it } != -1) {
                output.write(buffer, 0, len)
                output.flush()
            }
        } catch (_: Exception) {
        } finally {
            try { client.close() } catch (_: Exception) {}
            try { remote.close() } catch (_: Exception) {}
        }
    }

    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
            executor?.shutdownNow()
            executor = null
        } catch (e: Exception) {
            Log.e("LocalProxyBridge", "Error stopping bridge", e)
        }
    }
}
