import SwiftUI

struct InfoPopup: View {
    let description: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Got it") {
                isPresented = false
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(red: 147/255, green: 112/255, blue: 219/255))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(.horizontal, 40)
    }
}

struct HomeView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel

    @State private var showImagePicker = false
       @State private var selectedUIImage: UIImage? = nil
    @State private var dragOffset: [String: CGFloat] = [:]
    @State private var isShowingNote = false
    @State private var selectedInfoFactor: String? = nil
    @State private var showingFactorInfo = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let colors = (
        background: Color(UIColor.systemBackground),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(UIColor.secondarySystemBackground),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255),
        euphoric: Color(red: 255/255, green: 215/255, blue: 0/255),
        good: Color(red: 98/255, green: 182/255, blue: 183/255),
        neutral: Color(red: 135/255, green: 206/255, blue: 235/255),
        down: Color(red: 176/255, green: 196/255, blue: 222/255),
        depressed: Color(red: 169/255, green: 169/255, blue: 169/255),
        text: Color(UIColor.label),
        textSecondary: Color(UIColor.secondaryLabel)
    )
    
    private let factors = [
        MoodFactorInfo(name: "Work", icon: "briefcase", description: "Work-related experiences such as meetings, deadlines, achievements, or challenges. Swipe left if work positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Exercise", icon: "figure.run", description: "Physical activities, workouts, sports, or any form of exercise. Swipe left if exercise positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Weather", icon: "cloud.sun", description: "The day's weather conditions and how they made you feel. Swipe left if weather positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Sleep", icon: "bed.double", description: "Your sleep quality and quantity from the previous night. Swipe left if sleep positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Social", icon: "person.2", description: "Interactions with friends, family, colleagues, or social events. Swipe left if social interactions positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Food", icon: "fork.knife", description: "Your eating patterns, meals, or any food-related experiences. Swipe left if food-related experiences positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "Health", icon: "heart", description: "Your physical and mental well-being, including any health-related events. Swipe left if health positively affected your mood today, right if negatively."),
        MoodFactorInfo(name: "News", icon: "newspaper", description: "News events, media consumption, or current events that affected you. Swipe left if news positively affected your mood today, right if negatively.")
    ]
    
    private let moodLevels: [(range: ClosedRange<Double>, mood: (name: String, icon: String, description: String, color: Color))] = [
        (0...2, ("Depressed", "cloud.rain.fill", "Feeling very low and overwhelmed", Color(red: 169/255, green: 169/255, blue: 169/255))),
        (2...4, ("Down", "cloud.fill", "Having a rough time", Color(red: 176/255, green: 196/255, blue: 222/255))),
        (4...6, ("Neutral", "cloud.sun.fill", "Neither high nor low", Color(red: 135/255, green: 206/255, blue: 235/255))),
        (6...8, ("Good", "sun.and.horizon.fill", "Feeling positive and upbeat", Color(red: 98/255, green: 182/255, blue: 183/255))),
        (8...10, ("Euphoric", "sun.max.fill", "On top of the world!", Color(red: 255/255, green: 215/255, blue: 0/255)))
    ]
    
    private var currentMood: (name: String, icon: String, description: String, color: Color) {
        let level = viewModel.moodLevel
        return moodLevels.first { $0.range.contains(level) }?.mood ??
               ("Neutral", "cloud.sun.fill", "Neither high nor low", colors.neutral)
    }
    
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
                                        Text("Mood Journal")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("How are you feeling today?")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: currentMood.icon)
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
                            
                            VStack(spacing: 32) {
                                // Mood Level Section
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Your Mood")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colors.secondary)
                                        Spacer()
                                        Image(systemName: "sparkles")
                                            .foregroundColor(colors.secondary)
                                            .font(.system(size: 20))
                                    }
                                    .padding(.horizontal)
                                    
                                    // Current Mood Display
                                    VStack(spacing: 12) {
                                        Image(systemName: currentMood.icon)
                                            .font(.system(size: 48))
                                            .foregroundColor(currentMood.color)
                                            .padding(.top, 8)
                                        
                                        VStack(spacing: 6) {
                                            Text(currentMood.name)
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(currentMood.color)
                                            
                                            Text(currentMood.description)
                                                .font(.system(size: 16))
                                                .foregroundColor(colors.textSecondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity)
                                    .background(colors.buttonBackground)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                                    .padding(.horizontal)
                                    
                                    // Mood Slider
                                    // Update in HomeView.swift - Slider Section
                                    VStack(spacing: 10) {
                                        Slider(value: $viewModel.moodLevel, in: 0...10, step: 0.5)
                                            .tint(currentMood.color)
                                            .padding(.horizontal)
                                            
                                        HStack {
                                            Text("0")  // Changed from "1" to "0"
                                                .font(.system(size: 15))
                                                .foregroundColor(colors.textSecondary)
                                            Spacer()
                                            Text(String(format: "%.1f", viewModel.moodLevel))
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundColor(currentMood.color)
                                            Spacer()
                                            Text("10")
                                                .font(.system(size: 15))
                                                .foregroundColor(colors.textSecondary)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Factors Section
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("What influenced your mood?")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colors.secondary)
                                        Spacer()
                                        Image(systemName: "list.bullet.clipboard")
                                            .foregroundColor(colors.secondary)
                                            .font(.system(size: 20))
                                    }
                                    .padding(.horizontal)
                                    
                                    Text("Swipe factors left for positive influence, right for negative")
                                        .font(.system(size: 15, weight: .regular))
                                        .italic()
                                        .foregroundColor(colors.textSecondary)
                                        .padding(.horizontal)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: 16),
                                        GridItem(.flexible(), spacing: 16)
                                    ], spacing: 16) {
                                        ForEach(factors) { factor in
                                            factorButton(factor: factor)
                                        }
                                    }
                               
                                    .padding(.horizontal)
                                }
                                
                                // Note Section
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Add a Note")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colors.secondary)
                                        Spacer()
                                        Image(systemName: "note.text")
                                            .foregroundColor(colors.secondary)
                                            .font(.system(size: 20))
                                    }
                                    .padding(.horizontal)
                                    
                                    TextEditor(text: $viewModel.noteText)
                                        .frame(height: 100)
                                        .padding()
                                        .background(colors.buttonBackground)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(colors.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                }
                        
                                if let _ = selectedUIImage {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Photo attached")
                                            .font(.system(size: 16))
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("No photo attached yet")
                                        .foregroundColor(.secondary)
                                }

                                            
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    Text("Attach Photo")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)

                                            .padding(.top, 8)
                                // Save Button
                                Button(action: {
                                    viewModel.saveMood(with: selectedUIImage)
                                }) {
                                    Text("Save Entry")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(colors.secondary)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                            
                            }
                            .padding(.vertical, 24)
                        }
                        .dismissKeyboardOnTap() 
                        .padding(.bottom, 90)
                    }
                    .ignoresSafeArea()
                    .sheet(isPresented: $showImagePicker) {
                        ImagePicker(image: $selectedUIImage)
                    }

                    if showingFactorInfo, let selectedFactor = selectedInfoFactor,
                                   let factorInfo = factors.first(where: { $0.name == selectedFactor }) {
                                    Color.black.opacity(0.4)
                                        .ignoresSafeArea()
                                        .onTapGesture {
                                            showingFactorInfo = false
                                        }
                                    
                                    InfoPopup(
                                        description: factorInfo.description,
                                        isPresented: $showingFactorInfo
                                    )
                                }
                            }
                .onChange(of: viewModel.moodEntries.count) { oldCount, newCount in
                    print("Changed from \(oldCount) to \(newCount)")
                    selectedUIImage = nil
                }


                            .alert("Entry Already Exists", isPresented: $viewModel.showDuplicateEntryAlert) {
                                Button("Cancel", role: .cancel) {
                                    // Keep the original entry
                                    viewModel.pendingMoodEntry = nil
                                }
                                
                                Button("Replace", role: .destructive) {
                                    // Replace today's entry with the new one
                                    viewModel.confirmSaveExistingDayMood()
                                }
                            } message: {
                                Text("You've already logged your mood today. Do you want to replace the existing entry?")
                            }
                        }
                    }
    
    
    private func factorButton(factor: MoodFactorInfo) -> some View {
        let impact = viewModel.getFactorImpact(factor.name)
        let offset = dragOffset[factor.name] ?? 0
        
        return VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(colors.positive)
                    .opacity(offset < 0 ? 1 : 0)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: factor.icon)
                        .font(.system(size: 20))
                        .foregroundColor(impact == nil ? colors.secondary : .white)
                        .frame(width: 30, height: 30)
                    
                    Text(factor.name)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(colors.negative)
                    .opacity(offset > 0 ? 1 : 0)
            }
            .frame(height: 72)
            .foregroundColor(impact == nil ? colors.text : .white)
            .background(
                Group {
                    switch impact {
                    case .positive:
                        colors.positive
                    case .negative:
                        colors.negative
                    case nil:
                        colors.buttonBackground
                    }
                }
            )
            .overlay(
                Button {
                    selectedInfoFactor = factor.name
                    showingFactorInfo = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(impact == nil ? colors.secondary.opacity(0.5) : .white.opacity(0.7))
                }
                .padding(8),
                alignment: .topTrailing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(impact == nil ? colors.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset[factor.name] = gesture.translation.width
                }
                .onEnded { gesture in
                    let offset = gesture.translation.width
                    if abs(offset) > 50 {
                        viewModel.toggleFactor(factor.name, impact: offset < 0 ? .positive : .negative)
                    }
                    dragOffset[factor.name] = 0
                }
        )
    }
    
    private func getSafeAreaTop() -> CGFloat {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window?.safeAreaInsets.top ?? 0
        }
    }

    extension View {
        func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
            clipShape(RoundedCorner(radius: radius, corners: corners))
        }
    }

    struct RoundedCorner: Shape {
        var radius: CGFloat = .infinity
        var corners: UIRectCorner = .allCorners

        func path(in rect: CGRect) -> Path {
            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            return Path(path.cgPath)
        }
    }

    #Preview {
        HomeView()
            .environmentObject(MoodTrackerViewModel())
    }
extension View {
    func dismissKeyboardOnTap() -> some View {
        return self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
