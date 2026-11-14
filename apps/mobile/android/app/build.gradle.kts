import java.net.URI
import java.security.MessageDigest
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (releaseBuildRequested) {
    throw GradleException(
        "android/key.properties is required for PharmaFlow release signing."
    )
}

android {
    namespace = "com.example.pharmaflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.pharmaflow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appName"] = "PharmaFlow Dev"
        }

        release {
            manifestPlaceholders["appName"] = "PharmaFlow"
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
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
    implementation("cz.adaptech.tesseract4android:tesseract4android:4.9.0")
}

val priceOcrAssets = layout.buildDirectory.dir("generated/priceOcrAssets")
val preparePriceOcrAssets = tasks.register("preparePriceOcrAssets") {
    val revision = "e12c65a915945e4c28e237a9b52bc4a8f39a0cec"
    val models = mapOf(
        "fas" to "99e420969b5ddd2cb135b416316a7ed417c59c4faf9e0d28941348f6448114df",
        "eng" to "8280aed0782fe27257a68ea10fe7ef324ca0f8d85bd2fd145d1c2b560bcb66ba",
    )
    inputs.property("revision", revision)
    inputs.property("models", models)
    outputs.dir(priceOcrAssets)
    doLast {
        val directory = priceOcrAssets.get().dir("tessdata").asFile.apply { mkdirs() }
        fun digest(file: File) = MessageDigest.getInstance("SHA-256")
            .digest(file.readBytes()).joinToString("") { "%02x".format(it) }
        for ((language, expected) in models) {
            val file = directory.resolve("$language.traineddata")
            if (file.exists() && digest(file) == expected) continue
            val temporary = directory.resolve("$language.download")
            try {
                val url = URI(
                    "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/$revision/$language.traineddata",
                ).toURL()
                val connection = url.openConnection().apply {
                    connectTimeout = 15000
                    readTimeout = 30000
                }
                connection.getInputStream().use { input ->
                    temporary.outputStream().use { output -> input.copyTo(output) }
                }
                check(digest(temporary) == expected) { "OCR asset checksum mismatch: $language" }
                temporary.copyTo(file, overwrite = true)
            } finally {
                temporary.delete()
            }
        }
    }
}

android.sourceSets.getByName("main").assets.srcDir(priceOcrAssets)
tasks.named("preBuild").configure { dependsOn(preparePriceOcrAssets) }
