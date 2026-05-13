//
//  SpeechRecognizerService.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Observation
import Speech
import AVFoundation

@Observable
final class SpeechRecognizerService {
    var recognizedText: String = ""
    var isRecording: Bool = false

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
