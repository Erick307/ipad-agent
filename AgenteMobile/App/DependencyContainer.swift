class DependencyContainer {
    
    let apiKeyStore = APIKeyStore()
    let fileRepository = FileRepository()
    let speechRecognizer = SpeechRecognizerService()
    
    func makeChatViewModel() -> ChatViewModel {
        return ChatViewModel(
            repository: AnthropicAPIRepository(apiKeyStore: apiKeyStore),
            tools: [
                WriteFileTool(fileRepository: fileRepository),
                ReadFileTool(fileRepository: fileRepository),
                ListFilesTool(fileRepository: fileRepository),
                DeleteFileTool(fileRepository: fileRepository)
            ],
            speechRecognizer: speechRecognizer
        )
    }
}
