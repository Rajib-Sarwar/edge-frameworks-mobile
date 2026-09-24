import java.net.URI
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "io.github.rajibsarwar.edgeframeworks.example"
    compileSdk = 35

    defaultConfig {
        applicationId = "io.github.rajibsarwar.edgeframeworks.example"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(project(":edge-frameworks-core"))
    implementation(project(":edge-frameworks-gemini-nano"))
    implementation(project(":edge-frameworks-mediapipe-embeddings"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}


val embeddingModelUrl =
    "https://storage.googleapis.com/mediapipe-models/text_embedder/universal_sentence_encoder/float32/latest/universal_sentence_encoder.tflite"

val generatedEmbeddingAssets =
    layout.buildDirectory.dir("generated/embedding-assets")

android.sourceSets["main"].assets.srcDir(generatedEmbeddingAssets)

val downloadEmbeddingModel by tasks.registering {
    val outputFile = generatedEmbeddingAssets.map {
        it.file("universal_sentence_encoder.tflite")
    }

    outputs.file(outputFile)

    doLast {
        val target = outputFile.get().asFile
        target.parentFile.mkdirs()

        if (!target.exists()) {
            URI(embeddingModelUrl)
                .toURL()
                .openStream()
                .use { input ->
                    target.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
        }
    }
}

tasks.named("preBuild").configure {
    dependsOn(downloadEmbeddingModel)
}
