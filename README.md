# edge-frameworks-mobile

Local-first AI infrastructure for building native mobile experiences across iOS and Android.

> Status: v0.3.0 is released. v0.4.0 development is in progress.

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
Persistent vector storage, document chunking, native document import, collection
management, source tracking, OCR ingestion, and source-level incremental re-indexing are
now part of the framework.

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

The iOS demo persists vector data in Application Support and can import UTF-8 text,
Markdown, JSON, PDF, DOCX, HTML, and text-bearing image files through the system
document picker.
PDF pages use PDFKit with Apple Vision OCR fallback for scanned pages. DOCX text is
extracted from WordprocessingML inside the package, and HTML is converted to readable
text before chunking and indexing.

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

The Android demo persists vector data to app-local storage and can import UTF-8 text,
Markdown, JSON, PDF, DOCX, HTML, and text-bearing image files from the system document
picker. PDF
pages use PdfBox-Android with bundled ML Kit OCR fallback. DOCX text is extracted from
WordprocessingML and HTML is parsed with jsoup before chunking and indexing. The
embedding model is packaged with the app during the build rather than downloaded by the
runtime RAG code.

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
binary file with temp-file replacement. Reopening the store restores the
previously indexed vectors, so imported knowledge survives app restarts.

`EdgeRetriever` can now index either prebuilt chunks or an `EdgeDocument` together
with an `EdgeTextChunker`.

The example apps add native document pickers for plain text, Markdown, JSON, PDF, DOCX,
HTML, and text-bearing image files. PDF pages and other imported sources are converted
to `EdgeDocument` values before chunking. Source and format metadata are preserved
through retrieval, and imported content is embedded on-device and persisted in the local
vector store.

v0.3 adds OCR fallback for scanned/image-only PDF pages plus DOCX and HTML ingestion.
DOCX imports the main WordprocessingML document text while preserving source metadata;
HTML is converted to readable text before chunking. Standalone image files are OCR'd
locally before entering the same chunk/embed/persist pipeline.

## Scanned PDF / OCR ingestion

The PDF importers now use a hybrid extraction pipeline:

```text
PDF page
   ↓
embedded text available?
   ├── yes → direct extraction
   └── no  → render page image
                ↓
              OCR
                ↓
           EdgeDocument
                ↓
       chunk / embed / persist
```

On iOS, OCR fallback uses Apple Vision text recognition. On Android, the PDF module
renders the page with PdfBox-Android and uses the bundled ML Kit Text Recognition model.
Both implementations preserve `source`, `pageNumber`, `pageCount`,
`parentDocumentID`, `extractionMethod`, and `ocrEngine` metadata.

OCR is intentionally used only for PDF pages where embedded text extraction returns no
text, avoiding unnecessary OCR work for normal digital PDFs.

## DOCX / HTML ingestion

The document pipeline now accepts local Word and HTML knowledge sources:

```text
DOCX
  ↓
ZIP package
  ↓
word/document.xml
  ↓
WordprocessingML text
  ↓
EdgeDocument

HTML
  ↓
platform HTML parser
  ↓
readable text
  ↓
EdgeDocument
```

On iOS, DOCX ZIP access uses ZIPFoundation and HTML conversion uses the platform
attributed-string HTML importer. On Android, DOCX uses the platform ZIP/XML stack and
HTML parsing uses jsoup. Both formats preserve `source`, `mediaType`,
`documentFormat`, and `extractionMethod` metadata before chunking and embedding.

The DOCX slice focuses on the main `word/document.xml` body. Headers, footers,
comments, tracked-change semantics, and embedded media are not yet modeled separately.

## Image ingestion

v0.3 can ingest standalone image files as local knowledge by extracting visible text
before chunking and embedding.

```text
JPEG / PNG / HEIC / TIFF
        ↓
platform image decoder
        ↓
on-device OCR
        ↓
EdgeDocument
        ↓
EdgeTextChunker
        ↓
text embeddings
        ↓
persistent local RAG
```

On iOS, image decoding uses ImageIO and OCR uses Apple Vision. On Android, image
selection is decoded through ML Kit's `InputImage.fromFilePath` path and text is
recognized by the bundled ML Kit Text Recognition model. Imported image documents keep
`source`, `mediaType`, `documentFormat=image`, `extractionMethod=ocr`, and
`ocrEngine` metadata.

This v0.3 image slice is OCR-oriented ingestion for images that contain readable text,
such as screenshots, receipts, forms, signs, and photographed notes. It does **not**
yet provide semantic visual embeddings, image captioning, or general scene/object
understanding for images with no text.

## Persistent source catalog and incremental indexing

v0.3 now includes a durable catalog for knowledge collections and imported sources, plus
content-fingerprint-based change detection.

```text
local source bytes / text
        ↓
SHA-256 fingerprint
        ↓
EdgeKnowledgeSource
        ↓
EdgeFileKnowledgeCatalog
        ↓
fingerprint unchanged?
   ├── yes → skip embedding / indexing
   └── no  → remove previous source chunks
             re-chunk / re-embed / persist
             update source catalog
```

`EdgeKnowledgeSource` records the collection, logical source identifier, content
fingerprint, indexed document IDs, metadata, and last-indexed timestamp.
`EdgeFileKnowledgeCatalog` persists collections and sources locally and restores them
after app restart.

`EdgeIncrementalIndexer` compares the incoming source fingerprint with the persisted
catalog. Unchanged sources return `unchanged` without re-running the embedding provider.
Changed sources remove their previously indexed chunks, index the new documents, and
replace the catalog entry. Removing a source or collection also removes the associated
vector-store content.

Incremental indexing now keeps per-document fingerprints inside each source. When a
multi-document source changes, unchanged documents keep their existing vector entries
while changed, added, or removed documents are updated independently. PDF imports use
stable page keys, so changing one page does not require re-embedding every unchanged
page. Older persisted catalogs without per-document fingerprints remain readable and are
upgraded on the next changed-source sync.

## Automatic RAG orchestration

v0.4 starts by collapsing the manual retrieve → context-build → generate sequence into
one provider-neutral API.

```text
query
  ↓
EdgeRetriever
  ↓
top-K / filter / minimum score
  ↓
context builder
  ↓
EdgeAgent
  ↓
generation provider
  ↓
EdgeRAGResult
```

Swift:

```swift
let rag = EdgeRAG(
    retriever: retriever,
    agent: agent
)

let result = try await rag.run(
    query: "When does my flight leave?",
    in: travelCollection,
    topK: 3
)

print(result.answer)
print(result.retrievedResults)
```

Kotlin:

```kotlin
val rag = EdgeRAG(
    retriever = retriever,
    agent = agent
)

val result = rag.run(
    query = "When does my flight leave?",
    collection = travelCollection,
    topK = 3
)

println(result.answer)
println(result.retrievedResults)
```

`EdgeRAGRequest` supports an optional collection, vector filter, top-K, minimum score,
and custom system prompt. `EdgeRAGResult` returns the final answer together with the
retrieved search results and the exact local context passed into generation.

The default system instruction tells the model to answer only from supplied local
context and to say when the local knowledge is insufficient. Apps can replace that
instruction when they need domain-specific behavior.

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
│   ├── edge-frameworks-documents/
│   ├── edge-frameworks-images/
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

## Knowledge collections

v0.3 starts by adding source lifecycle and collection-scoped RAG. Both platforms now
share an `EdgeKnowledgeCollection` model plus `EdgeVectorFilter` for filtering and
removing indexed chunks.

```text
EdgeKnowledgeCollection
        ↓
document import / chunking
        ↓
collection metadata on each chunk
        ↓
EdgeVectorStore
   ├── filtered search
   ├── remove document
   ├── clear collection
   └── persistent updates
```

`EdgeRetriever` can index and retrieve within a collection, re-index a document by
replacing its previous chunks, remove one document, remove by metadata, or clear a
collection without affecting other local knowledge.

v0.3.0 includes collection lifecycle, scanned-PDF OCR, DOCX/HTML ingestion, standalone
image OCR, persistent source catalogs, and source-level incremental re-indexing.
Finer-grained diffing and broader visual semantics remain future work.

## v0.3.0

- [x] knowledge collection model
- [x] collection-scoped retrieval
- [x] vector metadata filters
- [x] document removal and collection clearing
- [x] document re-indexing lifecycle
- [x] scanned PDF / OCR ingestion
- [x] DOCX / HTML ingestion
- [x] image ingestion
- [x] persistent collection catalog and source management
- [x] automatic change detection / incremental re-indexing

## v0.4 progress

- [x] automatic RAG retrieval/context/generation orchestration
- [x] configurable top-K
- [x] optional minimum retrieval score
- [x] collection and metadata-filter aware orchestration
- [x] retrieved context/results returned to the caller
- [x] fine-grained page/document incremental re-indexing
- [ ] higher-level collection/source management APIs
- [ ] retrieval observability and metrics
- [ ] hybrid lexical + vector retrieval

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
