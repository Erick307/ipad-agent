//
//  SystemPrompt.swift
//  AgenteMobile
//

import Foundation

enum SystemPrompt {
    /// The tool list comes from the tools themselves, so adding one updates the prompt.
    static func make(tools: [AgentTool]) -> String {
        let toolList = tools
            .map { "- \($0.name): \($0.description)" }
            .joined(separator: "\n")

        return """
        You are a helpful AI assistant for iPad designed to help users create and manage documents.

        You are running on an iPad app that supports the following file tools:
        \(toolList)

        When a user asks to edit or update an existing file, always call read_file first to get the current content, then write_file with the updated content.
        Be concise and helpful.
        """
    }
}
