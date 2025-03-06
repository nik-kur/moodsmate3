import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
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
                    
                    VStack(spacing: 0) {
                        // Close Button at the top
                        HStack {
                            Spacer()
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(colors.secondary)
                                    .padding()
                            }
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // Title and Subtitle
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Change Password")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    Text("Enter your current and new password")
                                        .font(.system(size: 16))
                                        .foregroundColor(colors.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                
                                // Current Password Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Current Password")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    SecureField("Enter current password", text: $currentPassword)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                // New Password Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("New Password")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    SecureField("Enter new password", text: $newPassword)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                // Confirm New Password Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Confirm New Password")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    SecureField("Confirm new password", text: $confirmNewPassword)
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
                                
                                // Change Password Button
                                Button(action: changePassword) {
                                    Text("Change Password")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal, 20)
                                .disabled(!isFormValid)
                            }
                            .padding(.vertical, 24)
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmNewPassword.isEmpty &&
        newPassword == confirmNewPassword
    }
    
    private func changePassword() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: user.email!, password: currentPassword)
        
        user.reauthenticate(with: credential) { (result, error) in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            user.updatePassword(to: newPassword) { (error) in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    successMessage = "Password changed successfully"
                    
                    // Automatically dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
struct ChangePasswordView_Previews: PreviewProvider {
   static var previews: some View {
       ChangePasswordView()
           .environmentObject(AuthViewModel())
   }
}


