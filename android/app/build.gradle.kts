// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must come last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.newfitstreet"

    // SDK versions
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.newfitstreet"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        getByName("release") {
            // TEMP: use debug signing so flutter run --release works
            signingConfig = signingConfigs.getByName("debug")

            // ✅ Correct Kotlin DSL flags - enabled with ProGuard rules
            isMinifyEnabled = true
            isShrinkResources = true

            // ✅ Kotlin DSL syntax for proguardFiles
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Annotation issues handled by ProGuard rules in proguard-rules.pro
}

flutter {
    source = "../.."
}
