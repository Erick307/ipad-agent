//
//  DeleteFileTool.swift
//  AgenteMobile
//

import Foundation

struct DeleteFileTool: AgentTool {
    let fileRepository: FileRepository

    let name = "delete_file"
    let description = "Permanently deletes a file from the device. Use only when the user explicitly asks to delete or remove a file. This action cannot be undone."
    let inputSchema = ToolInputSchema(
        properties: [
            "filename": PropertySchema(
                type: "string",
                description: "Name of the file to delete (e.g. 'shopping_list.md')."
            )
        ],
        required: ["filename"]
    )

    func execute(_ input: ToolInput) async throws -> String {
        let filename = try input.string("filename")
        try await fileRepository.deleteFileByName(filename)
        return "File '\(filename)' deleted successfully."
    }
}
