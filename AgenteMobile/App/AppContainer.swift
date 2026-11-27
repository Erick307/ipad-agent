//
//  AppContainer.swift
//  AgenteMobile
//
//  The one place that creates the app's objects and wires them together.
//  Everything else receives its dependencies instead of building them.
//

import Foundation

final class AppContainer {
    let apiKeyStore = APIKeyStore()
    let fileRepository = FileRepository()
    let speechRecognizer = SpeechRecognizerService()

    func makeChatViewModel() -> ChatViewModel {
        let tools: [AgentTool] = [
            WriteFileTool(fileRepository: fileRepository),
            ReadFileTool(fileRepository: fileRepository),
            ListFilesTool(fileRepository: fileRepository),
            DeleteFileTool(fileRepository: fileRepository)
        ]

        let agent = AgentLoop(
            repository: AnthropicAPIRepository(apiKeyStore: apiKeyStore),
            tools: tools,
            systemPrompt: SystemPrompt.make(tools: tools)
        )

        return ChatViewModel(agent: agent, speechRecognizer: speechRecognizer)
    }
}
