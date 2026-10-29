import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
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
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bluepdf.blue_pdf"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += ""
                arguments += "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
            }
        }

    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storePath = keystoreProperties.getProperty("storeFile")
                storeFile = file(storePath ?: throw GradleException("Missing 'storeFile'"))
                storePassword = keystoreProperties["storePassword"]?.toString() ?: throw GradleException("Missing 'storePassword'")
                keyAlias = keystoreProperties["keyAlias"]?.toString() ?: throw GradleException("Missing 'keyAlias'")
                keyPassword = keystoreProperties["keyPassword"]?.toString() ?: throw GradleException("Missing 'keyPassword'")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            // Without key.properties (CI, fresh clones) release builds are debug-signed and not uploadable.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
}
