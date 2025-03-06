import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var networkMonitor = NetworkMonitor()
    
    enum ProfileSetupContext {
        case initialSetup
        case editing
    }
    
    var setupContext: ProfileSetupContext
    
    @State private var name: String
    @State private var age: String
    @State private var selectedGender: String
    @State private var errorMessage = ""
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    private let genders = ["Male", "Female", "Non-Binary", "Prefer not to say"]
    
    // Initializer for new profile setup
    init() {
        setupContext = .initialSetup
        _name = State(initialValue: "")
        _age = State(initialValue: "")
        _selectedGender = State(initialValue: "")
    }
    
    // Initializer for profile editing
    init(currentName: String, currentAge: Int, currentGender: String) {
        setupContext = .editing
        _name = State(initialValue: currentName)
        _age = State(initialValue: String(currentAge))
        _selectedGender = State(initialValue: currentGender)
    }
    
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
                                        Text(setupContext == .initialSetup ? "Setup Profile" : "Edit Profile")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(setupContext == .initialSetup
                                             ? "Complete your profile"
                                             : "Update your profile information")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: setupContext == .initialSetup
                                          ? "person.badge.plus"
                                          : "pencil.circle.fill")
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
                                    Text(setupContext == .initialSetup ? "Complete Profile" : "Update Profile")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .disabled(!isProfileValid)
                            }
                            .padding(.vertical, 24)
                        }
                    }
                    .ignoresSafeArea()
                    .navigationBarHidden(true)
                }
            }
        }
    }
    
    private var isProfileValid: Bool {
        !name.isEmpty &&
        !(age.isEmpty || Int(age) == nil) &&
        !selectedGender.isEmpty
    }
    
    private func saveProfile() {
        guard let ageValue = Int(age) else {
            errorMessage = "Please enter a valid age"
            return
        }
        
        switch setupContext {
        case .initialSetup:
            authViewModel.completeInitialProfile(name: name, age: ageValue, gender: selectedGender) { result in
                handleSaveResult(result)
            }
        case .editing:
            authViewModel.updateProfile(name: name, age: ageValue, gender: selectedGender) { result in
                handleSaveResult(result)
            }
        }
    }
    
    private func handleSaveResult(_ result: Result<Void, Error>) {
        switch result {
        case .success():
            switch setupContext {
            case .initialSetup:
                authViewModel.shouldShowInitialProfileSetup = false
            case .editing:
                presentationMode.wrappedValue.dismiss()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    private func getSafeAreaTop() -> CGFloat {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window?.safeAreaInsets.top ?? 0
        }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview for new profile setup
            ProfileSetupView()
                .environmentObject(AuthViewModel())
            
            // Preview for profile editing
            ProfileSetupView(currentName: "John Doe", currentAge: 30, currentGender: "Male")
                .environmentObject(AuthViewModel())
        }
    }
}
