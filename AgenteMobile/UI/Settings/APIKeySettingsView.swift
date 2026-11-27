//
//  APIKeySettingsView.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import SwiftUI

struct APIKeySettingsView: View {
    var apiKeyStore: APIKeyStore

    @Environment(\.dismiss) private var dismiss
    @State private var keyInput: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Stored in this iPad's Keychain. It is never saved in the app's files or synced to other devices.")
                }

                if apiKeyStore.isUsingEnvironmentKey {
                    Section {
                        Label("Using ANTHROPIC_API_KEY from the environment. It overrides the stored key.", systemImage: "info.circle")
                            .font(.caption)
                    }
                }

                if apiKeyStore.hasKey && !apiKeyStore.isUsingEnvironmentKey {
                    Section {
                        Button("Remove Stored Key", role: .destructive, action: removeKey)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveKey)
                        .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveKey() {
        do {
            try apiKeyStore.save(keyInput)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try apiKeyStore.delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    APIKeySettingsView(apiKeyStore: APIKeyStore())
}
