package com.tunnex.tunnex.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.net.wifi.WifiManager
import android.util.Log
import com.tunnex.tunnex.MainActivity
import kotlinx.coroutines.*
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray
import org.json.JSONObject

class TunnexVpnService : VpnService(), CoreCallbackHandler {

    companion object {
        const val TAG = "TunnexVPN"
        const val CHANNEL_ID = "tunnex_vpn"
        const val NOTIFICATION_ID = 1
        const val ACTION_STOP = "com.tunnex.STOP_VPN"
        const val EXTRA_CONFIG = "config"
        const val EXTRA_CORE = "core"
        const val EXTRA_SPLIT_BYPASS = "splitBypass"
        const val EXTRA_SPLIT_APPS = "splitApps"

        var instance: TunnexVpnService? = null
            private set

        var currentState: String = "disconnected"
            private set

        var onStateChanged: ((String) -> Unit)? = null

        fun setupXray(context: Context) {
            val xrayDir = java.io.File(context.filesDir, "xray").also { it.mkdirs() }
            for (name in listOf("geoip.dat", "geosite.dat")) {
                val outFile = java.io.File(xrayDir, name)
                if (!outFile.exists()) {
                    try {
                        context.assets.open(name).use { input ->
                            outFile.outputStream().use { output -> input.copyTo(output) }
                        }
                        // no debug log in release
                    } catch (_: Exception) {}
                }
            }
            val prefs = context.getSharedPreferences("xray_prefs", MODE_PRIVATE)
            var baseKey = prefs.getString("xudp_base_key_v7", null)
            if (baseKey == null) {
                val keyBytes = ByteArray(32)
                java.security.SecureRandom().nextBytes(keyBytes)
                baseKey = android.util.Base64.encodeToString(keyBytes,
                    android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING)
                prefs.edit().putString("xudp_base_key_v7", baseKey).apply()
            }
            Libv2ray.initCoreEnv(xrayDir.absolutePath, baseKey)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var coreController: CoreController? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private var splitBypass: Boolean = true
    private var splitApps: List<String> = emptyList()
    private var lastConfig: String? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopVpn()
            return START_NOT_STICKY
        }

        val config = intent?.getStringExtra(EXTRA_CONFIG)
        if (config == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        splitBypass = intent.getBooleanExtra(EXTRA_SPLIT_BYPASS, true)
        splitApps = intent.getStringArrayListExtra(EXTRA_SPLIT_APPS) ?: emptyList()

        startForeground(NOTIFICATION_ID, buildNotification("Подключение..."))
        setState("connecting")

        scope.launch {
            try {
                startXray(config)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start VPN", e)
                withContext(Dispatchers.Main) {
                    setState("disconnected")
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        }

        return START_STICKY
    }

    private suspend fun startXray(config: String) {
        // Close any existing core
        coreController?.let {
            try { it.stopLoop() } catch (_: Exception) {}
        }
        coreController = null
        vpnInterface?.close()
        vpnInterface = null

        // Setup TUN
        val fd = setupTunInterface()
        if (fd < 0) throw Exception("Failed to create TUN")

        withContext(Dispatchers.Main) { acquireLocks() }

        Log.i(TAG, "Starting VPN core")
        val controller = Libv2ray.newCoreController(this)
        controller.startLoop(config, fd.toInt())
        coreController = controller

        val serverName = try {
            val obj = JSONObject(config)
            val outbounds = obj.optJSONArray("outbounds")
            if (outbounds != null && outbounds.length() > 0)
                outbounds.getJSONObject(0).optString("tag", "Tunnex VPN")
            else "Tunnex VPN"
        } catch (_: Exception) { "Tunnex VPN" }

        lastConfig = config

        withContext(Dispatchers.Main) {
            updateNotification(serverName)
            setState("connected")
            registerNetworkCallback()
        }

        // Save state for boot restore
        getSharedPreferences("tunnex_vpn", MODE_PRIVATE).edit()
            .putBoolean("was_connected", true)
            .putString("last_config", lastConfig)
            .apply()
    }

    private fun setupTunInterface(): Long {
        try {
            val builder = Builder()
                .setSession("Tunnex")
                .setMtu(1500)
                .addAddress("26.26.26.1", 30)
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")

            // Split tunnel
            if (!splitBypass && splitApps.isNotEmpty()) {
                // "Только нужное" — only selected apps through VPN
                for (pkg in splitApps) {
                    try { builder.addAllowedApplication(pkg) } catch (_: Exception) {}
                }
            } else {
                // "Защитить всё" — all apps except self
                builder.addDisallowedApplication(packageName)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            Log.i(TAG, "TUN configured")
            vpnInterface = builder.establish()
            return vpnInterface?.fd?.toLong() ?: -1L
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup TUN", e)
            return -1L
        }
    }

    fun stopVpn() {
        setState("disconnecting")
        unregisterNetworkCallback()
        scope.launch {
            try {
                coreController?.stopLoop()
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping xray", e)
            }
            coreController = null
            vpnInterface?.close()
            vpnInterface = null

            withContext(Dispatchers.Main) { releaseLocks() }

            getSharedPreferences("tunnex_vpn", MODE_PRIVATE).edit()
                .putBoolean("was_connected", false).apply()

            withContext(Dispatchers.Main) {
                setState("disconnected")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    // CoreCallbackHandler (xray)
    override fun startup(): Long = 0L
    override fun shutdown(): Long = 0L
    override fun onEmitStatus(ind: Long, msg: String): Long {
        Log.d(TAG, "xray: $ind - $msg")
        return 0L
    }

    fun getTrafficStats(): Map<String, Long> {
        val controller = coreController
        if (controller == null) {
            Log.w(TAG, "getTrafficStats: controller is null")
            return mapOf("up" to 0L, "down" to 0L)
        }
        return try {
            val up = controller.queryStats("proxy", "uplink")
            val down = controller.queryStats("proxy", "downlink")
            if (up > 0 || down > 0) {
                Log.d(TAG, "stats: up=$up down=$down")
            }
            mapOf("up" to up, "down" to down)
        } catch (e: Exception) {
            Log.e(TAG, "queryStats error: ${e.message}")
            mapOf("up" to 0L, "down" to 0L)
        }
    }

    private fun setState(state: String) {
        currentState = state
        onStateChanged?.invoke(state)
    }

    // Notification
    private fun createNotificationChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "Tunnex VPN", NotificationManager.IMPORTANCE_LOW)
            .apply { description = "VPN connection status"; setShowBadge(false) }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val openPi = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val stopPi = PendingIntent.getService(this, 1,
            Intent(this, TunnexVpnService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Tunnex VPN")
            .setContentText(text)
            .setContentIntent(openPi)
            .addAction(Notification.Action.Builder(null, "Отключить", stopPi).build())
            .setOngoing(true).build()
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(text))
    }

    // Power management
    private fun acquireLocks() {
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "tunnex:vpn").apply { acquire() }
        @Suppress("DEPRECATION")
        wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
            .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "tunnex:vpn").apply { acquire() }
    }

    private fun releaseLocks() {
        wakeLock?.let { if (it.isHeld) it.release() }; wakeLock = null
        wifiLock?.let { if (it.isHeld) it.release() }; wifiLock = null
    }

    // Lifecycle
    // --- Network change detection (fixes Telegram after sleep) ---

    private fun registerNetworkCallback() {
        if (networkCallback != null) return
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val registerTime = System.currentTimeMillis()
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            private var lastRestartTime = registerTime
            override fun onAvailable(network: Network) {
                val now = System.currentTimeMillis()
                // Ignore first 5 seconds (TUN creation triggers onAvailable)
                if (now - registerTime < 5000) return
                if (now - lastRestartTime < 30000) return
                if (currentState != "connected") return
                lastRestartTime = now
                Log.i(TAG, "Network changed, restarting core")
                scope.launch {
                    restartCore()
                }
            }
        }
        cm.registerNetworkCallback(
            NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build(),
            networkCallback!!
        )
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let {
            try {
                (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                    .unregisterNetworkCallback(it)
            } catch (_: Exception) {}
        }
        networkCallback = null
    }

    private suspend fun restartCore() {
        val config = lastConfig ?: return
        try {
            coreController?.stopLoop()
            coreController = null
            // Close old TUN and create new (reusing fd causes Go panic)
            vpnInterface?.close()
            vpnInterface = null
            val fd = setupTunInterface()
            if (fd < 0) return
            delay(2000) // network stabilization
            val controller = Libv2ray.newCoreController(this@TunnexVpnService)
            controller.startLoop(config, fd.toInt())
            coreController = controller
            Log.i(TAG, "Core restarted after network change")
        } catch (e: Exception) {
            Log.e(TAG, "Restart failed", e)
        }
    }

    override fun onRevoke() { stopVpn(); super.onRevoke() }
    override fun onDestroy() {
        instance = null; scope.cancel(); releaseLocks()
        vpnInterface?.close(); vpnInterface = null
        super.onDestroy()
    }
}
