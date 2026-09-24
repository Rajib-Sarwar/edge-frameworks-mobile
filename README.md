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

## Initial direction

### iOS

- Swift + Swift Concurrency
- Foundation Models provider
- Core ML provider
- room for MLX and ExecuTorch

### Android

- Kotlin + Coroutines
- Gemini Nano / ML Kit GenAI provider
- LiteRT provider
- room for ExecuTorch

## Repository shape

```text
edge-frameworks-mobile/
├── ios/
├── android/
├── docs/
├── examples/
├── benchmarks/
└── .github/
```

## v0.1 goals

- define the core agent and provider contracts
- ship minimal Swift and Kotlin packages
- support streaming and cancellation
- add one provider per platform
- add example apps
- add baseline latency and memory benchmarks

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
