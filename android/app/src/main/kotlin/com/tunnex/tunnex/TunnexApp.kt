package com.tunnex.tunnex

import android.app.Application
import android.util.Log
import com.tunnex.tunnex.vpn.TunnexVpnService

class TunnexApp : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            TunnexVpnService.setupXray(this)
            Log.i("TunnexApp", "xray-core initialized")
        } catch (e: Exception) {
            Log.e("TunnexApp", "Failed to initialize xray", e)
        }
    }
}
