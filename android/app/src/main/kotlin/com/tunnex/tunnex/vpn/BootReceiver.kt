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

        // Check VPN permission is still granted
        if (VpnService.prepare(context) != null) {
            Log.w("TunnexBoot", "VPN permission not granted, skipping auto-start")
            return
        }

        Log.i("TunnexBoot", "Restoring VPN connection after boot")
        val lastCore = prefs.getString("last_core", "xray")
        val serviceIntent = Intent(context, TunnexVpnService::class.java).apply {
            putExtra(TunnexVpnService.EXTRA_CONFIG, lastConfig)
            putExtra(TunnexVpnService.EXTRA_CORE, lastCore)
        }
        context.startForegroundService(serviceIntent)
    }
}
