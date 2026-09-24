plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Platform signing (TBox / AOSP platform key).
// Provide these four values in ~/.gradle/gradle.properties or via -P flags to
// platform-sign the `system` flavor. If they are unset, the `system` flavor
// falls back to the debug key — that build will NOT install as uid.system on a
// device (signature mismatch); use it only to verify that the project compiles.
val tboxPlatformKeystore = providers.gradleProperty("TBOX_PLATFORM_KEYSTORE").orNull
val tboxPlatformAlias = providers.gradleProperty("TBOX_PLATFORM_KEY_ALIAS").orNull
val tboxPlatformStorePassword = providers.gradleProperty("TBOX_PLATFORM_STORE_PASSWORD").orNull
val tboxPlatformKeyPassword = providers.gradleProperty("TBOX_PLATFORM_KEY_PASSWORD").orNull
val tboxPlatformSigningValues = listOf(
    tboxPlatformKeystore,
    tboxPlatformAlias,
    tboxPlatformStorePassword,
    tboxPlatformKeyPassword,
)
val hasTboxPlatformSigning = tboxPlatformSigningValues.all { !it.isNullOrBlank() }

android {
    namespace = "com.carlauncher.car_launcher"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.carlauncher.car_launcher"
        minSdk = flutter.minSdkVersion
        // Match the CarCar launcher compatibility target. Its embedded-app
        // implementation intentionally uses system/private Android APIs.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasTboxPlatformSigning) {
            create("tboxPlatform") {
                storeFile = file(tboxPlatformKeystore!!)
                storePassword = tboxPlatformStorePassword
                keyAlias = tboxPlatformAlias!!
                keyPassword = tboxPlatformKeyPassword
            }
        }
    }

    // Two build channels:
    //  - normal: ordinary app, debug-signed. Installs and runs like today.
    //            Signature permissions (INJECT_EVENTS, ADD_TRUSTED_DISPLAY,
    //            MANAGE_ACTIVITY_*) are declared but NOT granted, so embedding
    //            uses the accessibility / freeform fallbacks.
    //  - system: adds android:sharedUserId="android.uid.system" (via the
    //            src/system/ manifest overlay) and is platform-signed. This is
    //            the CarCar-equivalent build: it runs as the system uid and is
    //            granted the signature/privileged permissions directly.
    flavorDimensions += "channel"
    productFlavors {
        create("normal") {
            dimension = "channel"
            isDefault = true
            signingConfig = signingConfigs.getByName("debug")
        }
        create("system") {
            dimension = "channel"
            // Platform key when available, debug key otherwise (compile-check only).
            signingConfig = signingConfigs.findByName("tboxPlatform")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
