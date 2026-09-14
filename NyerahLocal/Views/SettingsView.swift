import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ChatViewModel

    @State private var selectedModel: LocalModel
    @State private var systemPrompt: String
    @State private var thinkingEnabled: Bool
    @State private var autoSpeak: Bool

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        _selectedModel = State(initialValue: viewModel.selectedModel)
        _systemPrompt = State(initialValue: viewModel.systemPrompt)
        _thinkingEnabled = State(initialValue: viewModel.thinkingEnabled)
        _autoSpeak = State(initialValue: viewModel.autoSpeak)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model") {
                    Picker("Local model", selection: $selectedModel) {
                        ForEach(LocalModel.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }

                    Text(selectedModel.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Generation") {
                    Toggle("Thinking mode", isOn: $thinkingEnabled)
                    Text("Lets Qwen use its native reasoning mode before giving you the final answer. It can be noticeably slower, but is the default for harder questions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Read replies aloud", isOn: $autoSpeak)
                    Text("Uses iOS text-to-speech locally after a response finishes. You can also tap the speaker under any answer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("System instructions") {
                    TextEditor(text: $systemPrompt)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                        .textInputAutocapitalization(.sentences)

                    Button("Restore default instructions") {
                        systemPrompt = ChatViewModel.defaultSystemPrompt
                    }
                } footer: {
                    Text("These instructions are sent to the local model as its system prompt. Changing the model, instructions, or thinking mode starts a fresh conversation so the model's internal history stays consistent with what you see.")
                }

                Section("Privacy") {
                    Label("Chat inference runs on-device", systemImage: "iphone.gen3")
                    Label("No model API key required", systemImage: "key.slash")
                    Text("Downloading a model and future opt-in web tools require network access. Ordinary generation uses the model stored on the phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.applySettings(
                            model: selectedModel,
                            systemPrompt: systemPrompt,
                            thinkingEnabled: thinkingEnabled,
                            autoSpeak: autoSpeak
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
