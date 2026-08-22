plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aura"
    compileSdk = flutter.compileSdkVersion

    // Mantém o build Android alinhado ao aviso emitido pelo plugin
    // shared_preferences_android no FlutLab. O APK já compilava, mas fixar a NDK
    // remove o ruído vermelho do build e deixa a exigência explícita.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Identidade do app na loja e no aparelho. Só o applicationId muda: o
        // `namespace` acima segue com.example.aura de propósito, porque ele é
        // quem resolve o `android:name=".MainActivity"` do manifesto. Trocar o
        // namespace exigiria mover também o pacote Kotlin do MainActivity — e
        // errar isso quebra o app na abertura, justamente o sintoma que já
        // custou caro neste projeto.
        applicationId = "br.com.renatoalves.aura"
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
