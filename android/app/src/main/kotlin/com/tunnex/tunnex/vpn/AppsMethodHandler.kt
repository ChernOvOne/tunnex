package com.tunnex.tunnex.vpn

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class AppsMethodHandler(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.tunnex/apps"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                scope.launch {
                    val apps = getInstalledApps()
                    withContext(Dispatchers.Main) {
                        result.success(apps)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolvedApps = pm.queryIntentActivities(mainIntent, 0)
        val seen = mutableSetOf<String>()

        return resolvedApps.mapNotNull { resolveInfo ->
            val packageName = resolveInfo.activityInfo.packageName
            if (packageName == context.packageName) return@mapNotNull null
            if (!seen.add(packageName)) return@mapNotNull null

            val appInfo = try {
                pm.getApplicationInfo(packageName, 0)
            } catch (_: Exception) {
                return@mapNotNull null
            }

            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            mapOf(
                "packageName" to packageName,
                "appName" to (pm.getApplicationLabel(appInfo)?.toString() ?: packageName),
                "isSystem" to isSystem,
            )
        }
    }
}
