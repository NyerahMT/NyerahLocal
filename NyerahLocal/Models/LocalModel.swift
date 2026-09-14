import MLXLLM
import MLXLMCommon

enum LocalModel: String, CaseIterable, Identifiable {
    case qwen8B
    case qwen4B

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen8B:
            "Qwen3 8B · 4-bit"
        case .qwen4B:
            "Qwen3 4B · 4-bit"
        }
    }

    var detail: String {
        switch self {
        case .qwen8B:
            "Max quality target for iPhone 15 Pro Max. Large download and aggressive memory use."
        case .qwen4B:
            "Lower-memory fallback. Faster to load and leaves more room for long chats."
        }
    }

    var configuration: ModelConfiguration {
        switch self {
        case .qwen8B:
            LLMRegistry.qwen3_8b_4bit
        case .qwen4B:
            LLMRegistry.qwen3_4b_4bit
        }
    }
}
