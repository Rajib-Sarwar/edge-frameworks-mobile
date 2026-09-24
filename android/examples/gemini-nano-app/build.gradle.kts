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
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
}
