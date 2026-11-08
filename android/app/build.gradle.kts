import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Debug builds work on a clean open-source checkout, without private signing keys.
// Release builds REQUIRE a private Android signing configuration.
val signingProps = Properties()
val signingPropsFile = rootProject.file("key.properties")
if (signingPropsFile.isFile) {
    signingPropsFile.inputStream().use { signingProps.load(it) }
}
val storePath = signingProps.getProperty("storeFile")
val signingStore = storePath?.let { file(it) }
val signingReady = signingStore?.isFile == true &&
    listOf("storePassword", "keyPassword", "keyAlias").all {
        !signingProps.getProperty(it).isNullOrBlank()
    }

// Fail closed for release tasks. Do not accidentally distribute unsigned/debug-signed APKs.
val requestedRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (requestedRelease && !signingReady) {
    throw GradleException(
        "Android release signing is not configured. See android/key.properties.example " +
        "and docs/RELEASE_AUTOMATION.md. Never commit your keystore."
    )
}

android {
    namespace = "com.example.metersystem"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Keep package ID unchanged to preserve upgrades for existing users.
        applicationId = "app.dayark.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingReady) {
            create("dayarkRelease") {
                keyAlias = signingProps.getProperty("keyAlias")
                keyPassword = signingProps.getProperty("keyPassword")
                storeFile = signingStore
                storePassword = signingProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (signingReady) {
                signingConfig = signingConfigs.getByName("dayarkRelease")
            }
            isMinifyEnabled = true
            isShrinkResources = true
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
