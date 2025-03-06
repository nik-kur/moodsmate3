import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private var validUnlockedCount: Int {
            viewModel.achievements.filter { achievement in
                viewModel.unlockedAchievements.contains(achievement.id)
            }.count
        }
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        if !networkMonitor.isConnected {
                    OfflineView()
        } else {
            ZStack {
                colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Achievements")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Track your progress")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "trophy.fill")
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
                        

                        // Progress Overview
                        HStack {
                            Text("\(validUnlockedCount)/\(viewModel.achievements.count) Unlocked")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                        
                        // Achievements Grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.achievements) { achievement in
                                AchievementCard(
                                    achievement: achievement,
                                    isUnlocked: viewModel.unlockedAchievements.contains(achievement.id)
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 90)
                }
                .ignoresSafeArea()
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

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @State private var showingCelebration = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.color.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: achievement.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(isUnlocked ? achievement.color : .gray)
                    .symbolEffect(.bounce, options: .repeating, value: showingCelebration)
                
                if isUnlocked {
                    Circle()
                        .stroke(achievement.color.opacity(0.2), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(showingCelebration ? 1.5 : 1)
                        .opacity(showingCelebration ? 0 : 1)
                        .animation(.easeOut(duration: 1), value: showingCelebration)
                }
            }
            .padding(.top, 16)
            
            Text(achievement.title)
                .font(.headline)
                .foregroundColor(isUnlocked ? .primary : .gray)
                .multilineTextAlignment(.center)
            
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(isUnlocked ? .secondary : .gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isUnlocked ? achievement.color : Color.gray.opacity(0.3), lineWidth: 2)
        )
        .opacity(isUnlocked ? 1 : 0.7)
        .id("\(achievement.id)-\(isUnlocked)") // Force view update when unlock status changes
        .onAppear {
            print("📱 Achievement Card appeared: \(achievement.title) (ID: \(achievement.id)) Unlocked: \(isUnlocked)")
            if isUnlocked {
                DispatchQueue.main.async {
                    showingCelebration = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingCelebration = false
                    }
                }
            }
        }
    }
}

#Preview {
    AchievementsView()
        .environmentObject(MoodTrackerViewModel())
}
