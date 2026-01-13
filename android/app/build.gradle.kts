// KOD BLOK BAŞLANGICI
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val localPropertiesFile = rootProject.file("local.properties")
    val properties = Properties()
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.reader(Charsets.UTF_8))
    }
    return properties
}

val localProps = localProperties()
val flutterVersionCode = localProps.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProps.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.example.kargala" // Uygulama kimliğiniz
    compileSdk = 36 // <<< HATAYI ÇÖZECEK YÜKSELTME!

    defaultConfig {
        applicationId = "com.example.kargala"
        minSdk = flutter.minSdkVersion       // Minimum Android sürümü
        targetSdk = 33    // Hedef Android sürümü (33 veya 34 de olabilir, sorun değil)
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true // Büyük uygulamalar için gerekli
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // Veya kendi release imzanız
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Diğer bağımlılıklar buraya eklenebilir
    implementation("androidx.multidex:multidex:2.0.1") // MultiDex için gerekli
}
// KOD BLOK SONU
