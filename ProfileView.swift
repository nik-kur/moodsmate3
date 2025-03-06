import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showProfileSetup = false
    @State private var showChangeEmailSheet = false
    @State private var showChangePasswordSheet = false
    @State private var showDeleteAccountSheet = false
    @State private var showNotificationSettings = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
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
                                        Text("Profile")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Manage your account")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "person.circle.fill")
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
                                
                            )
                            
                            VStack(spacing: 20) {
                                // Profile Information Section
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Account Details")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                        .padding(.horizontal)
                                    
                                    ProfileInfoRow(icon: "person", title: "Name", value: authViewModel.currentUserName ?? "")
                                    ProfileInfoRow(icon: "envelope", title: "Email", value: Auth.auth().currentUser?.email ?? "")
                                    ProfileInfoRow(icon: "birthday.cake", title: "Age", value: "\(authViewModel.currentUserAge ?? 0)")
                                    ProfileInfoRow(icon: "person.2", title: "Gender", value: authViewModel.currentUserGender ?? "")
                                    
                                    Button("Edit Profile") {
                                        showProfileSetup = true
                                    }
                                    .font(.headline)
                                    .foregroundColor(colors.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                    
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        
                                    )
                                    .padding(.horizontal)
                                    // Add this state variable to ProfileView
                                   

                                    // Add this button in the ProfileView - place it in the "Account Security" VStack
                                    Button(action: {
                                        showNotificationSettings = true
                                    }) {
                                        HStack {
                                            Image(systemName: "bell")
                                                .font(.system(size: 20))
                                            Text("Notification Settings")
                                                .font(.headline)
                                        }
                                        .foregroundColor(colors.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                    }

                                   
                                }
                                
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Account Security")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)

                                    if !authViewModel.isAppleSignInUser {
                                        Button(action: {
                                            showChangeEmailSheet = true
                                        }){
                                            HStack {
                                                Image(systemName: "envelope")
                                                    .font(.system(size: 20))
                                                Text("Change Email")
                                                    .font(.headline)
                                            }
                                            .foregroundColor(colors.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(colors.buttonBackground)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                        }

                                        Button (action: {
                                            showChangePasswordSheet = true
                                        }) {
                                            HStack {
                                                Image(systemName: "lock")
                                                    .font(.system(size: 20))
                                                Text("Change Password")
                                                    .font(.headline)
                                            }
                                            .foregroundColor(colors.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(colors.buttonBackground)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                        }

                                        // Delete Account Button
                                        Button (action: {
                                            showDeleteAccountSheet = true
                                        }) {
                                            HStack {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 20))
                                                Text("Delete Account")
                                                    .font(.headline)
                                            }
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(colors.buttonBackground)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                    } else {
                                        Text("Your account is secured with Apple ID.")
                                            .foregroundColor(.gray)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(colors.buttonBackground)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                

                                    
                                    // Logout Button
                                    Button(action: { authViewModel.logout() }) {
                                        Text("Logout")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(colors.secondary)
                                            .cornerRadius(16)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 20)
                        }
                        .padding(.bottom, 90)
                    }
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea()
                }
                .frame(maxWidth: .infinity) // Add this line
                    .navigationViewStyle(StackNavigationViewStyle())
            }
            .frame(maxWidth: .infinity) // Add this line
                .navigationViewStyle(StackNavigationViewStyle())
            .sheet(isPresented: $showProfileSetup) {
                ProfileSetupView(
                    currentName: authViewModel.currentUserName ?? "",
                    currentAge: authViewModel.currentUserAge ?? 0,
                    currentGender: authViewModel.currentUserGender ?? ""
                )
            }
           
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showChangeEmailSheet) {
                ChangeEmailView()
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showDeleteAccountSheet) {
                DeleteAccountView()
            }
        }
    }
    private func getSafeAreaTop() -> CGFloat {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window?.safeAreaInsets.top ?? 0
        }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}
