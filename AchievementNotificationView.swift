import SwiftUI

struct AchievementNotification: View {
    let achievement: Achievement
    @Binding var isPresented: Bool
    
    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack {
            HStack(spacing: 15) {
                // Trophy animation container
                ZStack {
                    Circle()
                        .fill(achievement.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(achievement.color)
                        .symbolEffect(.bounce, options: .repeating)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievement Unlocked!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(achievement.title)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismissNotification()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
                opacity = 1
            }
        }
    }
    
    private func dismissNotification() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            offset = 100
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isPresented = false
        }
    }
}
