# Apple Foundation Models example

A minimal SwiftUI app that exercises the framework's public API:

```text
SwiftUI
  ↓
DemoViewModel
  ↓
EdgeAgent
  ↓
EdgeProviderRouter
  ↓
AppleFoundationModelProvider
  ↓
Apple Foundation Models
```

## Requirements

- Xcode 26 or newer
- iOS 26 or newer
- a device where Apple Foundation Models is available
- XcodeGen

## Generate and run

From this directory:

```bash
xcodegen generate
open AppleFoundationModelsDemo.xcodeproj
```

Then select a supported physical device and run the app.

The sample demonstrates:

- runtime capability detection
- provider routing
- streaming generation
- cancellation-aware framework APIs
- framework-level error handling
- local prompting through Apple Foundation Models
- persistent local RAG with Apple Natural Language embeddings
- TXT, Markdown, JSON, PDF, DOCX, HTML, and image OCR import
- PDF page-aware retrieval metadata through PDFKit


## Scanned PDFs

PDF pages without embedded text use an on-device Apple Vision OCR fallback before
chunking and indexing. Retrieved chunks retain the PDF source and page metadata, plus
whether text came from embedded PDF text or OCR.


## DOCX and HTML

DOCX files are unpacked locally and the main WordprocessingML document text is imported
through `AppleRichDocumentImporter`. HTML files are converted to readable text with
the platform HTML importer before chunking and indexing.


## Persistent sources

Imported documents are tracked in a local `EdgeFileKnowledgeCatalog`. The demo hashes
the selected file before indexing; importing the same unchanged source skips embeddings,
while changed content replaces the source's previously indexed chunks.


## Image ingestion

The demo accepts common image files and uses Apple Vision OCR to turn visible image text
into an `EdgeDocument` before chunking, embedding, and persistence. This is text-focused
image ingestion, not general image captioning or visual embeddings.


## Automatic RAG orchestration

The demo now uses `EdgeRAG` for the question-answering path. Retrieval, context
construction, and Apple Foundation Models generation are orchestrated by the framework;
the app only renders `EdgeRAGResult.answer` and its retrieved results.
