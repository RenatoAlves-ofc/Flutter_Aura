plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aura"
    compileSdk = flutter.compileSdkVersion

    // O build do FlutLab avisa que shared_preferences_android "exige" a NDK
    // 27.0.12077973, enquanto o flutter.ndkVersion do 3.32 é a 26.3.11579264.
    // O aviso é inofensivo e está sendo ignorado de propósito:
    //
    // - a causa real do app fechar ao abrir era outra (APK de 32 bits em
    //   aparelho arm64), já corrigida escolhendo o alvo `android arm64`;
    // - o APK arm64 gerado com esta configuração instala e roda em Android 16;
    // - o projeto não traz nenhuma dependência com código nativo próprio, então
    //   as únicas libs .so vêm da engine do Flutter, que já cuida do
    //   alinhamento de 16 KB exigido pelo Android 15+.
    //
    // Fixar a 27 aqui exigiria que o ambiente de build tivesse essa NDK
    // instalada — o que não dá para garantir no FlutLab, e uma falha de build
    // custaria bem mais do que duas linhas de aviso.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.aura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
