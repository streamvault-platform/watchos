import SwiftUI

struct AuthView: View {
    @StateObject private var vm: AuthViewModel

    init(tokenRepository: TokenRepository, apiClient: APIClient) {
        _vm = StateObject(wrappedValue: AuthViewModel(
            tokenRepository: tokenRepository,
            apiClient: apiClient
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Streamvault")
                    .font(.headline)
                    .padding(.top, 8)

                TextField("Server URL", text: $vm.serverUrlInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Username", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Password", text: $vm.password)

                if let error = vm.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: { Task { await vm.login() } }) {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoading)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }
}
