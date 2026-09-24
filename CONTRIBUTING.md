# Contributing

Thanks for your interest in contributing to `edge-frameworks-mobile`.

This project is still early, so the most useful contributions right now are focused, well-scoped changes that improve the core abstractions, platform integrations, tests, documentation, or examples.

## Before opening a pull request

- search existing issues and pull requests
- keep changes narrow enough to review comfortably
- include tests when behavior changes
- update documentation when public APIs change
- avoid introducing platform abstractions that hide important native behavior

## Development principles

The project is intentionally:

- native-first
- local-first
- explicit about platform capabilities
- conservative about public API surface
- performance-aware
- testable by default

## Commit messages

Use short conventional-style commit messages where practical:

```text
feat(ios): add streaming provider contract
fix(android): cancel generation when scope is cancelled
docs: explain provider lifecycle
test: cover model capability fallback
```

## Pull requests

A good pull request should explain:

1. what problem it solves
2. why the chosen approach fits the architecture
3. platform-specific tradeoffs
4. how it was tested
5. any API or compatibility impact

Small pull requests are preferred over large mixed changes.

## Platform expectations

### iOS

- Swift
- Swift Concurrency
- XCTest
- Swift Package Manager

### Android

- Kotlin
- Coroutines
- JUnit
- Gradle

## Discussions and issues

Use issues for concrete bugs, features, benchmarks, and architectural questions.

For larger changes, open an issue first so the design can be discussed before significant implementation work begins.

## Code of conduct

Be respectful, technical, and constructive. Feedback should focus on the code, architecture, behavior, and user impact.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
