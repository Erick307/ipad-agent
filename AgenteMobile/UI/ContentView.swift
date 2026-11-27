import SwiftUI
import Observation

struct ContentView: View {
    @State private var chatViewModel: ChatViewModel
    @State private var fileRepository: FileRepository
    @State private var apiKeyStore: APIKeyStore
    @State private var showAPIKeySettings: Bool

    init() {
        let apiKeyStore = APIKeyStore()
        let fileRepository = FileRepository()
        let speechRecognizer = SpeechRecognizerService()

        let chatViewModel = ChatViewModel(
            repository: AnthropicAPIRepository(apiKeyStore: apiKeyStore),
            tools: [
                WriteFileTool(fileRepository: fileRepository),
                ReadFileTool(fileRepository: fileRepository),
                ListFilesTool(fileRepository: fileRepository),
                DeleteFileTool(fileRepository: fileRepository)
            ],
            speechRecognizer: speechRecognizer
        )

        _chatViewModel = State(initialValue: chatViewModel)
        _fileRepository = State(initialValue: fileRepository)
        _apiKeyStore = State(initialValue: apiKeyStore)
        // Ask for a key on first launch
        _showAPIKeySettings = State(initialValue: !apiKeyStore.hasKey)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Chat View (40%)
            ChatView(viewModel: chatViewModel) {
                showAPIKeySettings = true
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Files View (60%)
            FileListView(fileRepository: fileRepository)
                .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView(apiKeyStore: apiKeyStore)
        }
    }
}

#Preview {
    ContentView()
}
