import SwiftUI
import Lottie

struct WelcomeView: View {
    @State private var currentPage = 0
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @Environment(\.colorScheme) var colorScheme
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    private let welcomePages = [
        WelcomePage(
            title: "Track Your Emotional Journey",
            description: "Understand yourself better by tracking daily moods and identifying what affects your wellbeing",
            animationName: "Animation - Notebook",
            accentColor: Color(red: 255/255, green: 215/255, blue: 0/255),
            size: WelcomePage.AnimationSize(height: 300, topPadding: 20, width: 300, bottomSpacing: 40)
        ),
        WelcomePage(
            title: "Discover Your Patterns",
            description: "Gain insights into what impacts your mood and learn to make positive changes",
            animationName: "Animation - Analytics",
            accentColor: Color(red: 98/255, green: 182/255, blue: 183/255),
            size: WelcomePage.AnimationSize(height: 300, topPadding: 20, width: 300, bottomSpacing: 40)
        ),
        WelcomePage(
            title: "Celebrate Progress",
            description: "Unlock achievements and watch your emotional awareness grow over time",
            animationName: "Animation - Trophy",
            accentColor: Color(red: 126/255, green: 188/255, blue: 137/255),
            size: WelcomePage.AnimationSize(height: 300, topPadding: 20, width: 300, bottomSpacing: 40)
        )
    ]
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Welcome to MoodMate")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Your journey to emotional wellness")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "heart.text.square.fill")
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
                    
                    VStack(spacing: 30) {
                        // Page Content
                        TabView(selection: $currentPage) {
                            ForEach(0..<welcomePages.count, id: \.self) { index in
                                WelcomePageView(page: welcomePages[index])
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 450)
                        .padding(.top, 20)
                        
                        // Page Indicators
                        HStack(spacing: 8) {
                            ForEach(0..<welcomePages.count, id: \.self) { index in
                                Circle()
                                    .fill(currentPage == index ? colors.secondary : colors.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(), value: currentPage)
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            Button {
                                print("Get Started button tapped")
                                withAnimation {
                                    hasSeenWelcome = true
                                }
                            } label: {
                                Text("Get Started")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(colors.secondary)
                                    .cornerRadius(16)
                            }
                            
                            Button {
                                print("Skip button tapped")
                                withAnimation {
                                    hasSeenWelcome = true
                                }
                            } label: {
                                Text("Skip")
                                    .font(.headline)
                                    .foregroundColor(colors.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            print("WelcomeView appeared, hasSeenWelcome: \(hasSeenWelcome)")
        }
        .onChange(of: hasSeenWelcome) { oldValue, newValue in
            print("🔴 hasSeenWelcome changed from \(oldValue) to: \(newValue)")
        }
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

struct LottieView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode
    
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: name)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: container.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: container.heightAnchor),
            animationView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct WelcomePage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let animationName: String
    let accentColor: Color
    let size: AnimationSize
    
    struct AnimationSize {
        let height: CGFloat
        let topPadding: CGFloat
        let width: CGFloat
        let bottomSpacing: CGFloat
    }
}

struct WelcomePageView: View {
    let page: WelcomePage
    
    var body: some View {
        VStack(spacing: page.size.bottomSpacing) {
            // Lottie Animation
            LottieView(name: page.animationName, loopMode: .loop)
                .frame(width: page.size.width, height: page.size.height)
                .padding(.top, page.size.topPadding)
                .frame(maxWidth: .infinity)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
        }
    }
}

// Note: cornerRadius and RoundedCorner are already defined elsewhere in your project

#Preview {
    WelcomeView()
}
