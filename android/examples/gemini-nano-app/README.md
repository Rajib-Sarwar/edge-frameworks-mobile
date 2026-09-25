# Gemini Nano example

A minimal Android app that exercises generation and local RAG through the framework's public APIs.

## Generation

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

## Local RAG

```text
Local chunks
    ↓
MediaPipeTextEmbeddingProvider
    ↓
Universal Sentence Encoder
    ↓
EdgeFileVectorStore
    ↓
top-K cosine retrieval
    ↓
retrieved context
    ↓
GeminiNanoProvider
    ↓
final answer
```

The Gradle build fetches Google's published Universal Sentence Encoder model into generated app assets. At runtime, embeddings and vector search stay on-device. Gemini Nano generation also runs on-device once the ML Kit model is available.

## Run

Open the `android` directory in Android Studio and run the `gemini-nano-app` configuration on a supported physical device with Gemini Nano available.

The first Gradle build needs network access to fetch the embedding model asset. The app then demonstrates:

- runtime capability detection
- provider routing
- streaming generation
- framework-level error handling
- MediaPipe on-device text embeddings
- top-K semantic retrieval with similarity scores
- retrieved-context generation with Gemini Nano
- persistent local vector storage
- TXT, Markdown, JSON, PDF, DOCX, and HTML import
- PDF page-aware retrieval metadata through PdfBox-Android


## Scanned PDFs

PDF pages without embedded text are rendered locally with PdfBox-Android and passed to
the bundled ML Kit Text Recognition model before chunking and indexing. Retrieved chunks
retain the PDF source and page metadata, plus whether text came from embedded PDF text
or OCR.


## DOCX and HTML

The `edge-frameworks-documents` module extracts DOCX text from WordprocessingML and
uses jsoup for HTML-to-text parsing before local chunking, embedding, and persistence.
