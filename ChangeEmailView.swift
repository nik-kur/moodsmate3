import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChangeEmailView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var newEmail = ""
    @State private var password = ""
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
                                    Text("Change Email")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    Text("Enter your new email and current password")
                                        .font(.system(size: 16))
                                        .foregroundColor(colors.textSecondary)
                                }
                                
                                
                                // New Email Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("New Email")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    TextField("Enter new email", text: $newEmail)
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
                                
                                
                                // Current Password Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Current Password")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    SecureField("Enter current password", text: $password)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                
                                
                                // Error and Success Messages
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                    
                                }
                                
                                if !successMessage.isEmpty {
                                    Text(successMessage)
                                        .foregroundColor(.green)
                                    
                                }
                                
                                // Change Email Button
                                Button(action: changeEmail) {
                                    Text("Change Email")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                
                                .disabled(!isFormValid)
                            }
                            .padding(.vertical, 24)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .navigationBarHidden(true)
            }
        }
    }
    
    private var isFormValid: Bool {
        !newEmail.isEmpty &&
        newEmail.contains("@") &&
        !password.isEmpty
    }
    
    private func changeEmail() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: user.email!, password: password)
        
        user.reauthenticate(with: credential) { (result, error) in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            user.sendEmailVerification(beforeUpdatingEmail: newEmail) { (error) in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    successMessage = "Verification email sent. Please verify your new email."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func updateEmailInFirestore(newEmail: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData(["email": newEmail]) { error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                successMessage = "Email updated successfully"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
struct ChangeEmailView_Previews: PreviewProvider {
   static var previews: some View {
       ChangeEmailView()
           .environmentObject(AuthViewModel())
   }
}
