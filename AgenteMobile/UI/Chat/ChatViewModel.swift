import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [Message] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var conversationId: String = UUID().uuidString

    private let repository: AnthropicRepository
    private let tools: [String: AgentTool]
    private let toolDefinitions: [ToolDefinition]
    private let speechRecognizer: SpeechRecognizerService

    private var systemPrompt: String = ""

    /// Maximum number of API round-trips per user message, to stop runaway tool loops.
    private static let maxAgentSteps = 10

    /// Separate message array formatted for the Anthropic API.
    /// Correctly preserves tool_use and tool_result blocks that the
    /// plain display `messages` array cannot represent.
    private var apiMessages: [APIMessage] = []

    init(
        repository: AnthropicRepository,
        tools: [AgentTool],
        speechRecognizer: SpeechRecognizerService
    ) {
        self.repository = repository
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.toolDefinitions = tools.map(\.definition)
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
                let response = try await repository.sendMessage(
                    messages: apiMessages,
                    system: systemPrompt,
                    tools: toolDefinitions
                )

                appendAssistantMessage(response.textContent)

                switch response.stopReason {
                case "tool_use" where !response.toolCalls.isEmpty:
                    let toolCalls = response.toolCalls
                    print("🛠️  Step \(step): Claude called \(toolCalls.count) tool(s)")
                    apiMessages.append(assistantTurn(response))
                    apiMessages.append(await toolResultsTurn(for: toolCalls))
                    // Next iteration sends the results back so Claude can see them

                case "end_turn", "stop_sequence":
                    // An empty assistant turn would be rejected on the next request
                    if !response.content.isEmpty {
                        apiMessages.append(assistantTurn(response))
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

    /// The assistant turn exactly as the API returned it (text, tool_use, thinking...).
    /// The tool_use blocks must be in the history before the matching tool_result blocks.
    private func assistantTurn(_ response: ClaudeResponse) -> APIMessage {
        APIMessage(role: "assistant", blocks: response.content.map(AnyEncodable.init))
    }

    /// Executes every tool call and returns all results in a single user turn.
    private func toolResultsTurn(for toolCalls: [ToolCall]) async -> APIMessage {
        var blocks: [AnyEncodable] = []
        for toolCall in toolCalls {
            let output = await executeToolCall(toolCall)
            blocks.append(AnyEncodable(APIToolResultBlock(
                tool_use_id: toolCall.id,
                content: output.content,
                is_error: output.isError
            )))
        }
        return APIMessage(role: "user", blocks: blocks)
    }

    // MARK: - Tool Execution

    /// Result of running a tool. Failures are still sent back to Claude (flagged
    /// with `is_error`) so it can retry or explain, instead of breaking the loop.
    private struct ToolOutput {
        let content: String
        let isError: Bool

        static func success(_ content: String) -> ToolOutput { ToolOutput(content: content, isError: false) }
        static func failure(_ content: String) -> ToolOutput { ToolOutput(content: content, isError: true) }
    }

    private func executeToolCall(_ toolCall: ToolCall) async -> ToolOutput {
        guard let tool = tools[toolCall.name] else {
            print("⚠️ Unknown tool: \(toolCall.name)")
            return .failure("Error: Unknown tool '\(toolCall.name)'")
        }
        do {
            return .success(try await tool.execute(ToolInput(toolCall.input)))
        } catch {
            print("❌ \(toolCall.name) error: \(error)")
            return .failure("Error: \(error.localizedDescription)")
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
