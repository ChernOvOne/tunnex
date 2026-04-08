package com.tunnex.tunnex.vpn

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class VpnTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()

        val service = TunnexVpnService.instance
        if (service != null && TunnexVpnService.currentState == "connected") {
            service.stopVpn()
        } else {
            // Restore last config
            val prefs = getSharedPreferences("tunnex_vpn", MODE_PRIVATE)
            val lastConfig = prefs.getString("last_config", null) ?: return

            val intent = Intent(this, TunnexVpnService::class.java).apply {
                putExtra(TunnexVpnService.EXTRA_CONFIG, lastConfig)
            }
            startForegroundService(intent)
        }

        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val isConnected = TunnexVpnService.currentState == "connected"
        tile.state = if (isConnected) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.subtitle = if (isConnected) "Подключено" else "Отключено"
        tile.updateTile()
    }
}
