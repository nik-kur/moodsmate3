import SwiftUI
import FirebaseAuth
import LocalAuthentication
import GoogleSignIn
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var showForgotPasswordView = false
    @State private var showProfileSetup = false
    @State private var showBiometricLogin = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    var body: some View {
        if !networkMonitor.isConnected {
                OfflineView()
        } else {
            NavigationView {
                ZStack {
                    colors.background.ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(isLogin ? "Login" : "Create Account")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(isLogin ? "Welcome back!" : "Create your account")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isLogin ? "person.fill" : "person.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, getSafeAreaTop())
                            .padding(.bottom, 24)
                            .background(
                                colors.secondary
                                    .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                                    .ignoresSafeArea(edges: .top)
                            )
                            
                            VStack(spacing: 24) {
                                // Email Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Email")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    TextField("Enter your email", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .autocorrectionDisabled()
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal)
                                
                                // Password Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Password")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    SecureField("Enter your password", text: $password)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal)
                                
                                // Confirm Password (for registration)
                                if !isLogin {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Confirm Password")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colors.secondary)
                                        
                                        SecureField("Confirm your password", text: $confirmPassword)
                                            .padding()
                                            .background(colors.buttonBackground)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Forgot Password Link
                                if isLogin {
                                    Button("Forgot Password?") {
                                        showForgotPasswordView = true
                                    }
                                    .foregroundColor(colors.secondary)
                                    .padding(.horizontal)
                                }
                                
                                // Error Message
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                                
                                // Action Button
                                Button(action: performAuthAction) {
                                    Text(isLogin ? "Login" : "Create Account")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .disabled(!isAuthValid)
                                
                                Button(action: {
                                    authViewModel.appleSignIn { result in
                                        switch result {
                                        case .success():
                                            // Handled in ViewModel
                                            break
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "applelogo")
                                        Text("Sign in with Apple")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                                    
                                }
                                .padding(.horizontal)
                                
                                // Switch between Login and Register
                                Button(action: {
                                    isLogin.toggle()
                                    errorMessage = ""
                                }) {
                                    Text(isLogin
                                         ? "Don't have an account? Register"
                                         : "Already have an account? Login")
                                    .foregroundColor(colors.secondary)
                                }
                                .padding()
                                
                            }
                            .padding(.vertical, 24)
                        }
                    }
                    .navigationBarHidden(true)
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $authViewModel.shouldShowInitialProfileSetup) {
                ProfileSetupView()
            }.onChange(of: authViewModel.isLoggedIn) {
                if authViewModel.isLoggedIn {
                    authViewModel.shouldShowInitialProfileSetup = false // ✅ Ensure profile setup view is dismissed
                }
            }


            .sheet(isPresented: $showForgotPasswordView) {
                ForgotPasswordView(
                    isPresented: $showForgotPasswordView,
                    colors: colors
                )
            }
            .sheet(isPresented: $showProfileSetup) {
                ProfileSetupView()
            }
        }
    }
    
    private var isAuthValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        (isLogin || (!confirmPassword.isEmpty && password == confirmPassword))
    }
    
    private func performAuthAction() {
        if isLogin {
            loginUser()
        } else {
            registerUser()
        }
    }
    private func getSafeAreaTop() -> CGFloat {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window?.safeAreaInsets.top ?? 0
        }
    
    private func loginUser() {
        authViewModel.login(email: email, password: password) { result in
            switch result {
            case .success():
                // Handled in ViewModel
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func registerUser() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        authViewModel.register(email: email, password: password) { result in
            switch result {
            case .success():
                // Trigger first-time profile setup
                authViewModel.shouldShowInitialProfileSetup = true
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func googleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        authViewModel.googleSignIn(presentingViewController: rootViewController) { result in
            switch result {
            case .success():
                // Handle successful login
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    private func handleBiometricError(_ error: NSError?) {
        guard let laError = error as? LAError else {
            errorMessage = "Biometric authentication unavailable"
            return
        }
        
        switch laError.code {
        case .biometryNotAvailable:
            errorMessage = "Biometric authentication not available on this device"
        case .biometryNotEnrolled:
            errorMessage = "No biometric authentication methods enrolled"
        default:
            errorMessage = laError.localizedDescription
        }
    }

    private func handleBiometricAuthFailure(_ error: Error?) {
        guard let laError = error as? LAError else {
            errorMessage = "Authentication failed"
            return
        }
        
        switch laError.code {
        case .userCancel:
            errorMessage = "Authentication was canceled by user"
        case .userFallback:
            errorMessage = "User selected alternate authentication method"
        case .systemCancel:
            errorMessage = "Authentication was canceled by system"
        default:
            errorMessage = "Biometric authentication failed"
        }
    }

    private func handleSuccessfulBiometricAuth() {
        guard let currentUser = Auth.auth().currentUser,
              let email = currentUser.email,
              let storedPassword = KeychainManager.retrieve(email: email) else {
            errorMessage = "No stored credentials found"
            return
        }
        
        authViewModel.login(email: email, password: storedPassword) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    break
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func performBiometricLogin() {
        guard let email = Auth.auth().currentUser?.email,
              let storedPassword = KeychainManager.retrieve(email: email) else {
            errorMessage = "No stored credentials found"
            return
        }
        
        authViewModel.login(email: email, password: storedPassword) { result in
            switch result {
            case .success():
                break
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
struct ForgotPasswordView: View {
    @Binding var isPresented: Bool
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        text: Color,
        textSecondary: Color
    )
    
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Close Button at the top
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(colors.secondary)
                                .padding()
                        }
                    }
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Title and Subtitle
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Reset Password")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(colors.secondary)
                                
                                Text("Enter your email to receive a password reset link")
                                    .font(.system(size: 16))
                                    .foregroundColor(colors.textSecondary)
                            }
                            .padding(.horizontal, 20)
                            
                            // Email Input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Email")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(colors.secondary)
                                
                                TextField("Enter your email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .padding(.horizontal, 20)
                            
                            // Error and Success Messages
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 20)
                            }
                            
                            if !successMessage.isEmpty {
                                Text(successMessage)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Send Reset Link Button
                            Button(action: resetPassword) {
                                Text("Send Reset Link")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(colors.secondary)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, 20)
                            .disabled(email.isEmpty)
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        
    }
       
    
    private func resetPassword() {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                successMessage = ""
            } else {
                successMessage = "Password reset link sent. Check your email."
                errorMessage = ""
                
                // Automatically dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isPresented = false
                }
            }
        }
    }
}
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(AuthViewModel())
    }
}
