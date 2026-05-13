//
//  FileListView.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import SwiftUI

struct FileListView: View {
    var fileRepository: FileRepository
    @State private var selectedFile: GeneratedFile?
    @State private var showingFileDetail = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Files")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(fileRepository.files.count) generated file(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .borderBottom()

            // File list or empty state
            if fileRepository.files.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No files yet")
                        .font(.headline)
                    Text("Files created in chat will appear here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                List {
                    ForEach(fileRepository.files) { file in
                        FileListRow(file: file)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedFile = file
                                showingFileDetail = true
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showingFileDetail) {
            if let file = selectedFile {
                FileDetailView(file: file, isPresented: $showingFileDetail)
            }
        }
    }
}

struct FileListRow: View {
    let file: GeneratedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(file.createdDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, 8)
    }
}

struct FileDetailView: View {
    let file: GeneratedFile
    @Binding var isPresented: Bool
    @State private var isCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(file.createdDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .borderBottom()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(file.content)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            Text(isCopied ? "Copied!" : "Copy")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }

                    Button(action: shareFile) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = file.content
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }

    private func shareFile() {
        let activityVC = UIActivityViewController(
            activityItems: [file.content],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

#Preview {
    FileListView(fileRepository: FileRepository())
}
