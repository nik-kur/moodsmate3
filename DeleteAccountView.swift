import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DeleteAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var password = ""
    @State private var errorMessage = ""
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary,
        destructive: Color.red
    )
    
    var body: some View {
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
                        VStack(alignment: .leading, spacing: 24) { // Set alignment at top level
                            VStack(alignment: .leading, spacing: 8) { // Reduced spacing for title + subtitle
                                       Text("Delete Account")
                                           .font(.system(size: 34, weight: .bold))
                                           .foregroundColor(colors.destructive)
                                       
                                       Text("Enter your password to permanently delete your account")
                                           .font(.system(size: 16))
                                           .foregroundColor(colors.textSecondary)
                                   }
                            
                            VStack(alignment: .leading, spacing: 8) { Text("Password")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(colors.secondary)
                                
                                SecureField("Enter password", text: $password)
                                    .padding()
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Warning Message
                            Text("Warning: This action cannot be undone")
                                .font(.caption)
                                .foregroundColor(colors.destructive)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }
                            
                            // Delete Account Button
                            Button(action: deleteAccount) {
                                Text("Delete Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(colors.destructive)
                                    .cornerRadius(16)
                            }
                            .disabled(password.isEmpty)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                }
                
            }
            
            .navigationBarHidden(true)
        }
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user logged in"
            return
        }
        
        // Reauthenticate
        let credential = EmailAuthProvider.credential(withEmail: user.email!, password: password)
        
        user.reauthenticate(with: credential) { (result, error) in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            // Delete Firestore user document
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).delete { error in
                if let error = error {
                    errorMessage = "Error deleting user data: \(error.localizedDescription)"
                    return
                }
                
                // Delete Firebase Authentication user
                user.delete { error in
                    if let error = error {
                        errorMessage = "Account deletion failed: \(error.localizedDescription)"
                    } else {
                        // Logout and show account deletion confirmation
                        try? Auth.auth().signOut()
                        authViewModel.shouldShowAccountDeletedMessage = true
                    }
                }
            }
        }
    }
}
struct DeleteAccountView_Previews: PreviewProvider {
   static var previews: some View {
       DeleteAccountView()
           .environmentObject(AuthViewModel())
   }
}
