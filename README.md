# edge-frameworks-mobile

Local-first AI infrastructure for building native mobile experiences across iOS and Android.

> Status: early development. APIs will change quickly until the first tagged release.

## Why this exists

Mobile AI is moving toward on-device execution, but the platform stacks are fragmented. iOS and Android expose different runtimes, model formats, hardware paths, and system capabilities.

`edge-frameworks-mobile` aims to provide a small, native-first abstraction layer for:

- model providers
- streaming generation
- structured output
- tool calling
- local memory and retrieval
- runtime capability checks
- cancellation and lifecycle handling
- observability and benchmarks

The goal is not to hide iOS and Android. The goal is to make the shared AI concepts consistent while keeping each platform native.

## Current providers

### iOS

- Apple Foundation Models
- Core ML — planned
- MLX — planned
- ExecuTorch — planned

### Android

- Gemini Nano through ML Kit GenAI Prompt API
- LiteRT — planned
- ExecuTorch — planned

## Quick start

### iOS

```swift
if #available(iOS 26.0, *) {
    let provider = AppleFoundationModelProvider()
    let router = EdgeProviderRouter(providers: [provider])
    let agent = EdgeAgent(router: router)

    let response = try await agent.run(
        EdgeGenerationRequest(
            prompt: "Summarize this note in three bullets."
        )
    )

    print(response.text)
}
```

### Android

```kotlin
val provider = GeminiNanoProvider()
val router = EdgeProviderRouter(listOf(provider))
val agent = EdgeAgent(router)

val response = agent.run(
    EdgeGenerationRequest(
        prompt = "Summarize this note in three bullets."
    )
)

println(response.text)
```

The Gemini Nano provider advertises capabilities only when the on-device model is ready. Downloadable or currently downloading models are surfaced as `ModelNotReady`; unsupported devices are surfaced as `ProviderUnavailable`.

The provider currently uses ML Kit GenAI Prompt API `1.0.0-beta4` and requires Android API 26 or newer.

## Example apps

Two small example apps exercise the same framework architecture on each platform:

- [iOS · Apple Foundation Models](ios/Examples/AppleFoundationModelsDemo)
- [Android · Gemini Nano](android/examples/gemini-nano-app)

Both examples include runtime capability checks, provider routing, streaming generation, and framework-level error handling. Their build paths are covered by CI.

## Running the examples

### iOS · Apple Foundation Models

The iOS example uses XcodeGen, so the generated `.xcodeproj` is not committed to the repository.

From a fresh clone:

```bash
cd ios/Examples/AppleFoundationModelsDemo

brew install xcodegen   # first time only
xcodegen generate
open AppleFoundationModelsDemo.xcodeproj
```

In Xcode, select a supported physical iPhone and run the `AppleFoundationModelsDemo` scheme.

Requirements:

- Xcode 26 or newer
- iOS 26 or newer
- Apple Foundation Models available on the device

### Android · Gemini Nano

Open the `android` directory in Android Studio, connect a supported physical Android device, and run:

```text
examples:gemini-nano-app
```

Requirements:

- Android API 26 or newer
- Gemini Nano / ML Kit GenAI available on the device

## Benchmarks

Physical-device provider baselines are documented in [docs/benchmarks.md](docs/benchmarks.md). The current baseline set includes Apple Foundation Models on iPhone 17 Pro Max and Gemini Nano on Samsung Galaxy Z Fold7.

## Repository shape

```text
edge-frameworks-mobile/
├── ios/
│   └── Examples/
│       └── AppleFoundationModelsDemo/
├── android/
│   ├── edge-frameworks-core/
│   ├── edge-frameworks-gemini-nano/
│   └── examples/
│       └── gemini-nano-app/
├── docs/
├── benchmarks/
└── .github/
```

## v0.1 goals

- [x] define the core agent and provider contracts
- [x] ship minimal Swift and Kotlin packages
- [x] support streaming and cancellation
- [x] add one provider per platform
- [x] add example apps
- [x] add baseline latency and memory benchmarks

## Principles

1. Native-first
2. Local-first
3. Small public API surface
4. Explicit platform capabilities
5. Measurable performance
6. Easy to test and extend

## Maintainer

Created and maintained by [Rajib Sarwar](https://github.com/Rajib-Sarwar).

## License

Apache License 2.0.
