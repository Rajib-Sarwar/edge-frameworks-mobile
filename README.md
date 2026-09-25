# edge-frameworks-mobile

Local-first AI infrastructure for building native mobile experiences across iOS and Android.

> Status: v0.2.0 is ready for release.

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

### iOS structured output

Apple Foundation Models supports typed guided generation through `@Generable`.

```swift
import EdgeFrameworks
import FoundationModels

@Generable
struct Summary {
    let title: String
    let bullets: [String]
}

if #available(iOS 26.0, *) {
    let provider = AppleFoundationModelProvider()

    let summary = try await provider.generateStructured(
        EdgeGenerationRequest(
            prompt: "Explain on-device AI in three short bullets."
        ),
        as: Summary.self
    )

    print(summary.title)
    print(summary.bullets)
}
```

When Apple Foundation Models is available, the provider advertises `.structuredOutput` in addition to text generation and streaming.

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

## Core tools

Both platforms expose the same provider-neutral tool contract:

| Concept | Swift | Kotlin |
| --- | --- | --- |
| Metadata | `EdgeToolDefinition(name:description:inputSchemaJSON:)` | `EdgeToolDefinition(name, description, inputSchemaJson)` |
| Text result | `EdgeToolResult(content:)` | `EdgeToolResult(content)` |
| Asynchronous operation | `EdgeTool.call(argumentsJSON:) async throws` | `EdgeTool.call(argumentsJson) suspend` |

Implement `EdgeTool` with a definition and a call method returning `EdgeToolResult`.
The schema is a JSON Schema string; arguments are JSON-encoded strings. The core
stores these strings unchanged. Each tool is responsible for decoding and validating
its arguments and throwing errors on failure. Results can hold plain text or serialized
JSON. Swift tools must also conform to `Sendable`.

The core contract stays provider-neutral. On iOS, `AppleFoundationModelToolAdapter`
bridges an `EdgeTool` into Apple's Foundation Models `Tool` protocol. The adapter
currently supports a conservative JSON Schema subset: object, string, integer, number,
boolean, arrays, required properties, descriptions, and min/max array lengths.

Apple Foundation Models can then call those tools automatically during generation:

```swift
let response = try await provider.generate(
    EdgeGenerationRequest(
        prompt: "Check the weather in New York."
    ),
    tools: [weatherTool]
)
```

When Apple Foundation Models is available, the provider advertises `.toolCalling`.
Android tool registration remains provider-specific future work.

## Local RAG foundation

The core now includes provider-neutral retrieval primitives on both platforms:

| Concept | Swift | Kotlin |
| --- | --- | --- |
| Source document | `EdgeDocument` | `EdgeDocument` |
| Searchable chunk | `EdgeChunk` | `EdgeChunk` |
| Vector | `EdgeEmbedding` | `EdgeEmbedding` |
| Embedding backend | `EdgeEmbeddingProvider` | `EdgeEmbeddingProvider` |
| Vector storage | `EdgeVectorStore` | `EdgeVectorStore` |
| Local store | `EdgeInMemoryVectorStore` | `EdgeInMemoryVectorStore` |
| Retrieval orchestration | `EdgeRetriever` | `EdgeRetriever` |

The retrieval flow is intentionally small:

```text
Document
   ↓
Chunk
   ↓
EmbeddingProvider
   ↓
Embedding
   ↓
VectorStore
   ↓
cosine similarity
   ↓
top-K relevant chunks
```

`EdgeRetriever` indexes chunks by asking an embedding provider for vectors, then
retrieves the most relevant chunks for a query. The in-memory vector store ranks
results with cosine similarity and replaces existing entries by chunk identifier.

The core remains provider-neutral. Real embedding backends plug into this contract on
both platforms: Apple Natural Language on iOS and MediaPipe Text Embedder on Android.
Persistent vector storage, document chunking, and native document import are included
in v0.2. Automatic prompt augmentation and richer ingestion formats remain future layers.

## iOS local RAG demo

The iOS package now includes `AppleNaturalLanguageEmbeddingProvider`, backed by
Apple's built-in Natural Language sentence embeddings. It implements the shared
`EdgeEmbeddingProvider` contract and produces vectors entirely on-device. Apple
documents `NLEmbedding.sentenceEmbedding(for:)` for retrieving sentence embeddings
and `vector(for:)` for obtaining the vector for a string.

The example app demonstrates the full local retrieval path:

```text
Local chunks
   ↓
Apple Natural Language sentence embeddings
   ↓
EdgeFileVectorStore
   ↓
cosine similarity / top-K retrieval
   ↓
retrieved context
   ↓
Apple Foundation Models
   ↓
answer
```

The demo indexes a small local knowledge set, lets you import local documents, shows
the retrieved chunks and similarity scores, and then generates the final answer from
that retrieved context with Apple Foundation Models. No network service or cloud vector
database is required for this flow.

The iOS demo now persists vector data in Application Support and can import UTF-8 text,
Markdown, JSON, and text-based PDF documents through the system document picker. PDF
text extraction uses Apple's PDFKit and preserves source filename and page metadata.
Scanned or image-only PDFs are not OCR'd in v0.2. Larger embedding backends and richer
document parsers remain future work.

## Android local RAG demo

Android now includes `MediaPipeTextEmbeddingProvider`, a reusable
`EdgeEmbeddingProvider` backed by Google AI Edge MediaPipe Text Embedder. The demo
uses the Universal Sentence Encoder model from Google's published MediaPipe model
assets. The Gradle build downloads that model into generated app assets; once the app
and required Gemini Nano model are present on the device, embedding, retrieval, and
generation run locally.

```text
Local chunks
   ↓
MediaPipe Text Embedder / Universal Sentence Encoder
   ↓
EdgeFileVectorStore
   ↓
cosine similarity / top-K retrieval
   ↓
retrieved context
   ↓
Gemini Nano through ML Kit Prompt API
   ↓
answer
```

The Android example mirrors the iOS demo: it indexes the same small local knowledge set,
accepts a question, displays the top retrieved chunks with similarity scores, and passes
only that retrieved context to Gemini Nano for the final response.

The Android demo now persists vector data to app-local storage and can import UTF-8
text, Markdown, JSON, and text-based PDF documents from the system document picker.
PDF extraction is provided by the Apache-2.0-licensed PdfBox-Android port and preserves
source filename and page metadata. Scanned or image-only PDFs are not OCR'd in v0.2.
The embedding model is packaged with the app during the build rather than downloaded by
the runtime RAG code.

## Document import, chunking, and persistence

The local RAG layer now includes portable document chunking and persistent vector
storage on both platforms.

```text
Imported text document
        ↓
EdgeDocument
        ↓
EdgeTextChunker
        ↓
EdgeChunk[]
        ↓
EdgeRetriever
        ↓
on-device embeddings
        ↓
EdgeFileVectorStore
        ↓
persistent local semantic search
```

`EdgeTextChunker` splits a document into overlapping, deterministic text windows and
preserves document metadata such as the source filename and chunk index. The default
configuration uses 800 characters per chunk with 120 characters of overlap, and can be
customized per app.

`EdgeFileVectorStore` persists chunks and their embedding vectors to app-local storage.
The iOS implementation uses an atomically written JSON file; Android uses a compact
binary file with an atomic temp-file replacement. Reopening the store restores the
previously indexed vectors, so imported knowledge survives app restarts.

`EdgeRetriever` can now index either prebuilt chunks or an `EdgeDocument` together
with an `EdgeTextChunker`.

The example apps add native document pickers for plain text, Markdown, JSON, and
text-based PDF files. PDF pages are imported as local documents before chunking, with
`source`, `pageNumber`, `pageCount`, and `parentDocumentID` metadata preserved
through retrieval. Imported content is chunked, embedded on-device, and persisted in the
local vector store.

PDF support in v0.2 is text extraction only. Scanned/image-only PDFs, OCR, Word, HTML,
and richer document parsers remain future work.

## Example apps

Two small example apps exercise the same framework architecture on each platform:

- [iOS · Apple Foundation Models](ios/Examples/AppleFoundationModelsDemo)
- [Android · Gemini Nano](android/examples/gemini-nano-app)

Both examples include runtime capability checks, provider routing, streaming generation, framework-level error handling, and end-to-end local RAG demos. iOS uses Apple Natural Language sentence embeddings with Apple Foundation Models; Android uses MediaPipe Text Embedder with Gemini Nano. The iOS example also includes typed structured output, and the framework supports Apple tool calling. Their build paths are covered by CI.

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
- First Gradle build needs network access to fetch the Universal Sentence Encoder model asset

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
│   ├── edge-frameworks-mediapipe-embeddings/
│   ├── edge-frameworks-pdf/
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

## v0.2.0

- [x] Apple Foundation Models structured output
- [x] structured-output demo flow on iOS
- [x] compile-time structured-generation coverage
- [x] framework-level tool abstraction
- [x] Apple Foundation Models tool calling
- [x] local retrieval / RAG foundation
- [x] iOS on-device embeddings + local RAG demo
- [x] Android on-device embeddings + local RAG demo
- [x] document import + chunking
- [x] persistent local vector storage
- [x] text-based PDF ingestion with page metadata

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
