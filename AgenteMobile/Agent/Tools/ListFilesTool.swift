//
//  ListFilesTool.swift
//  AgenteMobile
//

import Foundation

struct ListFilesTool: AgentTool {
    let fileRepository: FileRepository

    let name = "list_files"
    let description = "Lists all files saved on the device. Use this to discover what files exist before reading or editing one."
    let inputSchema = ToolInputSchema(properties: [:], required: [])

    func execute(_ input: ToolInput) async throws -> String {
        let files = try await fileRepository.listFiles()
        if files.isEmpty {
            return "No files found on device."
        }
        let lines = files.map { "- \($0.name) (\($0.sizeInKB))" }
        return "Files on device (\(files.count)):\n" + lines.joined(separator: "\n")
    }
}
