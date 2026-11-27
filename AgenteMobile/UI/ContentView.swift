import SwiftUI
import Observation

struct ContentView: View {
    @State private var chatViewModel: ChatViewModel
    @State private var fileRepository: FileRepository
    @State private var apiKeyStore: APIKeyStore
    @State private var showAPIKeySettings: Bool

    init(container: AppContainer) {
        _chatViewModel = State(initialValue: container.makeChatViewModel())
        _fileRepository = State(initialValue: container.fileRepository)
        _apiKeyStore = State(initialValue: container.apiKeyStore)
        // Ask for a key on first launch
        _showAPIKeySettings = State(initialValue: !container.apiKeyStore.hasKey)
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
    ContentView(container: AppContainer())
}
