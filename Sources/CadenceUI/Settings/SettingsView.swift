import SwiftUI
import CadenceCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showingSignIn = false
    @State private var confirmingErase = false
    @State private var exportURL: URL?

    var body: some View {
        @Bindable var model = model

        Form {
            Section("Units") {
                Picker("Weight", selection: $model.settings.weightUnit) {
                    ForEach(WeightUnit.allCases) { Text($0.symbol).tag($0) }
                }
                Picker("Distance", selection: $model.settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases) { Text($0.symbol).tag($0) }
                }
            }

            Section {
                if model.isSignedIn {
                    LabeledContent("Signed in as", value: model.settings.accountEmail ?? "—")
                    Button {
                        Task { await model.sync() }
                    } label: {
                        HStack {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if model.syncStatus == .syncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(model.syncStatus == .syncing)
                    Button("Sign Out", role: .destructive) {
                        model.signOut()
                    }
                } else {
                    Button {
                        showingSignIn = true
                    } label: {
                        Label("Sign in to sync", systemImage: "icloud")
                    }
                }
            } header: {
                Text("Account")
            } footer: {
                Text(syncFooter)
            }

            Section("Data") {
                Button {
                    exportURL = try? model.exportFileURL()
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share cadence-export.json", systemImage: "doc")
                    }
                }
                Button {
                    model.loadSampleData()
                } label: {
                    Label("Load Sample Data", systemImage: "sparkles")
                }
                Button(role: .destructive) {
                    confirmingErase = true
                } label: {
                    Label("Erase All Data", systemImage: "trash")
                }
            }

            Section("About") {
                LabeledContent("Version", value: "1.0")
                Link(destination: URL(string: "https://github.com/sid-dutta/cadence-ios")!) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            if let error = model.storageError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .confirmationDialog("Erase all local data?", isPresented: $confirmingErase, titleVisibility: .visible) {
            Button("Erase", role: .destructive) { model.eraseAllData() }
        } message: {
            Text("Workouts and runs on this device will be removed. Synced copies on the server are not affected.")
        }
    }

    private var syncFooter: String {
        switch model.syncStatus {
        case .idle:
            if let last = model.lastSyncedAt {
                return "Last synced \(last.formatted(.relative(presentation: .named)))."
            }
            return model.isSignedIn ? "Not synced yet." : "Sync keeps your history backed up and available on other devices."
        case .syncing:
            return "Syncing…"
        case .succeeded(let date):
            return "Synced \(date.formatted(.relative(presentation: .named)))."
        case .failed(let message):
            return "Sync failed: \(message)"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SettingsView() }
            .environment(AppModel.preview(signedIn: true))
    }
}
