import SwiftUI
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
class AuthViewModel: ObservableObject {

    @Published var isLoggedIn: Bool = false
    @Published var userName:   String = ""
    @Published var userEmail:  String = ""

    @Published var emailField:    String = ""
    @Published var passwordField: String = ""
    @Published var confirmField:  String = ""
    @Published var isSignUp:      Bool   = false
    @Published var isLoading:     Bool   = false
    @Published var errorMessage:  String?

    var currentNonce: String?

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "aura.isLoggedIn")
        userName   = UserDefaults.standard.string(forKey: "aura.userName") ?? ""
        userEmail  = UserDefaults.standard.string(forKey: "aura.userEmail") ?? ""
    }

    // MARK: - Apple Sign In

    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let firstName = credential.fullName?.givenName ?? ""
                let lastName  = credential.fullName?.familyName ?? ""
                let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
                let email = credential.email ?? ""

                // Apple only provides name/email on the FIRST sign-in.
                // Save the userIdentifier so we can recognise the user later,
                // and only overwrite stored values if Apple actually sent them.
                let appleUID = credential.user
                UserDefaults.standard.set(appleUID, forKey: "aura.appleUserID")

                if !name.isEmpty  { userName  = name  }
                if !email.isEmpty { userEmail = email }

                // Fallback: if we still have no email, use a stable
                // identifier so per-account storage keys stay consistent.
                if userEmail.isEmpty {
                    let savedEmail = UserDefaults.standard.string(forKey: "aura.userEmail") ?? ""
                    if savedEmail.isEmpty {
                        userEmail = "\(appleUID.prefix(8))@apple.id"
                    } else {
                        userEmail = savedEmail
                    }
                }
                if userName.isEmpty {
                    let savedName = UserDefaults.standard.string(forKey: "aura.userName") ?? ""
                    if !savedName.isEmpty { userName = savedName }
                }

                completeLogin()
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Email / Password

    func signInWithEmail() {
        guard validateEmailFields() else { return }
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false

            guard let account = AccountStore.verifyCredentials(
                email: self.emailField,
                password: self.passwordField
            ) else {
                self.errorMessage = "Account not found or wrong password."
                return
            }

            self.userName  = account.displayName
            self.userEmail = account.email
            self.completeLogin()
        }
    }

    func signUpWithEmail() {
        guard validateEmailFields() else { return }
        guard passwordField == confirmField else {
            errorMessage = "Passwords don't match."
            return
        }
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoading = false

            // Check if already registered
            if AccountStore.accountExists(email: self.emailField) {
                self.errorMessage = "An account with this email already exists. Try signing in."
                return
            }

            let displayName = self.emailField
                .components(separatedBy: "@").first?
                .replacingOccurrences(of: ".", with: " ")
                .capitalized ?? "User"

            let created = AccountStore.createAccount(
                email: self.emailField,
                password: self.passwordField,
                displayName: displayName
            )

            guard created else {
                self.errorMessage = "Could not create account. Try again."
                return
            }

            self.userName  = displayName
            self.userEmail = self.emailField.lowercased()
            self.completeLogin()
        }
    }

    // MARK: - Logout

    func logout() {
        isLoggedIn = false
        userName   = ""
        userEmail  = ""
        emailField    = ""
        passwordField = ""
        confirmField  = ""
        errorMessage  = nil
        isSignUp      = false

        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "aura.isLoggedIn")
        defaults.removeObject(forKey: "aura.userName")
        defaults.removeObject(forKey: "aura.userEmail")
    }

    // MARK: - Helpers

    private func completeLogin() {
        withAnimation(.easeInOut(duration: 0.5)) { isLoggedIn = true }
        let defaults = UserDefaults.standard
        defaults.set(true,      forKey: "aura.isLoggedIn")
        defaults.set(userName,  forKey: "aura.userName")
        defaults.set(userEmail, forKey: "aura.userEmail")
    }

    private func validateEmailFields() -> Bool {
        guard !emailField.isEmpty else {
            errorMessage = "Please enter your email."
            return false
        }
        guard emailField.contains("@") && emailField.contains(".") else {
            errorMessage = "Enter a valid email address."
            return false
        }
        guard passwordField.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        return true
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
