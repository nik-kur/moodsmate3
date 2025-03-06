import SwiftUI
import FirebaseAuth
import AuthenticationServices
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import CryptoKit


class AuthViewModel: NSObject, ObservableObject {
    @Published var isLoggedIn = false
    @Published var isProfileComplete = false
    @Published var shouldShowInitialProfileSetup = false
    @Published var shouldShowAccountDeletedMessage = false
    @Published var errorMessage: String?
    @Published var isAppleSignInUser = false

    private let networkMonitor = NetworkMonitor()
    
    // New properties for user profile
    @Published var currentUserName: String?
    @Published var currentUserAge: Int?
    @Published var currentUserGender: String?
    
    private let db = Firestore.firestore()
    private var currentNonce: String?
    
    override init() {
           super.init()
           checkAuthStatus()
       }
    
    
    func checkAuthStatus() {
        let isUserLoggedIn = Auth.auth().currentUser != nil
        
        if isUserLoggedIn {
            db.collection("users").document(Auth.auth().currentUser!.uid).getDocument { [weak self] (snapshot, error) in
                DispatchQueue.main.async {
                    self?.isLoggedIn = true
                    self?.isProfileComplete = true
                    self?.fetchCurrentUserProfile()
                    
                    if let providerData = Auth.auth().currentUser?.providerData.first {
                                        self?.isAppleSignInUser = (providerData.providerID == "apple.com")
                                    }
                }
            }
        } else {
            isLoggedIn = false
            isProfileComplete = false
            isAppleSignInUser = false 
        }
    }
    
    private func checkProfileStatus() {
        guard let currentUser = Auth.auth().currentUser else {
            isLoggedIn = false
            return
        }
        
        db.collection("users").document(currentUser.uid).getDocument { [weak self] (snapshot, error) in
            if let snapshot = snapshot, snapshot.exists {
                self?.isProfileComplete = true
                self?.fetchCurrentUserProfile()
            } else {
                self?.isProfileComplete = false
            }
        }
    }
    
    func fetchCurrentUserProfile() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        db.collection("users").document(currentUser.uid).getDocument { [weak self] (snapshot, error) in
            guard let data = snapshot?.data() else { return }
            
            self?.currentUserName = data["name"] as? String
            self?.currentUserAge = data["age"] as? Int
            self?.currentUserGender = data["gender"] as? String
        }
    }
    
    
    
    func login(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard networkMonitor.isConnected else {
            completion(.failure(AppError.networkError))
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result, error) in
            if let error = error {
                completion(.failure(AppError.authError(error.localizedDescription)))
                return
            }
            _ = KeychainManager.save(email: email, password: password)
            self?.checkAuthStatus()
            completion(.success(()))
        }
    }
    
    func register(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
       guard networkMonitor.isConnected else {
           completion(.failure(AppError.networkError))
           return
       }
       
       Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result, error) in
           if let error = error {
               completion(.failure(AppError.authError(error.localizedDescription)))
               return
           }
           
           guard let user = result?.user else {
               completion(.failure(AppError.authError("User creation failed")))
               return
           }
           
           var userData: [String: Any] = [
               "email": email,
               "createdAt": FieldValue.serverTimestamp(),
               "profileComplete": false
           ]
           
           if let savedAnswers = UserDefaults.standard.data(forKey: "questionnaireAnswers"),
              let answers = try? JSONDecoder().decode([String: String].self, from: savedAnswers) {
               userData["questionnaire"] = answers
           }
           
           self?.db.collection("users").document(user.uid).setData(userData) { error in
               if let error = error {
                   completion(.failure(AppError.dataError(error.localizedDescription)))
               } else {
                   self?.checkAuthStatus()
                   completion(.success(()))
               }
           }
       }
    }
    
    func googleSignIn(presentingViewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [unowned self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In failed"])))
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                self.checkAuthStatus()
                completion(.success(()))
            }
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    class ASAuthorizationControllerDelegate_Apple: NSObject, ASAuthorizationControllerDelegate {
        private let viewModel: AuthViewModel
        private let completion: (Result<Void, Error>) -> Void
        
        init(viewModel: AuthViewModel, completion: @escaping (Result<Void, Error>) -> Void) {
            self.viewModel = viewModel
            self.completion = completion
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            print("Apple Sign In authorization received")
            
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                
                // ✅ Fix: Ensure nonce is not nil before proceeding
                guard let nonce = viewModel.currentNonce else {
                    print("⚠️ Warning: Nonce is nil, Apple Sign-In may fail.")
                    return
                }
                
                // ✅ Fix: Ensure identityToken is retrieved correctly
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("⚠️ Warning: Failed to retrieve identity token from Apple.")
                    return
                }
                
                // ✅ Fix: Ensure token is converted properly
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("⚠️ Warning: Unable to convert Apple identity token to string.")
                    return
                }

                print("✅ Credential successfully created")
                
                let credential = OAuthProvider.credential(
                    providerID: AuthProviderID.apple,
                    idToken: idTokenString,
                    rawNonce: nonce
                )

                Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
                    if let error = error {
                        print("❌ Firebase Sign-In Error: \(error.localizedDescription)")
                        self?.viewModel.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let user = authResult?.user else {
                        print("❌ Error: No user found after Apple Sign-In.")
                        return
                    }
                    
                    let userDocRef = self?.viewModel.db.collection("users").document(user.uid)

                    userDocRef?.getDocument { (document, error) in
                        if let document = document, document.exists {
                            print("✅ User already exists. Skipping profile setup.")
                            DispatchQueue.main.async {
                                self?.viewModel.isLoggedIn = true
                                self?.viewModel.isProfileComplete = true  // ✅ Redirect to main view
                            }
                        } else {
                            print("🚀 Creating new user document for Apple Sign-In user.")
                            let userData: [String: Any] = [
                                "email": user.email ?? "Unknown",
                                "createdAt": FieldValue.serverTimestamp(),
                                "profileComplete": false
                            ]

                            userDocRef?.setData(userData) { error in
                                if let error = error {
                                    print("❌ Error creating user document: \(error.localizedDescription)")
                                } else {
                                    print("✅ New user detected, showing profile setup.")
                                    DispatchQueue.main.async {
                                        self?.viewModel.shouldShowInitialProfileSetup = true
                                    }
                                }
                            }
                        }
                    }
                }



            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("❌ Apple Sign-In failed: \(error.localizedDescription)")
            
            if let authError = error as? ASAuthorizationError {
                print("🔹 Authorization error code:", authError.code.rawValue)
            }
            
            viewModel.errorMessage = error.localizedDescription  // ✅ Fix: Ensure error is stored properly
        }

    }
    private var appleAuthDelegate: ASAuthorizationControllerDelegate_Apple?
    
    func appleSignIn(completion: @escaping (Result<Void, Error>) -> Void) {
        print("Starting Apple Sign In process")
        let nonce = randomNonceString()
        currentNonce = nonce  // Store nonce for later validation
        let hashedNonce = sha256(nonce)
        print("Generated nonce:", nonce)

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce  // Use hashed nonce

            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            appleAuthDelegate = ASAuthorizationControllerDelegate_Apple(viewModel: self, completion: completion)
            authorizationController.delegate = appleAuthDelegate
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    
    func saveQuestionnaireData(userId: String) {
        if let savedAnswers = UserDefaults.standard.data(forKey: "questionnaireAnswers"),
           let answers = try? JSONDecoder().decode([String: String].self, from: savedAnswers) {
            
            db.collection("users").document(userId).updateData([
                "questionnaire": answers
            ]) { error in
                if let error = error {
                    print("Error saving questionnaire data: \(error)")
                }
            }
        }
    }
    
    func completeInitialProfile(name: String, age: Int, gender: String, completion: @escaping (Result<Void, Error>) -> Void) {
       guard networkMonitor.isConnected else {
           completion(.failure(AppError.networkError))
           return
       }
       
       guard let currentUser = Auth.auth().currentUser else {
           completion(.failure(AppError.authError("No authenticated user")))
           return
       }

       var profileData: [String: Any] = [
           "name": name,
           "age": age,
           "gender": gender,
           "profileComplete": true,
           "createdAt": FieldValue.serverTimestamp()
       ]
       
       if let savedAnswers = UserDefaults.standard.data(forKey: "questionnaireAnswers"),
          let answers = try? JSONDecoder().decode([String: String].self, from: savedAnswers) {
           profileData["questionnaire"] = answers
       }

       let updateData: [String: Any] = [
           "name": name,
           "age": age,
           "gender": gender,
           "updatedAt": FieldValue.serverTimestamp()
       ]

       let userDocRef = db.collection("users").document(currentUser.uid)

       userDocRef.getDocument { [weak self] (document, error) in
           if let document = document, document.exists {
               userDocRef.updateData(updateData) { error in
                   if let error = error {
                       completion(.failure(AppError.dataError(error.localizedDescription)))
                   } else {
                       DispatchQueue.main.async {
                           self?.currentUserName = name
                           self?.currentUserAge = age
                           self?.currentUserGender = gender
                           self?.isProfileComplete = true
                           self?.isLoggedIn = true
                           print("✅ Profile updated. Redirecting to main view.")
                       }
                       completion(.success(()))
                   }
               }
           } else {
               userDocRef.setData(profileData) { error in
                   if let error = error {
                       completion(.failure(AppError.dataError(error.localizedDescription)))
                   } else {
                       DispatchQueue.main.async {
                           self?.currentUserName = name
                           self?.currentUserAge = age
                           self?.currentUserGender = gender
                           self?.isProfileComplete = true
                           self?.isLoggedIn = true
                           print("✅ Profile created. Redirecting to main view.")
                       }
                       completion(.success(()))
                   }
               }
           }
       }
    }


    // In AuthViewModel
    func updateProfile(name: String, age: Int, gender: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard networkMonitor.isConnected else {
            completion(.failure(AppError.networkError))
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(AppError.authError("No authenticated user")))
            return
        }
        
        let updateData: [String: Any] = [
            "name": name,
            "age": age,
            "gender": gender,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(currentUser.uid).updateData(updateData) { [weak self] error in
            if let error = error {
                completion(.failure(AppError.dataError(error.localizedDescription)))
            } else {
                DispatchQueue.main.async {
                    self?.currentUserName = name
                    self?.currentUserAge = age
                    self?.currentUserGender = gender
                }
                completion(.success(()))
            }
        }
    }
    func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
            isProfileComplete = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
    func biometricLogin() {
        guard let currentUser = Auth.auth().currentUser,
              let email = currentUser.email,
              let storedPassword = KeychainManager.retrieve(email: email) else {
            return
        }
        
        login(email: email, password: storedPassword) { result in
            switch result {
            case .success():
                // Login successful
                break
            case .failure(let error):
                print("Biometric login failed: \(error.localizedDescription)")
            }
        }
    }
}
// At the very bottom of the file, after the class closing brace
extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
