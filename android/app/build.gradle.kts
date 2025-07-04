import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    namespace = "com.bluepdf.blue_pdf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bluepdf.blue_pdf"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Release config for publishing
        create("release") {
            val storePath = keystoreProperties.getProperty("storeFile")
            println("✅ Using keystore path: $storePath")
            storeFile = file(storePath ?: throw GradleException("Missing 'storeFile'"))
            storePassword = keystoreProperties["storePassword"]?.toString() ?: throw GradleException("Missing 'storePassword'")
            keyAlias = keystoreProperties["keyAlias"]?.toString() ?: throw GradleException("Missing 'keyAlias'")
            keyPassword = keystoreProperties["keyPassword"]?.toString() ?: throw GradleException("Missing 'keyPassword'")
        }

        // Debug config fallback (auto-generated debug key)
        getByName("debug") {
            // Uses default debug keystore
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packagingOptions {
        resources {
            excludes += setOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
}
