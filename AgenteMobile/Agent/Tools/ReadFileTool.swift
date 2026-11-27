//
//  ReadFileTool.swift
//  AgenteMobile
//

import Foundation

struct ReadFileTool: AgentTool {
    let fileRepository: FileRepository

    let name = "read_file"
    let description = "Reads and returns the full content of an existing file on the device. Use this before editing a file so you have the current content."
    let inputSchema = ToolInputSchema(
        properties: [
            "filename": PropertySchema(
                type: "string",
                description: "Name of the file to read (e.g. 'shopping_list.md')."
            )
        ],
        required: ["filename"]
    )

    func execute(_ input: ToolInput) async throws -> String {
        try await fileRepository.readFileByName(input.string("filename"))
    }
}
