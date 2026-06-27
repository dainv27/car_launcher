plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.carlauncher.car_launcher"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("tboxPlatform") ?: signingConfigs.getByName("debug")
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
