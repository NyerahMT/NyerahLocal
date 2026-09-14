# Architecture

NyerahLocal is intentionally split into replaceable layers so the iPhone can run one memory-heavy engine at a time.

## v0.1 chat path

`ChatView` → `ChatViewModel` → `LocalModelService` → MLX `ChatSession` → Qwen3

- `ChatView` owns presentation only.
- `ChatViewModel` owns conversation/UI state, saved preferences, cancellation, and speech handoff.
- `LocalModelService` owns the live MLX `ModelContainer` and `ChatSession`.
- `LocalModel` is the small model catalog. The default is Qwen3 8B 4-bit; Qwen3 4B is the lower-memory fallback.
- `SpeechService` uses the system speech synthesizer and does not require a remote voice service.

Only one large model container is intentionally kept resident. Switching models releases the current container while Hugging Face's downloaded files remain cached on disk.

## System instructions

The system prompt is user-editable and stored locally in `UserDefaults`. Changing model, instructions, or reasoning mode starts a new model-side conversation so visible UI history cannot silently disagree with the transformer's internal chat history.

Qwen's native `enable_thinking` chat-template flag is passed through MLX as additional context. Reasoning tags are not rendered in the normal chat bubble; the app displays the final answer.

## Planned engines

Future capabilities should stay behind separate services instead of being fused into the chat code:

- vision / photo understanding
- persistent conversation storage and retrieval memory
- opt-in web and device tools
- local image generation
- image-to-image and masked editing
- local adapter/LoRA experiments

Image and language models should be memory-swapped rather than kept resident together on devices with limited unified memory.

## Build model

`project.yml` is the source of truth for the Xcode project. XcodeGen creates `NyerahLocal.xcodeproj`, while GitHub Actions performs an unsigned iOS Simulator build to catch compiler and package-integration regressions without requiring a developer certificate in CI.
