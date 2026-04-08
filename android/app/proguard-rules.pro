# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# xray-core (libv2ray)
-keep class libv2ray.** { *; }
-keep class go.** { *; }

# Tunnex VPN
-keep class com.tunnex.tunnex.vpn.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keep class kotlinx.coroutines.** { *; }
