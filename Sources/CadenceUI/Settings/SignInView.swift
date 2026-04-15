import SwiftUI
import CadenceCore

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var createAccount = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !isWorking
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .emailField()
                    SecureField("Password", text: $password)
                        .textContentType(createAccount ? .newPassword : .password)
                } footer: {
                    if createAccount {
                        Text("At least 8 characters.")
                    }
                }

                Section {
                    Toggle("Create a new account", isOn: $createAccount)
                }

                Section {
                    TextField("Server URL", text: $model.settings.serverURLString)
                        .autocorrectionDisabled()
                } header: {
                    Text("Server")
                } footer: {
                    Text("Point this at your cadence-api instance. The default works with a local dev server.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(createAccount ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle(createAccount ? "Create Account" : "Sign In")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onSubmit(submit)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.signIn(email: email, password: password, createAccount: createAccount)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView().environment(AppModel.preview())
    }
}
