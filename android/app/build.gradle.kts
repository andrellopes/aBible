import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.allc.a_bible"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.allc.a_bible"
        minSdk = 23
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Inject AdMob App ID via manifest placeholder. Falls back to Google's test App ID.
        manifestPlaceholders["ADMOB_APP_ID"] =
            (project.findProperty("ADMOB_APP_ID") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    // Configure signing only if key.properties exists. Otherwise, use debug signing for release.
    var hasKeystore = false
    signingConfigs {
        create("release") {
            val keyProperties = Properties()
            val keyPropertiesFile = rootProject.file("key.properties")
            hasKeystore = keyPropertiesFile.exists()
            if (hasKeystore) {
                keyProperties.load(keyPropertiesFile.inputStream())
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Allows building from source without a private keystore.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
