pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0" apply false
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

val flutterPluginFiles = listOf(
    file("../.flutter-plugins-dependencies"),
    file("../.flutter-plugins"),
).filter { it.exists() }

if (flutterPluginFiles.isNotEmpty()) {
    val localAppData = System.getenv("LOCALAPPDATA")
    if (!localAppData.isNullOrBlank()) {
        val windowsPubCachePathRegex =
            Regex("""[A-Za-z]:([\\]+)Users\1[^\\]+\1AppData\1Local\1Pub\1Cache\1hosted\1pub\.dev\1""")
        val currentPubCachePath = "$localAppData\\Pub\\Cache\\hosted\\pub.dev\\"

        flutterPluginFiles.forEach { pluginFile ->
            val originalContent = pluginFile.readText()
            val normalizedContent = windowsPubCachePathRegex.replace(originalContent) { matchResult ->
                val separator = matchResult.groupValues[1]
                currentPubCachePath.replace("\\", separator)
            }
            if (normalizedContent != originalContent) {
                pluginFile.writeText(normalizedContent)
            }
        }
    }
}

apply(plugin = "dev.flutter.flutter-plugin-loader")

include(":app")
