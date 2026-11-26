//
//  Constants.swift
//  AgenteMobile
//
//  No secrets here. The API key is entered in the app and kept in the
//  Keychain (see APIKeyStore).
//

import Foundation

enum AppConstants {
    static let ANTHROPIC_BASE_URL = "https://api.anthropic.com/v1"
    static let MODEL = "claude-haiku-5-5"
    static let MAX_TOKENS = 4096
    static let FILE_DIRECTORY_NAME = "AgentFiles"
    static let VOICE_LANGUAGE = "en-US"
}
