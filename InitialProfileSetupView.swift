import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct InitialProfileSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    
    @State private var name = ""
    @State private var age = ""
    @State private var selectedGender = ""
    @State private var errorMessage = ""
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    private let genders = ["Male", "Female", "Non-Binary", "Prefer not to say"]
    
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
                                        Text("Setup Profile")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("Complete your profile to get started")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "person.badge.plus")
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
                                // Name Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Full Name")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    TextField("Enter your full name", text: $name)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal)
                                
                                // Age Input
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Age")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    TextField("Enter your age", text: $age)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal)
                                
                                // Gender Selection
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Gender")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(colors.secondary)
                                    
                                    Menu {
                                        ForEach(genders, id: \.self) { gender in
                                            Button(gender) {
                                                selectedGender = gender
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedGender.isEmpty ? "Select Gender" : selectedGender)
                                                .foregroundColor(selectedGender.isEmpty ? .gray : .primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.down")
                                                .foregroundColor(colors.secondary)
                                        }
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Error Message
                                if !errorMessage.isEmpty {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                                
                                // Action Button
                                Button(action: saveProfile) {
                                    Text("Complete Profile")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .disabled(!isProfileValid || !networkMonitor.isConnected)
                            }
                            .padding(.vertical, 24)
                        }
                    }
                    .navigationBarHidden(true)
                    .ignoresSafeArea()
                }
            }
        }
    }
    private var isProfileValid: Bool {
        !name.isEmpty &&
        !(age.isEmpty || Int(age) == nil) &&
        !selectedGender.isEmpty
    }
    private func getSafeAreaTop() -> CGFloat {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window?.safeAreaInsets.top ?? 0
        }
    private func saveProfile() {
        guard networkMonitor.isConnected else {
                errorMessage = "No internet connection"
                return
            }
        guard let ageValue = Int(age) else {
            errorMessage = "Please enter a valid age"
            return
        }
        
        authViewModel.completeInitialProfile(name: name, age: ageValue, gender: selectedGender) { result in
            switch result {
            case .success():
                DispatchQueue.main.async {
                    authViewModel.shouldShowInitialProfileSetup = false  // ✅ Dismiss profile setup
                    authViewModel.isProfileComplete = true  // ✅ Redirect to main page
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }

    }
}
