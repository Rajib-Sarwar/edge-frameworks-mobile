# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Added

- v0.4 automatic RAG orchestration through `EdgeRAG` on Swift and Kotlin.
- `EdgeRAGRequest` configuration for collection/filter scoping, top-K, minimum score, and custom system prompts.
- `EdgeRAGResult` returning the generated answer, retrieved results, and constructed local context.
- Per-document source fingerprints and fine-grained incremental re-indexing for changed, added, and removed documents within a source.

## 0.3.0 - 2026-09-24

### Added

- v0.3 knowledge collections through `EdgeKnowledgeCollection`.
- Cross-platform vector filtering by document, collection, and metadata.
- Collection-scoped retrieval, document removal, collection clearing, and document re-indexing.
- Persistent vector-store removal support on iOS and Android.
- Scanned PDF OCR fallback on iOS with Apple Vision and on Android with bundled ML Kit Text Recognition.
- DOCX and HTML ingestion on iOS and Android with document-format metadata preserved for RAG.
- Persistent knowledge collection/source catalog on iOS and Android.
- SHA-256 source fingerprinting and source-level incremental re-indexing that skips unchanged content.
- Standalone image OCR ingestion on iOS with Apple Vision and on Android with bundled ML Kit Text Recognition.

### Notes

- Image ingestion in v0.3 is OCR-focused; semantic visual embeddings, image captioning, and general scene understanding are not included.
- Incremental re-indexing is source-level; any content change re-indexes that source as a unit rather than diffing individual pages or sections.
- DOCX ingestion focuses on the main `word/document.xml` body; headers, footers, comments, tracked-change semantics, and embedded media are not modeled separately.

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
