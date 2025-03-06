import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseInAppMessaging
import GoogleSignIn
import FirebaseAnalytics
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Make sure Firebase is only configured once
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Add error handling for Google Sign-In configuration
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        // Register for remote notifications
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        application.registerForRemoteNotifications()
        
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
                   // App was launched from a push notification
                   PushNotificationHandler.shared.handleAppLaunchFromNotification(userInfo: userInfo)
               }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // Here you would send this token to your server if using a custom notification service
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // Handle the notification
        PushNotificationHandler.shared.handleAppLaunchFromNotification(userInfo: userInfo)
        
        // Complete the background fetch
        completionHandler(.newData)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Check for any pending weekly reviews from previous app launches
        PushNotificationHandler.shared.checkForPendingReviewOnLaunch()
    }
}

@main
struct MoodTrackerApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasCompletedQuestionnaire") private var hasCompletedQuestionnaire = false
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenWelcome {
                    WelcomeView()
                        .transition(.opacity)
                        .zIndex(1)
                } else if !hasCompletedQuestionnaire {
                    QuestionnaireView(showQuestionnaire: $hasCompletedQuestionnaire)
                        .transition(.opacity)
                        .zIndex(0)
                } else {
                    NavigationView {
                        Group {
                            if !authViewModel.isLoggedIn {
                                AuthenticationView()
                            } else if authViewModel.shouldShowInitialProfileSetup {
                                InitialProfileSetupView()
                            } else if authViewModel.isProfileComplete {
                                MainView()
                            } else {
                                ProfileView()
                            }
                        }
                        .fullScreenCover(isPresented: $authViewModel.shouldShowAccountDeletedMessage) {
                            AccountDeletedView()
                        }
                    }
                    .environmentObject(authViewModel)
                    .transition(.opacity)
                    .zIndex(0)
                }
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Add this if there's a NavigationView
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Add this
            .fixIPadLayout() // Add this
            .animation(.easeInOut(duration: 0.3), value: hasSeenWelcome)
            .animation(.easeInOut(duration: 0.3), value: hasCompletedQuestionnaire)
    
            .onAppear {
                // Force fullscreen mode on iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
                    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.forEach { windowScene in
                        windowScene.activationConditions.prefersToActivateForTargetContentIdentifierPredicate =
                            NSPredicate(value: false)
                    }
                }
            }
            .onAppear {
                            
            }
        }
    }
}
