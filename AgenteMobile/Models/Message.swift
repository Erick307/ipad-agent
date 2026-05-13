//
//  Message.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    let isError: Bool = false

    var isSentByUser: Bool { role == "user" }
}
