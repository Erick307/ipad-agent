//
//  SpeechRecognizerService.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Combine
import Speech
import AVFoundation

class SpeechRecognizerService: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var isRecording: Bool = false

    func startRecording() async {
        // TODO: Implement speech recognition start
    }

    func stopRecording() async {
        // TODO: Implement speech recognition stop
    }

    func cancelRecording() {
        // TODO: Implement speech recognition cancel
    }
}
