import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Данные для подписи release читаем из keystore.properties (НЕ в git)
// play-ops подписывает своим общим upload-ключом через -Pandroid.injected.signing.*;
// в этом случае проектный signingConfig применять нельзя — иначе AGP возьмёт наш
// keystore с чужим паролем и подпись упадёт.
val hasInjectedSigning = project.hasProperty("android.injected.signing.store.file")
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.currencyconverter"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.karpinity.fixxe"
        minSdk = 24
        targetSdk = 36
        versionCode = 64
        versionName = "1.64"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystorePropertiesFile.exists() && !hasInjectedSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        // Сборка для раздачи вне Play (GitHub Releases). Отличается ровно одним:
        // умеет сказать, что вышла новая версия. В Play такое запрещено —
        // приложение оттуда обновляется только механизмом Play
        // (Device and Network Abuse policy), поэтому код проверки лежит в
        // отдельном source set и в bundleRelease не попадает вообще.
        create("standalone") {
            initWith(getByName("release"))
            matchingFallbacks += listOf("release")
        }
    }

    // Один и тот же класс UpdateNotice в двух вариантах: пустышка для Play и
    // рабочая проверка для сборки вне Play. Выбор делает тип сборки.
    sourceSets {
        getByName("debug").java.srcDir("src/noupdate/java")
        getByName("release").java.srcDir("src/noupdate/java")
        getByName("standalone").java.srcDir("src/updatecheck/java")
        getByName("standalone").res.srcDir("src/updatecheck/res")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }
}

dependencies {
    // юнит-тесты на JVM: разбор сумм и другие правила без эмулятора
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.activity:activity-ktx:1.8.2")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.recyclerview:recyclerview:1.3.2")

    // ViewModel + Coroutines
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Retrofit + OkHttp
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
}
