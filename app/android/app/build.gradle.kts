plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningVariables = listOf(
    "RELEASE_KEYSTORE_PATH",
    "RELEASE_KEYSTORE_PASSWORD",
    "RELEASE_KEY_ALIAS",
    "RELEASE_KEY_PASSWORD",
)
val missingReleaseSigningVariables = releaseSigningVariables.filter { System.getenv(it).isNullOrBlank() }

// Keep debug/test builds credential-free, but reject every release packaging task.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project.path == ":app" &&
            it.name.contains("release", ignoreCase = true) &&
            (it.name.startsWith("assemble", ignoreCase = true) ||
                it.name.startsWith("bundle", ignoreCase = true) ||
                it.name.startsWith("package", ignoreCase = true)) }) {
        if (missingReleaseSigningVariables.isNotEmpty()) {
            throw GradleException("Release signing unavailable: missing ${missingReleaseSigningVariables.joinToString()}")
        }
        if (!file(System.getenv("RELEASE_KEYSTORE_PATH")).isFile) {
            throw GradleException("Release signing unavailable: RELEASE_KEYSTORE_PATH is not a file")
        }
    }
}

android {
    namespace = "com.lendentracker.lenden_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.lendentracker.lenden_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    flavorDimensions += "testIsolation"
    productFlavors {
        create("acceptance") {
            dimension = "testIsolation"
            applicationIdSuffix = ".acceptance"
        }
        create("standard") {
            dimension = "testIsolation"
        }
    }
    signingConfigs {
        create("production") {
            if (missingReleaseSigningVariables.isEmpty()) {
                storeFile = file(System.getenv("RELEASE_KEYSTORE_PATH"))
                storePassword = System.getenv("RELEASE_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("RELEASE_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("production")
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
