import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only once google-services.json is
// present, so the project still builds before Firebase credentials are
// supplied (the gateway then falls back to the native game).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Optional release signing from android/key.properties.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.stonewatch.watchgame"

    // compileSdk 36 for plugin compatibility; targetSdk 35; minSdk 26
    // is the floor the current Firebase / AppsFlyer stack supports.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        // flutter_local_notifications needs java.time.* desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.stonewatch.watchgame"
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Dart-level obfuscation is applied at build time via
            // --obfuscate; R8 minify is left off so Firebase / AppsFlyer
            // reflection keeps working without extra keep-rules.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // WindowCompat / WindowInsetsControllerCompat / WindowInsetsAnimationCompat
    // for the edge-to-edge window + keyboard-inset bridge in MainActivity.
    implementation("androidx.core:core-ktx:1.15.0")
}

flutter {
    source = "../.."
}
