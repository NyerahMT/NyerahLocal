import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

@MainActor
final class LocalModelService {
    private struct SessionConfiguration: Equatable {
        let model: LocalModel
        let instructions: String
        let thinkingEnabled: Bool
    }

    private var loadedModel: LocalModel?
    private var container: ModelContainer?
    private var session: ChatSession?
    private var sessionConfiguration: SessionConfiguration?
    private var loadingTask: Task<ModelContainer, Error>?
    private var loadingModel: LocalModel?

    var activeModel: LocalModel? { loadedModel }

    func prepare(
        model: LocalModel,
        instructions: String,
        thinkingEnabled: Bool,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws {
        let modelContainer = try await modelContainer(for: model, progress: progress)
        let desired = SessionConfiguration(
            model: model,
            instructions: instructions,
            thinkingEnabled: thinkingEnabled
        )

        if session == nil || sessionConfiguration != desired {
            let parameters = GenerateParameters(
                maxTokens: 2_048,
                temperature: 0.65,
                topP: 0.92
            )

            session = ChatSession(
                modelContainer,
                instructions: instructions,
                generateParameters: parameters,
                additionalContext: ["enable_thinking": thinkingEnabled]
            )
            sessionConfiguration = desired
        }
    }

    func generate(
        prompt: String,
        model: LocalModel,
        instructions: String,
        thinkingEnabled: Bool,
        progress: @escaping @MainActor @Sendable (Double) -> Void,
        onChunk: @escaping @MainActor @Sendable (String) -> Void
    ) async throws {
        try await prepare(
            model: model,
            instructions: instructions,
            thinkingEnabled: thinkingEnabled,
            progress: progress
        )

        guard let session else {
            throw LocalModelError.sessionUnavailable
        }

        for try await chunk in session.streamResponse(to: prompt) {
            try Task.checkCancellation()
            onChunk(chunk)
        }
    }

    func clearConversation() async {
        await session?.clear()
    }

    func unload() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingModel = nil
        session = nil
        sessionConfiguration = nil
        container = nil
        loadedModel = nil
    }

    private func modelContainer(
        for model: LocalModel,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> ModelContainer {
        if loadedModel == model, let container {
            progress(1)
            return container
        }

        if loadingModel == model, let loadingTask {
            return try await loadingTask.value
        }

        // Only keep one large model resident at a time. Model files remain cached on disk.
        unload()
        loadingModel = model
        progress(0)

        let configuration = model.configuration
        let task = Task<ModelContainer, Error> {
            try await #huggingFaceLoadModelContainer(configuration: configuration) { value in
                Task { @MainActor in
                    progress(value.fractionCompleted)
                }
            }
        }

        loadingTask = task

        do {
            let loaded = try await task.value
            container = loaded
            loadedModel = model
            loadingTask = nil
            loadingModel = nil
            progress(1)
            return loaded
        } catch {
            loadingTask = nil
            loadingModel = nil
            throw error
        }
    }
}

enum LocalModelError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            "The local model loaded, but the chat session could not be created."
        }
    }
}
