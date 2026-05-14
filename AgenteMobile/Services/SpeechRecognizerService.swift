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

@MainActor
@Observable
final class SpeechRecognizerService {
    var recognizedText: String = ""
    var isRecording: Bool = false
    var errorMessage: String? = nil

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: AppConstants.VOICE_LANGUAGE))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Public Methods

    func startRecording() async {
        guard !isRecording else { return }

        guard await requestPermissions() else {
            errorMessage = "Microphone or speech recognition access denied. Enable in Settings."
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available right now."
            return
        }

        do {
            recognizedText = ""
            errorMessage = nil

            // Configure audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create recognition request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            // Install audio tap — capture request directly to avoid actor isolation
            // issues inside the closure (no self reference needed)
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            // Start recognition — hop back to MainActor for all state mutations
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.recognizedText = result.bestTranscription.formattedString
                    }
                    // Stop when the recognizer finalises (silence detected) or errors
                    if error != nil || result?.isFinal == true {
                        await self.stopRecording()
                    }
                }
            }

        } catch {
            await stopRecording()
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard isRecording else { return }
        isRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancelRecording() {
        Task {
            await stopRecording()
            recognizedText = ""
        }
    }

    // MARK: - Permissions

    nonisolated func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
