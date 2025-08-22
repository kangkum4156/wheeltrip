plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // Flutter 플러그인은 반드시 마지막
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.wheeltrip"

    // 숫자로 명시 (일부 플러그인이 변수 참조를 싫어함)
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.wheeltrip"
        minSdk = 23            // flutter_foreground_task 최소 21 이상이면 OK
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

flutter {
    source = "../.."
}

dependencies {
    // desugaring 라이브러리
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
