import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = DemoViewModel()
    @State private var isImportingDocument = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Text(model.status)
                        .foregroundStyle(.secondary)
                }

                Section("Prompt") {
                    TextEditor(text: $model.prompt)
                        .frame(minHeight: 120)
                }

                Section {
                    Button {
                        model.run()
                    } label: {
                        if model.isRunning {
                            ProgressView()
                        } else {
                            Text("Run on device")
                        }
                    }
                    .disabled(isBusy)

                    Button {
                        model.runStructured()
                    } label: {
                        if model.isStructuredRunning {
                            HStack {
                                ProgressView()
                                Text("Generating structure…")
                            }
                        } else {
                            Text("Run structured output")
                        }
                    }
                    .disabled(isBusy)

                    Button {
                        model.runBenchmark()
                    } label: {
                        if model.isBenchmarking {
                            HStack {
                                ProgressView()
                                Text("Benchmarking…")
                            }
                        } else {
                            Text("Run benchmark")
                        }
                    }
                    .disabled(isBusy)
                }

                Section("Response") {
                    if model.output.isEmpty {
                        Text("Response will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(model.output)
                            .textSelection(.enabled)
                    }
                }

                if !model.structuredOutput.isEmpty {
                    Section("Structured Output") {
                        Text(model.structuredOutput)
                            .textSelection(.enabled)
                    }
                }

                if !model.benchmarkOutput.isEmpty {
                    Section("Benchmark") {
                        Text(model.benchmarkOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("Local RAG") {
                    Text(model.ragStatus)
                        .foregroundStyle(.secondary)

                    Button("Import document") {
                        isImportingDocument = true
                    }
                    .disabled(model.isRAGRunning)

                    TextField(
                        "Ask local knowledge",
                        text: $model.ragQuestion,
                        axis: .vertical
                    )

                    Button {
                        model.runRAG()
                    } label: {
                        if model.isRAGRunning {
                            HStack {
                                ProgressView()
                                Text("Running local RAG…")
                            }
                        } else {
                            Text("Ask local knowledge")
                        }
                    }
                    .disabled(
                        isBusy ||
                        !model.isRAGReady ||
                        model.isRAGRunning
                    )
                }

                if !model.ragRetrievedOutput.isEmpty {
                    Section("Retrieved Chunks") {
                        Text(model.ragRetrievedOutput)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                if !model.ragAnswer.isEmpty {
                    Section("RAG Answer") {
                        Text(model.ragAnswer)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Edge Frameworks")
            .fileImporter(
                isPresented: $isImportingDocument,
                allowedContentTypes: [
                    .plainText,
                    .json,
                    .pdf,
                    .html,
                    UTType(filenameExtension: "md") ?? .plainText,
                    UTType(filenameExtension: "docx")
                        ?? .data
                ],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        model.importDocument(url: url)
                    }

                case .failure(let error):
                    model.ragStatus =
                        "Document picker failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private var isBusy: Bool {
        !model.isAvailable ||
        model.isRunning ||
        model.isStructuredRunning ||
        model.isBenchmarking
    }
}
