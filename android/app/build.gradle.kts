plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aura"
    compileSdk = flutter.compileSdkVersion

    // NÃO fixe a NDK aqui. O aviso vermelho do FlutLab sobre a
    // shared_preferences_android exigir a 27.0.12077973 é sobre metadado, não
    // sobre compilação: o plugin não tem uma linha de código nativo (zero .c,
    // .cpp, .h, .so, CMakeLists.txt) e não declara ndkVersion nenhuma no
    // próprio build.gradle — conferido no ~/.pub-cache. Ou seja, não existe
    // .so dele para a NDK proteger.
    //
    // Fixar a 27 troca um aviso cosmético por risco real: o ambiente de build
    // passa a precisar daquela NDK instalada, o que não dá para garantir no
    // FlutLab, e o build falha antes de compilar se ela não estiver lá. O APK
    // que funciona no aparelho foi gerado SEM o pin. Histórico da ida e da
    // volta em docs/DECISOES.md §5.
    ndkVersion = flutter.ndkVersion

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
