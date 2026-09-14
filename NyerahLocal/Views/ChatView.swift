import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showingSettings = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    statusBar
                    Divider()
                    conversation
                    composer
                }
            }
            .navigationTitle("NyerahLocal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.newConversation()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New conversation")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .alert(
                "Local model error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private var statusBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(viewModel.modelStatusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(viewModel.selectedModel.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if viewModel.downloadProgress > 0 && viewModel.downloadProgress < 1 {
                ProgressView(value: viewModel.downloadProgress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }

    private var statusColor: Color {
        if viewModel.errorMessage != nil { return .red }
        if viewModel.isBusy { return .orange }
        if viewModel.downloadProgress >= 1 { return .green }
        return .secondary
    }

    @ViewBuilder
    private var conversation: some View {
        if viewModel.messages.isEmpty {
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 76)

                    ZStack {
                        Circle()
                            .fill(.primary.opacity(0.06))
                            .frame(width: 88, height: 88)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 8) {
                        Text("Your AI, on your iPhone")
                            .font(.title2.bold())
                        Text("Qwen runs locally with MLX. Your first message downloads the selected model; after that, ordinary chat inference does not need a model API or cloud AI.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                    }

                    Button {
                        viewModel.preloadSelectedModel()
                    } label: {
                        Label(
                            viewModel.isBusy ? "Preparing model…" : "Load model now",
                            systemImage: "arrow.down.circle"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy)

                    Text("The 8B model is intentionally aggressive for an iPhone 15 Pro Max. If iOS terminates it for memory pressure, switch to the 4B fallback in Settings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 330)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages) { _, messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 42)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if message.role == .assistant && message.text.isEmpty && viewModel.isBusy {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(viewModel.thinkingEnabled ? "Thinking…" : "Generating…")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text(message.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                        .background(
                            message.role == .user ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                }

                if message.role == .assistant && !message.text.isEmpty {
                    Button {
                        viewModel.speak(message.text)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Read response aloud")
                    .padding(.leading, 6)
                }
            }

            if message.role == .assistant {
                Spacer(minLength: 42)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message NyerahLocal", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if viewModel.isBusy {
                    Button {
                        viewModel.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.red)
                    .accessibilityLabel("Stop generation")
                } else {
                    Button {
                        viewModel.send()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .disabled(!viewModel.canSend)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}
