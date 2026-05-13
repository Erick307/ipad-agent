//
//  ContentView.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var fileRepository: FileRepository

    init() {
        let claudeRepository = ClaudeRepository()
        let fileRepository = FileRepository()
        let speechRecognizer = SpeechRecognizerService()

        let chatViewModel = ChatViewModel(
            claudeRepository: claudeRepository,
            fileRepository: fileRepository,
            speechRecognizer: speechRecognizer
        )

        _chatViewModel = StateObject(wrappedValue: chatViewModel)
        _fileRepository = StateObject(wrappedValue: fileRepository)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Chat View (40%)
            ChatView(viewModel: chatViewModel)
                .frame(maxWidth: .infinity)

            Divider()

            // Files View (60%)
            FileListView(fileRepository: fileRepository)
                .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}
