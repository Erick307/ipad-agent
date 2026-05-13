import Foundation

struct GeneratedFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let content: String
    let createdDate: Date
    let filePath: URL
    let fileSize: Int

    var sizeInKB: String {
        String(format: "%.1f KB", Double(fileSize) / 1024)
    }
}
