import EdgeFrameworks
import Foundation
import FoundationModels
import UIKit

@Generable
struct StructuredSummary {
    let title: String
    let bullets: [String]
}

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var prompt = "Explain on-device AI in three short bullets."
    @Published var output = ""
    @Published var structuredOutput = ""
    @Published var status = "Checking on-device model…"
    @Published var benchmarkOutput = ""
    @Published var isRunning = false
    @Published var isStructuredRunning = false
    @Published var isBenchmarking = false
    @Published var isAvailable = false

    @Published var ragQuestion = "When does my Tokyo flight leave?"
    @Published var ragStatus = "Preparing local knowledge…"
    @Published var ragRetrievedOutput = ""
    @Published var ragAnswer = ""
    @Published var isRAGRunning = false
    @Published var isRAGReady = false

    private var agent: EdgeAgent?
    private var provider: AppleFoundationModelProvider?
    private var ragRetriever: EdgeRetriever?
    private var incrementalIndexer: EdgeIncrementalIndexer?
    private let ragChunker = EdgeTextChunker(
        maxCharacters: 800,
        overlapCharacters: 120
    )

    init() {
        configure()
    }

    func configure() {
        guard #available(iOS 26.0, *) else {
            status = "Apple Foundation Models requires iOS 26 or newer."
            return
        }

        let provider = AppleFoundationModelProvider()
        self.provider = provider

        let router = EdgeProviderRouter(providers: [provider])
        agent = EdgeAgent(router: router)

        Task {
            let capabilities = await provider.capabilities()
            isAvailable = capabilities.contains(.textGeneration)

            status = isAvailable
                ? "Foundation Models is ready · running locally."
                : "Foundation Models is not available on this device."

            await configureLocalRAG()
        }
    }

    func run() {
        guard let agent else { return }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isRunning = true
        output = ""
        status = "Generating on device…"

        Task {
            defer { isRunning = false }

            do {
                let stream = try await agent.stream(
                    EdgeGenerationRequest(
                        prompt: trimmedPrompt,
                        systemPrompt: "Answer clearly and concisely."
                    )
                )

                for try await event in stream {
                    switch event {
                    case .started:
                        status = "Generating on device…"

                    case .token(let token):
                        output += token

                    case .completed:
                        status = "Completed locally."
                    }
                }
            } catch {
                status = "Generation failed."
                output = String(describing: error)
            }
        }
    }

    func runStructured() {
        guard
            #available(iOS 26.0, *),
            let provider
        else {
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isStructuredRunning = true
        structuredOutput = ""
        status = "Generating structured output…"

        Task {
            defer { isStructuredRunning = false }

            do {
                let result = try await provider.generateStructured(
                    EdgeGenerationRequest(
                        prompt: trimmedPrompt,
                        systemPrompt: "Return a concise title and exactly three short bullets."
                    ),
                    as: StructuredSummary.self
                )

                let bullets = result.bullets
                    .map { "• \($0)" }
                    .joined(separator: "\n")

                structuredOutput = """
                \(result.title)

                \(bullets)
                """
                status = "Structured output completed locally."
            } catch {
                status = "Structured generation failed."
                structuredOutput = String(describing: error)
            }
        }
    }

    func importDocument(url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let sourceName = url.lastPathComponent

            guard let incrementalIndexer else {
                ragStatus = "Local RAG is not ready."
                return
            }

            let fileExtension = url.pathExtension.lowercased()
            if fileExtension == "pdf" {
                ragStatus =
                    "Extracting PDF text · OCR fallback runs locally when needed…"
            } else if fileExtension == "docx" {
                ragStatus = "Extracting DOCX text locally…"
            } else if fileExtension == "html" || fileExtension == "htm" {
                ragStatus = "Parsing HTML locally…"
            } else if Self.imageExtensions.contains(fileExtension) {
                ragStatus = "Recognizing image text locally…"
            } else {
                ragStatus = "Reading local document…"
            }

            Task {
                do {
                    let documents: [EdgeDocument]
                    let fileExtension =
                        url.pathExtension.lowercased()

                    switch fileExtension {
                    case "pdf":
                        documents = try await Task.detached {
                            try await ApplePDFDocumentImporter()
                                .importDocumentWithOCR(
                                    data: data,
                                    sourceName: sourceName
                                )
                        }.value

                    case "docx":
                        let document = try await Task.detached {
                            try AppleRichDocumentImporter()
                                .importDOCX(
                                    data: data,
                                    sourceName: sourceName
                                )
                        }.value
                        documents = [document]

                    case "html", "htm":
                        let document = try await Task.detached {
                            try AppleRichDocumentImporter()
                                .importHTML(
                                    data: data,
                                    sourceName: sourceName
                                )
                        }.value
                        documents = [document]

                    case let imageExtension
                    where Self.imageExtensions.contains(
                        imageExtension
                    ):
                        let mediaType =
                            Self.imageMediaType(
                                for: imageExtension
                            )

                        let document = try await Task.detached {
                            try AppleImageDocumentImporter()
                                .importDocument(
                                    data: data,
                                    sourceName: sourceName,
                                    mediaType: mediaType
                                )
                        }.value
                        documents = [document]

                    default:
                        guard let text = String(
                            data: data,
                            encoding: .utf8
                        ) else {
                            ragStatus =
                                "Import failed · document is not supported UTF-8 text."
                            return
                        }

                        documents = [
                            EdgeDocument(
                                id: UUID().uuidString,
                                text: text,
                                metadata: [
                                    "source": sourceName,
                                    "mediaType": "text/plain"
                                ]
                            )
                        ]
                    }

                    let chunks = documents.flatMap {
                        ragChunker.chunk($0)
                    }

                    guard !chunks.isEmpty else {
                        ragStatus =
                            "Import skipped · document contains no extractable text."
                        return
                    }

                    let sourceIdentifier =
                        url.absoluteString
                    let sourceID =
                        EdgeContentFingerprint.sha256(
                            sourceIdentifier
                        )
                    let fingerprint =
                        EdgeContentFingerprint.sha256(data)

                    ragStatus =
                        "Checking source fingerprint and local index…"

                    let syncResult =
                        try await incrementalIndexer.sync(
                            sourceID: sourceID,
                            sourceIdentifier: sourceIdentifier,
                            contentFingerprint: fingerprint,
                            documents: documents,
                            collection: Self.importedCollection,
                            metadata: [
                                "source": sourceName,
                                "fileExtension": fileExtension
                            ],
                            chunker: ragChunker
                        )

                    let ocrPages = documents.filter {
                        $0.metadata["extractionMethod"] == "ocr"
                    }.count

                    let ocrNote = ocrPages > 0
                        ? " · OCR used on \(ocrPages) page(s)"
                        : ""

                    switch syncResult {
                    case .unchanged:
                        ragStatus =
                            "\(sourceName) is unchanged · skipped re-indexing."

                    case .indexed(_, let removedChunks, _):
                        let replaced = removedChunks > 0
                            ? " · replaced \(removedChunks) old chunk(s)"
                            : ""

                        ragStatus =
                            "Imported \(sourceName) · \(chunks.count) chunks persisted locally\(replaced)\(ocrNote)."
                    }
                } catch {
                    ragStatus = "Document import failed: \(error)"
                }
            }
        } catch {
            ragStatus = "Document import failed: \(error)"
        }
    }

    func runRAG() {
        guard
            #available(iOS 26.0, *),
            let provider,
            let ragRetriever
        else {
            return
        }

        let question = ragQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        isRAGRunning = true
        ragRetrievedOutput = ""
        ragAnswer = ""
        ragStatus = "Retrieving relevant chunks locally…"

        Task {
            defer { isRAGRunning = false }

            do {
                let results = try await ragRetriever.retrieve(
                    query: question,
                    topK: 3
                )

                ragRetrievedOutput = results
                    .enumerated()
                    .map { index, result in
                        let score = result.score.formatted(
                            .number.precision(.fractionLength(3))
                        )
                        let source =
                            result.chunk.metadata["source"] ?? "local"
                        let page = result.chunk.metadata["pageNumber"]
                            .map { " · page \($0)" } ?? ""

                        return """
                        \(index + 1). [\(score)] \(source)\(page)
                        \(result.chunk.text)
                        """
                    }
                    .joined(separator: "\n\n")

                let context = results
                    .map(\.chunk.text)
                    .joined(separator: "\n")

                ragStatus = "Generating answer from retrieved local context…"

                let response = try await provider.generate(
                    EdgeGenerationRequest(
                        prompt: """
                        Local context:
                        \(context)

                        Question:
                        \(question)
                        """,
                        systemPrompt: """
                        Answer using only the supplied local context. If the context does not contain
                        the answer, say that the local knowledge does not contain enough information.
                        """
                    )
                )

                ragAnswer = response.text
                ragStatus = "RAG completed locally · no network required."
            } catch {
                ragStatus = "Local RAG failed."
                ragAnswer = String(describing: error)
            }
        }
    }

    func runBenchmark() {
        guard
            #available(iOS 26.0, *),
            let provider
        else {
            return
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isBenchmarking = true
        benchmarkOutput = ""
        status = "Warming up model…"

        Task {
            defer { isBenchmarking = false }

            do {
                let request = EdgeGenerationRequest(
                    prompt: trimmedPrompt,
                    systemPrompt: "Answer clearly and concisely."
                )

                _ = try await provider.generate(request)

                status = "Running 10 benchmark iterations…"

                let summary = try await EdgeBenchmarkRunner().run(
                    provider: provider,
                    request: request,
                    iterations: 10
                )

                benchmarkOutput = formatBenchmark(summary)
                status = "Benchmark completed."
            } catch {
                status = "Benchmark failed."
                benchmarkOutput = String(describing: error)
            }
        }
    }

    private func configureLocalRAG() async {
        do {
            let embeddingProvider = try AppleNaturalLanguageEmbeddingProvider()

            let applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let vectorStore = try EdgeFileVectorStore(
                fileURL: applicationSupport
                    .appendingPathComponent("EdgeFrameworks", isDirectory: true)
                    .appendingPathComponent("rag-vectors.json")
            )

            let retriever = EdgeRetriever(
                embeddingProvider: embeddingProvider,
                vectorStore: vectorStore
            )

            let catalog = try EdgeFileKnowledgeCatalog(
                fileURL: applicationSupport
                    .appendingPathComponent(
                        "EdgeFrameworks",
                        isDirectory: true
                    )
                    .appendingPathComponent(
                        "knowledge-catalog.json"
                    )
            )

            let incrementalIndexer =
                EdgeIncrementalIndexer(
                    retriever: retriever,
                    catalog: catalog
                )

            try await retriever.index(Self.demoChunks)
            ragRetriever = retriever
            self.incrementalIndexer = incrementalIndexer
            isRAGReady = true
            ragStatus =
                "Local RAG ready · vectors and source catalog persist on device."
        } catch {
            isRAGReady = false
            ragStatus = "Local embeddings unavailable: \(error)"
        }
    }

    private static let imageExtensions: Set<String> = [
        "jpg",
        "jpeg",
        "png",
        "heic",
        "heif",
        "tif",
        "tiff"
    ]

    private static func imageMediaType(
        for fileExtension: String
    ) -> String {
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        case "tif", "tiff":
            return "image/tiff"
        default:
            return "image/*"
        }
    }

    private static let importedCollection =
        EdgeKnowledgeCollection(
            id: "imported-documents",
            name: "Imported Documents"
        )

    private static let demoChunks: [EdgeChunk] = [
        EdgeChunk(
            id: "travel-flight",
            documentID: "travel-notes",
            text: "Our flight to Tokyo leaves Newark on October 12 at 9:30 AM."
        ),
        EdgeChunk(
            id: "travel-hotel",
            documentID: "travel-notes",
            text: "We are staying at the Shinagawa Prince Hotel in Tokyo for four nights."
        ),
        EdgeChunk(
            id: "travel-train",
            documentID: "travel-notes",
            text: "The airport train reservation is for the Narita Express after landing."
        ),
        EdgeChunk(
            id: "insurance",
            documentID: "personal-notes",
            text: "The new insurance coverage begins on November 1."
        ),
        EdgeChunk(
            id: "dinner",
            documentID: "personal-notes",
            text: "Friday dinner is reserved at an Italian restaurant at 7:00 PM."
        )
    ]

    private func formatBenchmark(
        _ summary: EdgeBenchmarkSummary
    ) -> String {
        """
        Device: \(UIDevice.current.model)
        OS: iOS \(UIDevice.current.systemVersion)
        Provider: \(summary.providerID)
        Iterations: \(summary.iterations)
        Warm-up: 1 unmeasured request

        Average latency: \(summary.averageLatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        P50 latency: \(summary.p50LatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        P95 latency: \(summary.p95LatencyMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms
        Average memory delta: \((summary.averageMemoryDeltaBytes / 1_048_576).formatted(.number.precision(.fractionLength(2)))) MB
        """
    }
}
