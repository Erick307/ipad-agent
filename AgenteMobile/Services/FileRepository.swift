//
//  FileRepository.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation
import Observation

enum FileRepositoryError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "File '\(name)' not found"
        }
    }
}

@Observable
final class FileRepository {
    var files: [GeneratedFile] = []

    var documentDirectory: URL {
        let baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return baseDirectory.appendingPathComponent(AppConstants.FILE_DIRECTORY_NAME)
    }

    init() {
        loadFiles()
    }

    private func loadFiles() {
        Task {
            do {
                let loadedFiles = try await listFiles()
                await MainActor.run {
                    self.files = loadedFiles
                }
            } catch {
                print("❌ Error loading files: \(error)")
            }
        }
    }

    // MARK: - Write

    func writeFile(filename: String, content: String) async throws -> GeneratedFile {
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: documentDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let filePath = documentDirectory.appendingPathComponent(filename)
        let data = content.data(using: .utf8) ?? Data()
        try data.write(to: filePath, options: .atomic)

        let file = GeneratedFile(
            id: UUID(),
            name: filename,
            content: content,
            createdDate: Date(),
            filePath: filePath,
            fileSize: content.utf8.count
        )

        // Replace any existing in-memory entry for this filename
        await MainActor.run {
            self.files.removeAll { $0.name == filename }
            self.files.append(file)
        }

        return file
    }

    // MARK: - Read

    func readFileByName(_ filename: String) async throws -> String {
        let filePath = documentDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            throw FileRepositoryError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: filePath)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func readFile(_ file: GeneratedFile) async throws -> String {
        let data = try Data(contentsOf: file.filePath)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - List

    func listFiles() async throws -> [GeneratedFile] {
        guard FileManager.default.fileExists(atPath: documentDirectory.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: documentDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        )

        return try fileURLs.map { fileURL in
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int ?? 0
            let createdDate = attributes[.modificationDate] as? Date ?? Date()
            let content = try String(contentsOf: fileURL, encoding: .utf8)

            return GeneratedFile(
                id: UUID(),
                name: fileURL.lastPathComponent,
                content: content,
                createdDate: createdDate,
                filePath: fileURL,
                fileSize: fileSize
            )
        }
    }

    // MARK: - Delete

    func deleteFile(_ file: GeneratedFile) async throws {
        try FileManager.default.removeItem(at: file.filePath)
        await MainActor.run {
            self.files.removeAll { $0.id == file.id }
        }
    }
}
