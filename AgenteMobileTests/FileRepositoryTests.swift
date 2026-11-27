//
//  FileRepositoryTests.swift
//  AgenteMobileTests
//

import Foundation
import Testing
@testable import AgenteMobile

@MainActor
struct FileRepositoryTests {
    let root: URL
    let agentDirectory: URL
    let repository: FileRepository

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileRepositoryTests-\(UUID().uuidString)")
        agentDirectory = root.appendingPathComponent("AgentFiles")
        try FileManager.default.createDirectory(at: agentDirectory, withIntermediateDirectories: true)
        repository = FileRepository(directory: agentDirectory)
    }

    static let maliciousNames = [
        "../escape.md",
        "../../Library/Preferences/x.plist",
        "notes/../../escape.md",
        "sub/notes.md",
        "/etc/passwd",
        "..\\escape.md",
        "a:b.md",
        "..",
        ".",
        ".hidden",
        "",
        "   ",
        "bad\nname.md",
        "nul\0.md"
    ]

    @Test(arguments: maliciousNames)
    func writeRejectsPathLikeNames(_ name: String) async throws {
        await #expect(throws: FileRepositoryError.self) {
            _ = try await repository.writeFile(filename: name, content: "pwned")
        }
        // Nothing may be created next to the agent folder
        let siblings = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(siblings == ["AgentFiles"])
    }

    @Test(arguments: maliciousNames)
    func readRejectsPathLikeNames(_ name: String) async throws {
        await #expect(throws: FileRepositoryError.self) {
            _ = try await repository.readFileByName(name)
        }
    }

    @Test func deleteCannotRemoveFilesOutsideFolder() async throws {
        let outside = root.appendingPathComponent("keep.md")
        try Data("important".utf8).write(to: outside)

        await #expect(throws: FileRepositoryError.self) {
            try await repository.deleteFileByName("../keep.md")
        }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test func plainNamesRoundTrip() async throws {
        _ = try await repository.writeFile(filename: "shopping list.md", content: "- milk")
        let content = try await repository.readFileByName("shopping list.md")
        #expect(content == "- milk")

        try await repository.deleteFileByName("shopping list.md")
        await #expect(throws: FileRepositoryError.self) {
            _ = try await repository.readFileByName("shopping list.md")
        }
    }
}
