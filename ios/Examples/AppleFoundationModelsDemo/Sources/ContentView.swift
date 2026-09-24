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
                    .disabled(!model.isAvailable || model.isRunning)
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
            }
            .navigationTitle("Edge Frameworks")
        }
    }
}
