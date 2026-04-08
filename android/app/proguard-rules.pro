# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# xray-core (libv2ray)
-keep class libv2ray.** { *; }
-keep class go.** { *; }

# Tunnex VPN
-keep class com.tunnex.tunnex.vpn.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }

# url_launcher
-dontwarn android.window.**
