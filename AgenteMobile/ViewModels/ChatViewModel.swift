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
    private let fileManagerService: FileManagerService
    private let speechRecognizer: SpeechRecognizerService

    private var systemPrompt: String = ""

    init(
        claudeRepository: ClaudeRepository,
        fileManagerService: FileManagerService,
        speechRecognizer: SpeechRecognizerService
    ) {
        self.claudeRepository = claudeRepository
        self.fileManagerService = fileManagerService
        self.speechRecognizer = speechRecognizer
        loadSystemPrompt()
    }

    private func loadSystemPrompt() {
        // TODO: Load from Resources/SystemPrompts/*.md
        self.systemPrompt = "You are a helpful AI assistant for iPad."
    }

    func sendMessage(_ text: String) async throws {
        // TODO: Implement agentic loop
        print("Message received: \(text)")
    }

    private func executeCreateFile(_ toolCall: ToolCall) async throws {
        // TODO: Implement tool execution
    }
}
