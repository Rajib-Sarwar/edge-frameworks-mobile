# Equipory Product Spec

Working name: Equipory
Tagline: Every machine remembers.

## Target customer

The first customer is an independent HVAC/R technician or small service company that
needs fast access to equipment-specific history, manuals, photos, service notes, and
troubleshooting evidence in the field.

## Core promise

Equipory gives each machine a private, persistent intelligence workspace. A technician
can ask about that exact asset and get an answer grounded in its local manuals, service
history, notes, photos, and labels.

## MVP

1. Equipment list and search.
2. Add equipment manually; nameplate camera/OCR follows immediately.
3. Equipment workspace.
4. Import and manage manuals, bulletins, notes, and text-bearing images.
5. Ask this equipment with collection-scoped local RAG.
6. Show citations/source/page with every grounded answer.
7. Service history and service-note capture.
8. Generate a service closeout from technician-entered facts and evidence.

## Not in v1

Dispatch, payroll, invoicing, CRM, parts marketplace, fleet management, and generalized
chat are intentionally out of scope.

## Premium boundary

Free should make the product useful enough to experience the core value. Pro should
unlock sustained professional use: more equipment, more local knowledge, full document
ingestion, equipment memory, cited Q&A, service history, and closeout generation.

Pricing remains a launch hypothesis and will be validated before App Store release.

## Product principles

- Equipment-first, not chatbot-first.
- Evidence is visible with AI answers.
- Local/private execution is preferred when device capabilities permit.
- Camera-first field workflows.
- Fast interactions with large touch targets.
- The app drives framework requirements; speculative framework work is secondary.
- Avoid unsupported absolute privacy/offline claims where model or asset availability
  has prerequisites.

## Framework mapping

EquipmentAsset -> EdgeKnowledgeCollection
Sources -> EdgeKnowledgeManager / EdgeIncrementalIndexer
Ask this equipment -> EdgeRAG
Answer diagnostics -> EdgeRAGMetrics
Manuals/images -> existing document/PDF/image ingestion modules
Nameplate scanning -> image OCR pipeline plus structured equipment extraction

## Quality metrics

For the MVP we care about:

- time to create an equipment asset
- successful nameplate field extraction rate
- source import success rate
- retrieval latency
- generation latency
- top retrieval score and retained-result count
- citation/source coverage
- user correction rate after OCR
- question-to-useful-answer rate
- repeat use per equipment asset
- service-closeout completion rate

The framework exposes local technical metrics. Product analytics should be a separate,
explicit layer and must not silently upload equipment knowledge.
