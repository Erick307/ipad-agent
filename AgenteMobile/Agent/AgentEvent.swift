//
//  AgentEvent.swift
//  AgenteMobile
//

import Foundation

/// What the agent loop reports while it runs, in the order it happens.
enum AgentEvent: Equatable {
    /// Text Claude wrote. One turn can produce several, between tool calls.
    case assistantText(String)
    case toolStarted(name: String)
    case toolFinished(name: String, isError: Bool)
}

/// Why the agent loop stopped before Claude finished its turn.
enum AgentError: LocalizedError, Equatable {
    case maxTokens
    case refusal
    case stepLimitReached(Int)
    case unexpectedStop(String)
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .maxTokens:
            return "The response was cut off (max_tokens). Try a shorter request."
        case .refusal:
            return "Claude declined to complete this request."
        case .stepLimitReached(let steps):
            return "Stopped after \(steps) steps. Send another message to continue."
        case .unexpectedStop(let reason):
            return "Unexpected stop reason: \(reason)"
        case .alreadyRunning:
            return "Claude is still working on the previous message."
        }
    }
}
