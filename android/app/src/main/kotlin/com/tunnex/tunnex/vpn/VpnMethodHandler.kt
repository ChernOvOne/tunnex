package com.tunnex.tunnex.vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnMethodHandler(
    private val activity: Activity
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.tunnex/vpn"
        const val EVENT_CHANNEL = "com.tunnex/vpn_state"
        const val VPN_PERMISSION_REQUEST = 24601
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingConfig: String? = null
    private var pendingCore: String? = null
    private var pendingSplitBypass: Boolean = true
    private var pendingSplitApps: List<String> = emptyList()
    private var eventSink: EventChannel.EventSink? = null

    val eventStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            // Send current state immediately
            events?.success(TunnexVpnService.currentState)

            // Register for future state changes
            TunnexVpnService.onStateChanged = { state ->
                activity.runOnUiThread {
                    eventSink?.success(state)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            TunnexVpnService.onStateChanged = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val config = call.argument<String>("config")
                val core = call.argument<String>("core") ?: "xray"
                val splitBypass = call.argument<Boolean>("splitBypass") ?: true
                val splitApps = call.argument<List<String>>("splitApps") ?: emptyList()
                if (config == null) {
                    result.error("NO_CONFIG", "Config is required", null)
                    return
                }
                startVpn(config, core, splitBypass, splitApps, result)
            }
            "stop" -> {
                stopVpn(result)
            }
            "getState" -> {
                result.success(TunnexVpnService.currentState)
            }
            "getStats" -> {
                val stats = TunnexVpnService.instance?.getTrafficStats()
                    ?: mapOf("up" to 0L, "down" to 0L)
                // Ensure HashMap<String, Any> for Flutter compatibility
                result.success(HashMap<String, Any>(stats))
            }
            "requestPermission" -> {
                requestVpnPermission(result)
            }
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    try {
                        val file = java.io.File(path)
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            activity, "${activity.packageName}.fileprovider", file)
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback: open file directly
                        try {
                            val uri = android.net.Uri.fromFile(java.io.File(path))
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            activity.startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INSTALL_FAILED", e2.message, null)
                        }
                    }
                } else {
                    result.error("NO_PATH", "Path required", null)
                }
            }
            "requestBatteryOptimization" -> {
                try {
                    val pm = activity.getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                    if (!pm.isIgnoringBatteryOptimizations(activity.packageName)) {
                        val intent = android.content.Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = android.net.Uri.parse("package:${activity.packageName}")
                        activity.startActivity(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun startVpn(config: String, core: String, splitBypass: Boolean, splitApps: List<String>, result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            pendingResult = result
            pendingConfig = config
            pendingCore = core
            pendingSplitBypass = splitBypass
            pendingSplitApps = splitApps
            activity.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST)
            return
        }

        doStartVpn(config, core, splitBypass, splitApps)
        result.success(null)
    }

    private fun doStartVpn(config: String, core: String, splitBypass: Boolean, splitApps: List<String>) {
        val intent = Intent(activity, TunnexVpnService::class.java).apply {
            putExtra(TunnexVpnService.EXTRA_CONFIG, config)
            putExtra(TunnexVpnService.EXTRA_CORE, core)
            putExtra(TunnexVpnService.EXTRA_SPLIT_BYPASS, splitBypass)
            putStringArrayListExtra(TunnexVpnService.EXTRA_SPLIT_APPS, ArrayList(splitApps))
        }
        activity.startForegroundService(intent)
    }

    private fun stopVpn(result: MethodChannel.Result) {
        TunnexVpnService.instance?.stopVpn()
            ?: run {
                // Service not running, send stop intent anyway
                val intent = Intent(activity, TunnexVpnService::class.java).apply {
                    action = TunnexVpnService.ACTION_STOP
                }
                activity.startService(intent)
            }
        result.success(null)
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(activity)
        if (prepareIntent != null) {
            pendingResult = result
            activity.startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST)
        } else {
            result.success(true) // Already granted
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != VPN_PERMISSION_REQUEST) return false

        if (resultCode == Activity.RESULT_OK) {
            pendingConfig?.let { config ->
                doStartVpn(config, pendingCore ?: "xray", pendingSplitBypass, pendingSplitApps)
                pendingResult?.success(null)
            } ?: run {
                pendingResult?.success(true)
            }
        } else {
            pendingResult?.error("PERMISSION_DENIED", "VPN permission denied", null)
        }

        pendingResult = null
        pendingConfig = null
        pendingCore = null
        return true
    }
}
