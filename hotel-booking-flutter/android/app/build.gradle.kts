import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

fun resolveSigningValue(propertyKey: String, envKey: String): String? {
    val fromProps = keystoreProperties.getProperty(propertyKey)?.trim()
    if (!fromProps.isNullOrEmpty()) {
        return fromProps
    }
    val fromEnv = System.getenv(envKey)?.trim()
    if (!fromEnv.isNullOrEmpty()) {
        return fromEnv
    }
    return null
}

val releaseStoreFilePath = resolveSigningValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = resolveSigningValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = resolveSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = resolveSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")

val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrEmpty() &&
    !releaseStorePassword.isNullOrEmpty() &&
    !releaseKeyAlias.isNullOrEmpty() &&
    !releaseKeyPassword.isNullOrEmpty() &&
    file(releaseStoreFilePath).exists()

android {
    namespace = "com.bronc3.hotel_booking_flutter"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.bronc3.hotel_booking_flutter"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Minh Thanh Villa DEV")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Minh Thanh Villa STAGING")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Minh Thanh Villa")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Never sign production/release builds with the debug signing key.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val isReleaseTaskRequested = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }
    if (isReleaseTaskRequested && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured. Provide android/key.properties or " +
            "environment variables ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
            "ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD. Refusing to sign release build with debug key."
        )
    }
}

flutter {
    source = "../.."
}
