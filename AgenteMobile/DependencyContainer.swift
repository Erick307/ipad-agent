class DependencyContainer {
    
    let apiKeyStore = APIKeyStore()
    lazy var claudeRepository = ClaudeRepository(apiKeyStore: apiKeyStore)
    let fileRepository = FileRepository()
    let speechRecognizer = SpeechRecognizerService()
    
    func makeChatViewModel() -> ChatViewModel {
        return ChatViewModel(claudeRepository: claudeRepository, fileRepository: fileRepository, speechRecognizer: speechRecognizer)
    }
}
