// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must come last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.anshul.newfitstreet"

    // SDK versions
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.anshul.newfitstreet"
        minSdk = 21
        targetSdk = 35
        versionCode = 2
        versionName = "2.0"
    }

    // ✅ Use Java 17 for compilation
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ✅ Release signing configuration (points to android/app/key.jks)
    signingConfigs {
        create("release") {
            storeFile = file("key.jks")          // keystore inside android/app/
            storePassword = "fitstreet"          // your keystore password
            keyAlias = "release-key"             // alias used while creating key.jks
            keyPassword = "fitstreet"            // key password
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // Disable shrinking/minification for now
            isMinifyEnabled = false
            isShrinkResources = false

            // If you add ProGuard later, uncomment:
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
    implementation("javax.annotation:javax.annotation-api:1.3.2")
}

flutter {
    source = "../.."
}
