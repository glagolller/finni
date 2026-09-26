plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStore = System.getenv("FINNI_KEYSTORE")
val releasePassword = System.getenv("FINNI_STORE_PASSWORD")
val releaseAlias = System.getenv("FINNI_KEY_ALIAS")
val releaseSigningReady = listOf(releaseStore, releasePassword, releaseAlias)
    .all { !it.isNullOrBlank() }

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") }) {
        check(releaseSigningReady) {
            "Release requires FINNI_KEYSTORE, FINNI_STORE_PASSWORD and FINNI_KEY_ALIAS."
        }
    }
}

android {
    namespace = "ru.finni.pet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.finni.pet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = file(releaseStore!!)
                storePassword = releasePassword
                keyAlias = releaseAlias
                keyPassword = releasePassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningReady) {
                signingConfig = signingConfigs.getByName("release")
            }
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
