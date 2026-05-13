//
//  FileRepository.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Observation

@Observable
final class FileRepository {
    var files: [GeneratedFile] = []

    var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        loadFiles()
    }

    private func loadFiles() {
        // TODO: Load actual files from disk
        // For now, this returns empty array
        DispatchQueue.main.async {
            self.files = []
        }
    }

    func createFile(filename: String, content: String) async throws -> GeneratedFile {
        // TODO: Implement file creation
        let fileSize = content.utf8.count
        let file = GeneratedFile(
            id: UUID(),
            name: filename,
            content: content,
            createdDate: Date(),
            filePath: documentDirectory.appendingPathComponent(filename),
            fileSize: fileSize
        )

        await MainActor.run {
            self.files.append(file)
        }

        return file
    }

    func deleteFile(_ file: GeneratedFile) async throws {
        // TODO: Implement file deletion
        await MainActor.run {
            self.files.removeAll { $0.id == file.id }
        }
    }

    func readFile(_ file: GeneratedFile) async throws -> String {
        // TODO: Implement file reading
        return file.content
    }

    func listFiles() async throws -> [GeneratedFile] {
        // TODO: Implement file listing
        return files
    }
}
