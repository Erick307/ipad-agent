import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var conversationId: String = UUID().uuidString

    private let claudeRepository: ClaudeRepository
    private let fileRepository: FileRepository
    private let speechRecognizer: SpeechRecognizerService

    private var systemPrompt: String = ""

    init(
        claudeRepository: ClaudeRepository,
        fileRepository: FileRepository,
        speechRecognizer: SpeechRecognizerService
    ) {
        self.claudeRepository = claudeRepository
        self.fileRepository = fileRepository
        self.speechRecognizer = speechRecognizer
        loadSystemPrompt()
    }

    // MARK: - Public Methods

    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Add user message
        let userMessage = Message(
            id: UUID(),
            role: "user",
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)

        // Start the agentic loop
        await agenticLoop()
    }

    // MARK: - Agentic Loop

    /// Main agentic loop: sends messages and handles responses
    private func agenticLoop() async {
        isLoading = true
        errorMessage = nil

        do {
            // Send all messages to Claude
            let response = try await claudeRepository.sendMessage(
                messages: messages,
                systemPrompt: systemPrompt
            )

            // Add assistant response
            let assistantMessage = Message(
                id: UUID(),
                role: "assistant",
                content: response.textContent,
                timestamp: Date()
            )
            messages.append(assistantMessage)

            // Handle tool calls if any (future implementation)
            if let toolCalls = response.toolCalls {
                for toolCall in toolCalls {
                    try await executeToolCall(toolCall)
                    // After tool execution, loop again to send result to Claude
                    await agenticLoop()
                }
            }

            // Clear error if successful
            errorMessage = nil

        } catch {
            // Handle API errors gracefully
            let errorMsg = error.localizedDescription
            errorMessage = "Failed to get response: \(errorMsg)"
            print("❌ Agentic loop error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Tool Execution

    func executeToolCall(_ toolCall: ToolCall) async throws {
        switch toolCall.name {
        case "create_file":
            try await executeCreateFile(toolCall)
        default:
            print("⚠️ Unknown tool: \(toolCall.name)")
        }
    }

    func executeCreateFile(_ toolCall: ToolCall) async throws {
        let filename = toolCall.input.filename
        let content = toolCall.input.content

        // Create file using repository
        let file = try await fileRepository.createFile(
            filename: filename,
            content: content
        )

        // Add tool result message (future implementation when we add tool_result role)
        print("✅ File created: \(file.name)")
    }

    // MARK: - Private Methods

    private func loadSystemPrompt() {
        // TODO: Load from Resources/SystemPrompts/*.md
        self.systemPrompt = """
        You are a helpful AI assistant for iPad designed to help users create and manage documents.

        You are running on an iPad app that supports creating markdown files.
        Be concise and helpful in your responses.
        """
    }
}
