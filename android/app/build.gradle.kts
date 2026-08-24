import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mapsPropertiesFile = rootProject.file("maps.properties")
val mapsProperties = Properties().apply {
    if (mapsPropertiesFile.exists()) {
        FileInputStream(mapsPropertiesFile).use { load(it) }
    }
}

val teamSigningFile = rootProject.file("team-signing.properties")
val teamSigningProperties = Properties().apply {
    if (teamSigningFile.exists()) {
        FileInputStream(teamSigningFile).use { load(it) }
    }
}

android {
    namespace = "com.example.my_find"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_find"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_maps_flutter 2.18 requires Android API 24 or newer.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] =
            mapsProperties.getProperty("MAPS_API_KEY", "")
    }

    signingConfigs {
        create("teamDebug") {
            if (teamSigningFile.exists()) {
                storeFile = rootProject.file(
                    teamSigningProperties.getProperty("storeFile"),
                )
                storePassword = teamSigningProperties.getProperty("storePassword")
                keyAlias = teamSigningProperties.getProperty("keyAlias")
                keyPassword = teamSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            if (teamSigningFile.exists()) {
                signingConfig = signingConfigs.getByName("teamDebug")
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
