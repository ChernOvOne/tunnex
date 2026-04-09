package com.tunnex.tunnex.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("tunnex_vpn", Context.MODE_PRIVATE)
        val wasConnected = prefs.getBoolean("was_connected", false)
        val lastConfig = prefs.getString("last_config", null)

        if (!wasConnected || lastConfig == null) return

        // Check Flutter auto_connect setting
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val autoConnect = flutterPrefs.getBoolean("flutter.auto_connect", false)
        if (!autoConnect) {
            Log.i("TunnexBoot", "Auto-connect disabled in settings")
            return
        }

        if (VpnService.prepare(context) != null) {
            Log.w("TunnexBoot", "VPN permission not granted")
            return
        }

        Log.i("TunnexBoot", "Auto-starting VPN after boot")
        val serviceIntent = Intent(context, TunnexVpnService::class.java).apply {
            putExtra(TunnexVpnService.EXTRA_CONFIG, lastConfig)
        }
        context.startForegroundService(serviceIntent)
    }
}
