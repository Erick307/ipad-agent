//
//  ChatViewModel.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

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

    private func loadSystemPrompt() {
        // TODO: Load from Resources/SystemPrompts/*.md
        self.systemPrompt = "You are a helpful AI assistant for iPad."
    }

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

        // Start loading
        isLoading = true
        errorMessage = nil

        do {
            // Get response from repository (currently mock)
            let response = try await claudeRepository.sendMessage(
                messages: messages,
                systemPrompt: systemPrompt
            )

            // Add assistant message
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
                    try await executeCreateFile(toolCall)
                }
            }

        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func executeCreateFile(_ toolCall: ToolCall) async throws {
        // TODO: Implement tool execution for file creation
        print("Tool call received: \(toolCall.name)")
    }
}
