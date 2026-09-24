# Benchmark protocol

The framework includes lightweight benchmark runners on iOS and Android so provider performance can be measured with the same basic shape.

## Metrics

Each run records:

- average request latency
- p50 request latency
- p95 request latency
- average memory delta during generation
- provider identifier
- iteration count

The current memory metric is intentionally lightweight:

- iOS samples process resident memory before and after each request.
- Android samples JVM heap usage before and after each request.

These values are useful for regressions and relative comparisons, but they are not a complete measurement of accelerator, model-cache, or system-wide memory use. The iOS and Android memory numbers also come from different measurement mechanisms, so they should not be treated as directly comparable cross-platform memory usage.

## Recommended device protocol

For publishable provider baselines:

1. use a physical device
2. record device model and OS version
3. confirm the on-device model is already downloaded and ready
4. close unrelated foreground apps
5. use the same prompt for every provider comparison
6. run one warm-up request that is not included in results
7. run at least 10 measured iterations
8. record whether Low Power Mode or battery saver is enabled
9. report both latency and memory metrics
10. do not compare simulator numbers with physical-device numbers

## Example prompt

```text
Explain on-device AI in three short bullets.
```

## Physical-device baselines

These are provider baselines captured from the example apps on physical hardware. They are useful for tracking framework/provider behavior on known devices; they are not intended as a universal ranking of platform or model performance.

| Platform | Device | OS | Provider | Iterations | Avg latency | P50 | P95 | Avg memory delta |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| iOS | iPhone 17 Pro Max | iOS 27.0 | `apple.foundation-models` | 10 | 908.4 ms | 884.7 ms | 1,106.3 ms | ~0.00 MB |
| Android | Samsung Galaxy Z Fold7 (SM-F966U) | Android 16 | `google.gemini-nano` | 10 | 4,493.0 ms | 4,473.4 ms | 4,608.9 ms | 0.1 MB |

Test prompt:

```text
Explain on-device AI in three short bullets.
```

Each baseline used one unmeasured warm-up request followed by 10 measured requests. Power-mode state was not recorded for these first baselines.

The iOS example currently reports the generic hardware family name (`iPhone`) from `UIDevice.current.model`; the specific iPhone 17 Pro Max model above was recorded from the physical test device metadata.

## Swift

```swift
let summary = try await EdgeBenchmarkRunner().run(
    provider: provider,
    request: EdgeGenerationRequest(
        prompt: "Explain on-device AI in three short bullets."
    ),
    iterations: 10
)

print(summary)
```

## Kotlin

```kotlin
val summary = EdgeBenchmarkRunner().run(
    provider = provider,
    request = EdgeGenerationRequest(
        prompt = "Explain on-device AI in three short bullets."
    ),
    iterations = 10
)

println(summary)
```

## Publishing results

Do not commit benchmark numbers produced by CI as device baselines. CI validates the benchmark code; provider baselines should come from supported physical hardware and include the device metadata needed to reproduce the result.
