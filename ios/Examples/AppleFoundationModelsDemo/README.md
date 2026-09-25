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
- TXT, Markdown, JSON, and text-based PDF import
- PDF page-aware retrieval metadata through PDFKit


PDF ingestion in v0.2 extracts existing text only. Scanned/image-only PDFs require OCR and are intentionally out of scope.
