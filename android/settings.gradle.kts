pluginManagement {
    val flutterSdkPath =
        run {
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
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")

// Force compileSdk 36 on all Android library subprojects.
// Required because file_picker v8.x declares compileSdkVersion 34 but
// flutter_plugin_android_lifecycle now requires API 36 or higher.
// Using beforeProject+afterEvaluate because legacy Groovy plugins use
// 'apply plugin:' which doesn't trigger plugins.withId().
gradle.beforeProject {
    afterEvaluate {
        if (pluginManager.hasPlugin("com.android.library")) {
            @Suppress("UnstableApiUsage")
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
                compileSdk = 36
            }
        }
    }
}
