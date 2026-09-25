# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- v0.3 knowledge collections through `EdgeKnowledgeCollection`.
- Cross-platform vector filtering by document, collection, and metadata.
- Collection-scoped retrieval, document removal, collection clearing, and document re-indexing.
- Persistent vector-store removal support on iOS and Android.

## 0.2.0 - 2026-09-24

### Added

- Apple Foundation Models structured output and tool calling.
- Cross-platform tool abstraction.
- Cross-platform local RAG primitives, on-device embedding providers, persistent vector storage, document chunking, and native document import.
- Text-based PDF ingestion on iOS through PDFKit and on Android through PdfBox-Android.
- PDF source/page metadata preserved for local retrieval.

### Notes

- v0.2 PDF support extracts existing PDF text only; OCR and scanned/image-only PDF ingestion are out of scope.
- DOCX, HTML, image ingestion, richer collection management, and advanced re-indexing remain future work.

## 0.1.0

Initial public baseline for the mobile edge-AI framework.

### Added

- Shared iOS and Android provider abstractions.
- Provider routing and agent execution.
- Streaming generation and cancellation handling.
- Apple Foundation Models provider for iOS.
- Gemini Nano provider through ML Kit GenAI Prompt API for Android.
- Gemini Nano availability and model-download state handling.
- Runnable iOS and Android example apps.
- Cross-platform benchmark runners.
- Physical-device benchmark baselines for iPhone 17 Pro Max and Samsung Galaxy Z Fold7.
- GitHub Actions validation for Swift, Kotlin, and both example apps.
- Apache 2.0 license, contribution guide, and security policy.

### Notes

- Apple Foundation Models currently advertises text generation and streaming only.
- Structured output and tool calling remain roadmap capabilities and are not part of the v0.1.0 public provider surface.
- Gemini Nano availability depends on ML Kit / AICore support on the physical device.
- Benchmark memory metrics are lightweight platform-specific deltas and are not directly comparable across iOS and Android.
