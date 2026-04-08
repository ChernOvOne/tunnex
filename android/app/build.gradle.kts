plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tunnex.tunnex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tunnex.tunnex"
        minSdk = 26 // Android 8.0+ (required for sing-box + notification channels)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // sing-box Go library (built via gomobile bind)
    // Place libbox.aar in android/app/libs/
    // Build: cd sing-box && make lib_android
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))

    // Kotlin coroutines (for VPN service)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}
