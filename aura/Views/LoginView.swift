import SwiftUI
import AuthenticationServices

// ============================================================
// MARK: - LOGIN VIEW
// ============================================================

struct LoginView: View {
    @ObservedObject var auth: AuthViewModel

    @State private var showEmailLogin = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            AuraBackground()

            VStack(spacing: 0) {

                Spacer()

                // Logo / Branding
                VStack(spacing: 16) {
                    Text("Aura")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Tune into your well-being")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AuraTheme.textTertiary)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer()
                Spacer()

                // Auth Buttons
                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        auth.handleAppleRequest(request)
                    } onCompletion: { result in
                        auth.handleAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(action: {
                        withAnimation(.spring(duration: 0.4)) { showEmailLogin = true }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.85))
                            Text("Continue with Email")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 28)
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)

                Spacer()

                Text("By continuing, you agree to our Terms & Privacy Policy")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AuraTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .opacity(buttonsOpacity)
            }

            if showEmailLogin {
                EmailLoginView(auth: auth, isPresented: $showEmailLogin)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if auth.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.2)
            }
        }
        .animation(.easeOut(duration: 0.3), value: auth.errorMessage != nil)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                buttonsOffset = 0
                buttonsOpacity = 1.0
            }
        }
    }
}

// ============================================================
// MARK: - EMAIL LOGIN VIEW
// ============================================================

struct EmailLoginView: View {
    @ObservedObject var auth: AuthViewModel
    @Binding var isPresented: Bool

    @FocusState private var focusedField: Field?
    enum Field { case email, password, confirm }

    /// Height of the visible scroll area, used so the form fills the screen.
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        ZStack {
            AuraBackground()

            ScrollView {
                VStack(spacing: 0) {

                    HStack {
                        Button(action: {
                            withAnimation(.spring(duration: 0.4)) {
                                auth.errorMessage = nil
                                focusedField = nil
                                isPresented = false
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(AuraTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer(minLength: 60)

                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Text(auth.isSignUp ? "Create Account" : "Welcome Back")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(auth.isSignUp ? "Sign up with your email" : "Sign in to continue")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(AuraTheme.textTertiary)
                        }

                        VStack(spacing: 14) {
                            AuraTextField(icon: "envelope", placeholder: "Email",
                                          text: $auth.emailField, isSecure: false)
                                .focused($focusedField, equals: .email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }

                            AuraTextField(icon: "lock", placeholder: "Password",
                                          text: $auth.passwordField, isSecure: true)
                                .focused($focusedField, equals: .password)
                                .textContentType(auth.isSignUp ? .newPassword : .password)
                                .submitLabel(auth.isSignUp ? .next : .go)
                                .onSubmit {
                                    if auth.isSignUp { focusedField = .confirm }
                                    else { auth.signInWithEmail() }
                                }

                            if auth.isSignUp {
                                AuraTextField(icon: "lock.rotation", placeholder: "Confirm Password",
                                              text: $auth.confirmField, isSecure: true)
                                    .focused($focusedField, equals: .confirm)
                                    .textContentType(.newPassword)
                                    .submitLabel(.go)
                                    .onSubmit { auth.signUpWithEmail() }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }

                        Button(action: {
                            auth.isSignUp ? auth.signUpWithEmail() : auth.signInWithEmail()
                        }) {
                            Text(auth.isSignUp ? "Create Account" : "Sign In")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(AuraTheme.bgDeep)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
                                )
                        }

                        Button(action: {
                            withAnimation(.spring(duration: 0.35)) {
                                auth.isSignUp.toggle()
                                auth.errorMessage = nil
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(auth.isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(AuraTheme.textTertiary)
                                Text(auth.isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundColor(.white)
                            }
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 80)
                }
                .frame(minHeight: viewportHeight)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focusedField = nil }
        }
        .animation(.easeOut(duration: 0.3), value: auth.errorMessage != nil)
        .animation(.spring(duration: 0.35), value: auth.isSignUp)
    }
}
