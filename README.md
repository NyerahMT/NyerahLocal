# NyerahLocal

A local-first multimodal AI assistant for iPhone, built with SwiftUI and MLX.

The first milestone is deliberately small and real: download a capable open-weight model directly to the phone, run inference locally, stream a multi-turn conversation, and optionally read the answer aloud. The architecture is model-swappable so image generation/editing, vision, tools, memory, web search, and on-device adapters can be added without replacing the chat core.

## Current target

- iPhone 15 Pro Max or newer
- iOS 17+
- SwiftUI
- MLX Swift LM 3.31.4
- Default model: `mlx-community/Qwen3-8B-4bit`
- Fallback model: `mlx-community/Qwen3-4B-4bit`
- Local streamed chat with editable system instructions
- Optional on-device text-to-speech for replies
- No model API keys or cloud inference

Models are downloaded from Hugging Face the first time they are selected, then cached on-device by the MLX/Hugging Face stack.

## Generate the Xcode project

This repo uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the project definition stays reviewable in `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open NyerahLocal.xcodeproj
```

For a physical iPhone, choose your signing team in Xcode. The target requests the increased-memory-limit entitlement because an 8B 4-bit model is intentionally aggressive for an 8 GB phone.

## Why Qwen3 8B first?

Apple's MLX Swift examples expose Qwen3 8B 4-bit as a supported configuration, and it is large enough to be a meaningful personal assistant while still being plausible on high-memory iPhones. NyerahLocal also includes a 4B fallback so we have a known lower-memory path if the 8B configuration proves unstable on-device.

## Near-term roadmap

1. Prove Qwen3 8B streaming chat on the iPhone 15 Pro Max.
2. Add a vision model and photo attachments.
3. Add local persistent conversations and retrieval memory.
4. Add web/search and other opt-in tools.
5. Add local image generation and image editing as a separate memory-swapped engine.
6. Experiment with on-device LoRA adapters after inference is stable.

This is a personal experimental app. The priority is local control, capability, and a clean architecture rather than broad-device compatibility.
