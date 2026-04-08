package com.tunnex.tunnex

import android.content.Intent
import android.os.Bundle
import com.tunnex.tunnex.vpn.AppsMethodHandler
import com.tunnex.tunnex.vpn.VpnMethodHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var vpnHandler: VpnMethodHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        vpnHandler = VpnMethodHandler(this)

        // MethodChannel for VPN control (start/stop/getState)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VpnMethodHandler.CHANNEL
        ).setMethodCallHandler(vpnHandler)

        // EventChannel for VPN state stream
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VpnMethodHandler.EVENT_CHANNEL
        ).setStreamHandler(vpnHandler.eventStreamHandler)

        // MethodChannel for installed apps list (split tunnel)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppsMethodHandler.CHANNEL
        ).setMethodCallHandler(AppsMethodHandler(this))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (vpnHandler.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
