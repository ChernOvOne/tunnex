package com.tunnex.tunnex.vpn

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream

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

            // Get app icon as base64 PNG
            val iconBase64 = try {
                val drawable = pm.getApplicationIcon(appInfo)
                val bitmap = if (drawable is BitmapDrawable) {
                    drawable.bitmap
                } else {
                    val bmp = Bitmap.createBitmap(48, 48, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, 48, 48)
                    drawable.draw(canvas)
                    bmp
                }
                val stream = ByteArrayOutputStream()
                val scaled = Bitmap.createScaledBitmap(bitmap, 48, 48, true)
                scaled.compress(Bitmap.CompressFormat.PNG, 80, stream)
                Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
            } catch (_: Exception) { "" }

            mapOf(
                "packageName" to packageName,
                "appName" to (pm.getApplicationLabel(appInfo)?.toString() ?: packageName),
                "isSystem" to isSystem,
                "icon" to iconBase64,
            )
        }
    }
}
