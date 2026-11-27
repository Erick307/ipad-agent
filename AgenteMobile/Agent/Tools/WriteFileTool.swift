//
//  WriteFileTool.swift
//  AgenteMobile
//

import Foundation

struct WriteFileTool: AgentTool {
    let fileRepository: FileRepository

    let name = "write_file"
    let description = "Creates a new file or overwrites an existing file with the given content. Use this to save or update any document on the device."
    let inputSchema = ToolInputSchema(
        properties: [
            "filename": PropertySchema(
                type: "string",
                description: "Plain file name with no folders or path characters (e.g. 'shopping_list.md'). Use .md extension for markdown."
            ),
            "content": PropertySchema(
                type: "string",
                description: "Full content to write to the file."
            )
        ],
        required: ["filename", "content"]
    )

    func execute(_ input: ToolInput) async throws -> String {
        let filename = try input.string("filename")
        let content = try input.string("content")
        let file = try await fileRepository.writeFile(filename: filename, content: content)
        return "File '\(filename)' saved successfully. Size: \(file.sizeInKB)"
    }
}
