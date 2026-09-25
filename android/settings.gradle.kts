pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "edge-frameworks-mobile-android"
include(":edge-frameworks-core")
include(":edge-frameworks-gemini-nano")
include(":edge-frameworks-mediapipe-embeddings")
include(":edge-frameworks-pdf")
include(":edge-frameworks-documents")
include(":examples:gemini-nano-app")
