import SwiftUI
import Observation

struct ChatView: View {
    var viewModel: ChatViewModel
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Talk with Claude")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .borderBottom()

            // Messages
            if viewModel.messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No messages yet")
                        .font(.headline)
                    Text("Start chatting to begin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Claude is thinking...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding()
            }

            // Input area
            VStack(spacing: 8) {
                // Voice error banner
                if let voiceError = viewModel.voiceError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(voiceError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    // Mic button
                    Button(action: toggleRecording) {
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                            .font(.title2)
                            .foregroundStyle(viewModel.isRecording ? .red : .secondary)
                            .symbolEffect(.pulse, isActive: viewModel.isRecording)
                    }
                    .disabled(viewModel.isLoading)

                    TextField(
                        viewModel.isRecording ? "Listening…" : "Type a message…",
                        text: $inputText
                    )
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isLoading || viewModel.isRecording)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading || viewModel.isRecording)
                }
                .padding()
                .background(Color(.systemGray6))
            }
        }
        // Sync live transcription into the text field while recording
        .onChange(of: viewModel.recognizedText) { _, text in
            if viewModel.isRecording {
                inputText = text
            }
        }
        // When recording stops, keep the transcribed text in the field
        // so the user can review and tap Send
        .onChange(of: viewModel.isRecording) { _, isRecording in
            if !isRecording && !viewModel.recognizedText.isEmpty {
                inputText = viewModel.recognizedText
            }
        }
    }

    private func toggleRecording() {
        if viewModel.isRecording {
            Task { await viewModel.stopVoiceInput() }
        } else {
            inputText = ""
            Task { await viewModel.startVoiceInput() }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        inputText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isSentByUser {
                Spacer()
            }

            VStack(alignment: message.isSentByUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                message.isSentByUser
                    ? Color.blue
                    : Color(.systemGray5)
            )
            .foregroundStyle(
                message.isSentByUser
                    ? Color.white
                    : Color.primary
            )
            .cornerRadius(12)
            .frame(maxWidth: .infinity * 0.8, alignment: message.isSentByUser ? .trailing : .leading)

            if !message.isSentByUser {
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
}

extension View {
    func borderBottom() -> some View {
        self
            .overlay(
                VStack(spacing: 0) {
                    Spacer()
                    Divider()
                }
            )
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel(
        claudeRepository: ClaudeRepository(),
        fileRepository: FileRepository(),
        speechRecognizer: SpeechRecognizerService()
    ))
}
