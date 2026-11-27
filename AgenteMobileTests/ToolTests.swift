//
//  ToolTests.swift
//  AgenteMobileTests
//

import Foundation
import Testing
@testable import AgenteMobile

@MainActor
struct ToolTests {
    let directory: URL
    let fileRepository: FileRepository

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileRepository = FileRepository(directory: directory)
    }

    @Test func missingParameterThrows() async throws {
        let tool = WriteFileTool(fileRepository: fileRepository)

        await #expect(throws: ToolInputError.missingParameter("content")) {
            _ = try await tool.execute(ToolInput(["filename": .string("notes.md")]))
        }
    }

    @Test func fileToolsWorkTogether() async throws {
        let write = WriteFileTool(fileRepository: fileRepository)
        let read = ReadFileTool(fileRepository: fileRepository)
        let list = ListFilesTool(fileRepository: fileRepository)
        let delete = DeleteFileTool(fileRepository: fileRepository)
        let notes = ToolInput(["filename": .string("notes.md")])

        _ = try await write.execute(ToolInput(["filename": .string("notes.md"), "content": .string("# Notes")]))
        #expect(try await read.execute(notes) == "# Notes")
        #expect(try await list.execute(ToolInput([:])).contains("- notes.md"))

        _ = try await delete.execute(notes)
        #expect(try await list.execute(ToolInput([:])) == "No files found on device.")
    }

    @Test func systemPromptListsTheInjectedTools() {
        let prompt = SystemPrompt.make(tools: [FakeTool(name: "first_tool"), FakeTool(name: "second_tool")])

        #expect(prompt.contains("- first_tool: A fake tool for tests."))
        #expect(prompt.contains("- second_tool: A fake tool for tests."))
    }
}
