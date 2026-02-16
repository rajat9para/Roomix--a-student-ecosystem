import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

// Load local.properties for optional configuration
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader(Charsets.UTF_8).use { reader ->
        localProperties.load(reader)
    }
}

// Compute MapMyIndia key once at configuration time so it can be used for
// manifestPlaceholders and also injected into Flutter dart defines.
val mapmyindiaKey: String = System.getenv("MAPMYINDIA_API_KEY")
    ?: localProperties.getProperty("mapmyindia.api.key", "")

// Encode dart-defines the same way Flutter does (base64 per entry) and merge
// into any existing definitions that were passed via CLI.
fun encodeDartDefine(define: String): String =
    Base64.getEncoder().encodeToString(define.toByteArray(Charsets.UTF_8))

fun mergeDartDefines(existing: String?, extraEncoded: String): String =
    when {
        existing.isNullOrBlank() -> extraEncoded
        existing.split(',').contains(extraEncoded) -> existing
        else -> "$existing,$extraEncoded"
    }

if (mapmyindiaKey.isNotEmpty()) {
    val existingDartDefines = project.findProperty("dart-defines")?.toString()
    val encodedDefine = encodeDartDefine("MAPMYINDIA_API_KEY=$mapmyindiaKey")
    project.extensions.extraProperties["dart-defines"] =
        mergeDartDefines(existingDartDefines, encodedDefine)
}

// If running a release task, require that a MapMyIndia key is present to avoid
// shipping builds that will fail at runtime with missing map functionality.
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (isReleaseBuild && mapmyindiaKey.isEmpty()) {
    throw org.gradle.api.GradleException("MAPMYINDIA_API_KEY is required for release builds. Set MAPMYINDIA_API_KEY env var or add mapmyindia.api.key to android/local.properties.")
}

android {
    namespace = "com.company.roomix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.company.roomix"
        // minSdk 23 required for Firebase Auth
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for Firebase
        multiDexEnabled = true

        // MapMyIndia API key injected into Android manifest via placeholders
        manifestPlaceholders["mapmyindiaApiKey"] = mapmyindiaKey
    }

    buildTypes {
        release {
            // Signing with debug keys for now
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
