import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date

    var isSentByUser: Bool { role == "user" }

    static func user(_ content: String) -> Message {
        Message(id: UUID(), role: "user", content: content, timestamp: Date())
    }

    static func assistant(_ content: String) -> Message {
        Message(id: UUID(), role: "assistant", content: content, timestamp: Date())
    }
}
