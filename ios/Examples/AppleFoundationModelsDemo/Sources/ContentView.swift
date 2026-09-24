import SwiftUI

struct ContentView: View {
    @StateObject private var model = DemoViewModel()

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
            }
            .navigationTitle("Edge Frameworks")
        }
    }

    private var isBusy: Bool {
        !model.isAvailable ||
        model.isRunning ||
        model.isStructuredRunning ||
        model.isBenchmarking
    }
}
