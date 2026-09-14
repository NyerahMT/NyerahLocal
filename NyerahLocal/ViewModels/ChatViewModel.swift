import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    static let defaultSystemPrompt = """
    You are NyerahLocal, a private local AI assistant running on the user's device. Be direct, capable, conversational, and useful. Follow the user's instructions carefully. Do not claim to have used the web, tools, files, camera, or other capabilities unless the app actually supplied their results. If current information is required and no tool result is available, say that clearly. Keep hidden reasoning private and give the user the useful conclusion.
    """

    var messages: [ChatMessage] = []
    var draft = ""
    var selectedModel: LocalModel
    var systemPrompt: String
    var thinkingEnabled: Bool
    var autoSpeak: Bool

    var isBusy = false
    var downloadProgress = 0.0
    var statusText = "Ready"
    var errorMessage: String?

    private let modelService = LocalModelService()
    private let speechService = SpeechService()
    private var generationTask: Task<Void, Never>?
    private var rawAssistantText = ""

    private enum Keys {
        static let model = "selectedModel"
        static let systemPrompt = "systemPrompt"
        static let thinking = "thinkingEnabled"
        static let autoSpeak = "autoSpeak"
    }

    init() {
        let defaults = UserDefaults.standard
        selectedModel = LocalModel(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .qwen8B
        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        thinkingEnabled = defaults.object(forKey: Keys.thinking) as? Bool ?? true
        autoSpeak = defaults.object(forKey: Keys.autoSpeak) as? Bool ?? false
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
    }

    var modelStatusLabel: String {
        if isBusy && downloadProgress > 0 && downloadProgress < 1 {
            return "Downloading \(Int(downloadProgress * 100))%"
        }
        return statusText
    }

    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isBusy else { return }

        draft = ""
        errorMessage = nil
        speechService.stop()
        messages.append(ChatMessage(role: .user, text: prompt))

        let assistantID = UUID()
        messages.append(ChatMessage(id: assistantID, role: .assistant, text: ""))
        rawAssistantText = ""
        isBusy = true
        downloadProgress = 0
        statusText = modelService.activeModel == selectedModel
            ? "Thinking locally…"
            : "Loading \(selectedModel.displayName)…"

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await modelService.generate(
                    prompt: prompt,
                    model: selectedModel,
                    instructions: systemPrompt,
                    thinkingEnabled: thinkingEnabled,
                    progress: { [weak self] value in
                        guard let self else { return }
                        self.downloadProgress = value
                        if value < 1 {
                            self.statusText = "Downloading \(self.selectedModel.displayName)…"
                        } else {
                            self.statusText = "Thinking locally…"
                        }
                    },
                    onChunk: { [weak self] chunk in
                        guard let self else { return }
                        self.rawAssistantText += chunk
                        let visible = Self.visibleAnswer(from: self.rawAssistantText)
                        if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                            self.messages[index].text = visible
                        }
                    }
                )

                let answer = Self.visibleAnswer(from: rawAssistantText)
                if let index = messages.firstIndex(where: { $0.id == assistantID }) {
                    messages[index].text = answer.isEmpty ? rawAssistantText.trimmingCharacters(in: .whitespacesAndNewlines) : answer
                }

                statusText = "\(selectedModel.displayName) ready"
                downloadProgress = 1

                if autoSpeak, let final = messages.first(where: { $0.id == assistantID })?.text {
                    speechService.speak(final)
                }
            } catch is CancellationError {
                if let index = messages.firstIndex(where: { $0.id == assistantID }),
                   messages[index].text.isEmpty {
                    messages[index].text = "Stopped."
                }
                statusText = "Stopped"
            } catch {
                errorMessage = error.localizedDescription
                if let index = messages.firstIndex(where: { $0.id == assistantID }),
                   messages[index].text.isEmpty {
                    messages[index].text = "I couldn't finish that response."
                }
                statusText = "Model error"
            }

            isBusy = false
            generationTask = nil
        }
    }

    func stop() {
        generationTask?.cancel()
        speechService.stop()
    }

    func speak(_ text: String) {
        speechService.speak(text)
    }

    func newConversation() {
        generationTask?.cancel()
        generationTask = nil
        isBusy = false
        messages.removeAll()
        rawAssistantText = ""
        errorMessage = nil
        speechService.stop()
        statusText = modelService.activeModel.map { "\($0.displayName) ready" } ?? "Ready"

        Task {
            await modelService.clearConversation()
        }
    }

    func preloadSelectedModel() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        downloadProgress = 0
        statusText = "Loading \(selectedModel.displayName)…"

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await modelService.prepare(
                    model: selectedModel,
                    instructions: systemPrompt,
                    thinkingEnabled: thinkingEnabled,
                    progress: { [weak self] value in
                        guard let self else { return }
                        self.downloadProgress = value
                        self.statusText = value < 1
                            ? "Downloading \(self.selectedModel.displayName)…"
                            : "Preparing local model…"
                    }
                )
                downloadProgress = 1
                statusText = "\(selectedModel.displayName) ready"
            } catch is CancellationError {
                statusText = "Stopped"
            } catch {
                errorMessage = error.localizedDescription
                statusText = "Model error"
            }
            isBusy = false
            generationTask = nil
        }
    }

    func applySettings(
        model: LocalModel,
        systemPrompt: String,
        thinkingEnabled: Bool,
        autoSpeak: Bool
    ) {
        let prompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrompt = prompt.isEmpty ? Self.defaultSystemPrompt : prompt
        let conversationConfigurationChanged =
            self.selectedModel != model ||
            self.systemPrompt != normalizedPrompt ||
            self.thinkingEnabled != thinkingEnabled

        let modelChanged = self.selectedModel != model
        self.selectedModel = model
        self.systemPrompt = normalizedPrompt
        self.thinkingEnabled = thinkingEnabled
        self.autoSpeak = autoSpeak

        let defaults = UserDefaults.standard
        defaults.set(model.rawValue, forKey: Keys.model)
        defaults.set(normalizedPrompt, forKey: Keys.systemPrompt)
        defaults.set(thinkingEnabled, forKey: Keys.thinking)
        defaults.set(autoSpeak, forKey: Keys.autoSpeak)

        if modelChanged {
            modelService.unload()
        }

        if conversationConfigurationChanged {
            newConversation()
        }
    }

    func resetSystemPrompt() {
        applySettings(
            model: selectedModel,
            systemPrompt: Self.defaultSystemPrompt,
            thinkingEnabled: thinkingEnabled,
            autoSpeak: autoSpeak
        )
    }

    private static func visibleAnswer(from raw: String) -> String {
        var output = raw

        while let start = output.range(of: "<think>") {
            if let end = output.range(of: "</think>", range: start.upperBound..<output.endIndex) {
                output.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                output.removeSubrange(start.lowerBound..<output.endIndex)
                break
            }
        }

        output = output.replacingOccurrences(of: "</think>", with: "")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
