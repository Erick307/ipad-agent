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

    /// Maximum number of API round-trips per user message, to stop runaway tool loops.
    private static let maxAgentSteps = 10

    /// Separate message array formatted for the Anthropic API.
    /// Correctly preserves tool_use and tool_result blocks that the
    /// plain display `messages` array cannot represent.
    private var apiMessages: [APIMessage] = []

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

        let userMessage = Message(
            id: UUID(),
            role: "user",
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)
        apiMessages.append(APIMessage(role: "user", text: text))

        await agenticLoop()
    }

    // MARK: - Agentic Loop

    private func agenticLoop() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        for step in 1...Self.maxAgentSteps {
            do {
                let response = try await claudeRepository.sendMessage(
                    apiMessages: apiMessages,
                    systemPrompt: systemPrompt
                )

                appendAssistantMessage(response.textContent)

                switch response.stopReason {
                case "tool_use" where response.toolCalls?.isEmpty == false:
                    let toolCalls = response.toolCalls ?? []
                    print("🛠️  Step \(step): Claude called \(toolCalls.count) tool(s)")
                    apiMessages.append(assistantTurn(text: response.textContent, toolCalls: toolCalls))
                    apiMessages.append(await toolResultsTurn(for: toolCalls))
                    // Next iteration sends the results back so Claude can see them

                case "end_turn", "stop_sequence":
                    if !response.textContent.isEmpty {
                        apiMessages.append(APIMessage(role: "assistant", text: response.textContent))
                    }
                    return

                case "max_tokens":
                    // The response was cut off. A truncated tool_use input can still
                    // parse as valid JSON (e.g. half a file), so never run its tools.
                    errorMessage = "The response was cut off (max_tokens). Try a shorter request."
                    return

                case "refusal":
                    errorMessage = "Claude declined to complete this request."
                    return

                default:
                    print("⚠️ Unexpected stop reason: \(response.stopReason)")
                    errorMessage = "Unexpected stop reason: \(response.stopReason)"
                    return
                }

            } catch {
                errorMessage = "Failed to get response: \(error.localizedDescription)"
                print("❌ Agentic loop error: \(error)")
                return
            }
        }

        print("⛔ Agentic loop stopped: reached \(Self.maxAgentSteps) steps")
        errorMessage = "Stopped after \(Self.maxAgentSteps) steps. Send another message to continue."
    }

    private func appendAssistantMessage(_ text: String) {
        guard !text.isEmpty else { return }
        messages.append(Message(
            id: UUID(),
            role: "assistant",
            content: text,
            timestamp: Date()
        ))
    }

    /// Full assistant turn (text + tool_use blocks). The API requires it in the
    /// history before the user turn that carries the matching tool_result blocks.
    private func assistantTurn(text: String, toolCalls: [ToolCall]) -> APIMessage {
        var blocks: [AnyEncodable] = []
        if !text.isEmpty {
            blocks.append(AnyEncodable(APITextBlock(text: text)))
        }
        for toolCall in toolCalls {
            blocks.append(AnyEncodable(APIToolUseBlock(
                id: toolCall.id,
                name: toolCall.name,
                input: toolCall.input
            )))
        }
        return APIMessage(role: "assistant", blocks: blocks)
    }

    /// Executes every tool call and returns all results in a single user turn.
    private func toolResultsTurn(for toolCalls: [ToolCall]) async -> APIMessage {
        var blocks: [AnyEncodable] = []
        for toolCall in toolCalls {
            let result = await executeToolCall(toolCall)
            blocks.append(AnyEncodable(APIToolResultBlock(
                tool_use_id: toolCall.id,
                content: result
            )))
        }
        return APIMessage(role: "user", blocks: blocks)
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ toolCall: ToolCall) async -> String {
        switch toolCall.name {
        case "write_file":  return await executeWriteFile(toolCall)
        case "read_file":   return await executeReadFile(toolCall)
        case "list_files":  return await executeListFiles()
        case "delete_file": return await executeDeleteFile(toolCall)
        default:
            print("⚠️ Unknown tool: \(toolCall.name)")
            return "Error: Unknown tool '\(toolCall.name)'"
        }
    }

    private func executeWriteFile(_ toolCall: ToolCall) async -> String {
        let filename = toolCall.input["filename"]?.stringValue ?? ""
        let content  = toolCall.input["content"]?.stringValue  ?? ""

        guard !filename.isEmpty else { return "Error: filename is required" }

        print("🔧 write_file: \(filename) (\(content.count) bytes)")

        do {
            let file = try await fileRepository.writeFile(filename: filename, content: content)
            print("✅ File written: \(file.name)")
            return "File '\(filename)' saved successfully. Size: \(file.sizeInKB)"
        } catch {
            print("❌ write_file error: \(error)")
            return "Error writing '\(filename)': \(error.localizedDescription)"
        }
    }

    private func executeReadFile(_ toolCall: ToolCall) async -> String {
        let filename = toolCall.input["filename"]?.stringValue ?? ""

        guard !filename.isEmpty else { return "Error: filename is required" }

        print("🔧 read_file: \(filename)")

        do {
            let content = try await fileRepository.readFileByName(filename)
            print("✅ File read: \(filename)")
            return content
        } catch {
            print("❌ read_file error: \(error)")
            return "Error reading '\(filename)': \(error.localizedDescription)"
        }
    }

    private func executeDeleteFile(_ toolCall: ToolCall) async -> String {
        let filename = toolCall.input["filename"]?.stringValue ?? ""
        guard !filename.isEmpty else { return "Error: filename is required" }

        print("🔧 delete_file: \(filename)")

        do {
            try await fileRepository.deleteFileByName(filename)
            print("✅ File deleted: \(filename)")
            return "File '\(filename)' deleted successfully."
        } catch {
            print("❌ delete_file error: \(error)")
            return "Error deleting '\(filename)': \(error.localizedDescription)"
        }
    }

    private func executeListFiles() async -> String {
        print("🔧 list_files")

        do {
            let files = try await fileRepository.listFiles()
            if files.isEmpty {
                return "No files found on device."
            }
            let lines = files.map { "- \($0.name) (\($0.sizeInKB))" }
            return "Files on device (\(files.count)):\n" + lines.joined(separator: "\n")
        } catch {
            print("❌ list_files error: \(error)")
            return "Error listing files: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    private func loadSystemPrompt() {
        self.systemPrompt = """
        You are a helpful AI assistant for iPad designed to help users create and manage documents.

        You are running on an iPad app that supports the following file tools:
        - write_file: create a new file or overwrite an existing one
        - read_file: read the full content of an existing file
        - list_files: list all files saved on the device
        - delete_file: permanently delete a file from the device

        When a user asks to edit or update an existing file, always call read_file first to get the current content, then write_file with the updated content.
        Only use delete_file when the user explicitly asks to delete or remove a file.
        Be concise and helpful.
        """
    }
}
