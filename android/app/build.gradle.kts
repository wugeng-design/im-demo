plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.imsdk.demo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.imsdk.demo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.add("armeabi-v7a")
            abiFilters.add("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("release-keystore.jks")
            storePassword = System.getenv("RELEASE_STORE_PASSWORD") ?: "changeit"
            keyAlias = System.getenv("RELEASE_KEY_ALIAS") ?: "release"
            keyPassword = System.getenv("RELEASE_KEY_PASSWORD") ?: "changeit"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        resources {
            excludes += listOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/LICENSE",
                "/META-INF/LICENSE.txt",
                "/META-INF/NOTICE",
                "/META-INF/NOTICE.txt",
                "META-INF/services/javax.annotation.processing.Processor"
            )
        }
    }

    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}
