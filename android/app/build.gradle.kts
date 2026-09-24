plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase: with android/app/google-services.json (git-ignored, provided by the
// operator on the build machine) the default FirebaseApp is configured natively,
// which background / killed-app push delivery relies on. Without the file the
// app falls back to the XATBOX_FIREBASE_* dart-defines (env/README.md).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: android/key.properties (git-ignored) points at the upload
// keystore in android/app. Both files are copied to every build machine.
// Parsed by hand: inside a Gradle script `java` names the Java extension, not
// the java.* package.
val releaseSigning: Map<String, String>? = rootProject.file("key.properties")
    .takeIf { it.exists() }
    ?.readLines()
    ?.filter { it.contains('=') && !it.trimStart().startsWith("#") }
    ?.associate { it.substringBefore('=').trim() to it.substringAfter('=').trim() }

android {
    namespace = "kz.xatbox.xatbox_mobile"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kz.xatbox.xatbox_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        releaseSigning?.let { props ->
            create("release") {
                keyAlias = props.getValue("keyAlias")
                keyPassword = props.getValue("keyPassword")
                storeFile = file(props.getValue("storeFile"))
                storePassword = props.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // The release key must stay the same for every build, otherwise
            // installed apps refuse the update. Without android/key.properties
            // the build falls back to the debug key (fine for local tests only).
            signingConfig = if (releaseSigning != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 (on by default for Flutter release builds). Keep rules for
            // classes reached by reflection/JNI/persisted JSON: proguard-rules.pro.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // local_auth (BiometricPrompt): LaunchTheme must be an AppCompat theme.
    implementation("androidx.appcompat:appcompat:1.7.1")
}
