import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    var isError: Bool = false

    var isSentByUser: Bool { role == "user" }
}
