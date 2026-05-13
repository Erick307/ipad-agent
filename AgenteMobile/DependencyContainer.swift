class DependencyContainer {
    
    let claudeRepository =  ClaudeRepository()
    let fileRepository = FileRepository()
    let speechRecognizer = SpeechRecognizerService()
    
    func makeChatViewModel() -> ChatViewModel {
        return ChatViewModel(claudeRepository: claudeRepository, fileRepository: fileRepository, speechRecognizer: speechRecognizer)
    }
}
