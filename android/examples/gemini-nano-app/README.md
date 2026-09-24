# Gemini Nano example

A minimal Android app that runs a prompt through the framework's public API:

```text
MainActivity
    ↓
EdgeAgent
    ↓
EdgeProviderRouter
    ↓
GeminiNanoProvider
    ↓
ML Kit GenAI / Gemini Nano
```

## Run

Open the `android` directory in Android Studio and run the `gemini-nano-app` configuration on a supported physical device with Gemini Nano available.

The app intentionally keeps the UI simple. It demonstrates:

- runtime capability detection
- provider routing
- streaming generation
- framework-level error handling
- fully on-device prompting through Gemini Nano
