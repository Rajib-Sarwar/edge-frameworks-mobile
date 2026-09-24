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

These values are useful for regressions and relative comparisons, but they are not a complete measurement of accelerator, model-cache, or system-wide memory use.

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
