import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let agent: AgentLoop
    private let speechRecognizer: SpeechRecognizerService

    init(agent: AgentLoop, speechRecognizer: SpeechRecognizerService) {
        self.agent = agent
        self.speechRecognizer = speechRecognizer
    }

    // MARK: - Voice Input

    var isRecording: Bool { speechRecognizer.isRecording }
    var recognizedText: String { speechRecognizer.recognizedText }
    var voiceError: String? { speechRecognizer.errorMessage }

    func startVoiceInput() async {
        await speechRecognizer.startRecording()
    }

    func stopVoiceInput() async {
        await speechRecognizer.stopRecording()
    }

    func cancelVoiceInput() {
        speechRecognizer.cancelRecording()
    }

    // MARK: - Public Methods

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        messages.append(.user(text))
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for try await event in agent.send(text) {
                if case .assistantText(let reply) = event {
                    messages.append(.assistant(reply))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
