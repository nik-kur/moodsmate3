//
//  WeeklyReviewView.swift - IMPROVED VERSION

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// Updated sections for WeeklyReviewView.swift

struct WeeklyReviewView: View {
    let review: WeeklyReview
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var viewReady = false
    @State private var contentLoaded = false
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    colors.background.ignoresSafeArea()
                    
                    // Loading indicator shown until content is ready
                    if !contentLoaded {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading review...")
                                .padding(.top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Main Content
                    if viewReady {
                        VStack(spacing: 0) {
                            // Header with purple background
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Week in Review")
                                            .font(.system(size: 34, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(dateRangeString(from: review.weekStartDate, to: review.weekEndDate))
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, getSafeAreaTop())
                            .padding(.bottom, 24)
                            .background(
                                colors.secondary
                                    .edgesIgnoringSafeArea(.top)
                                    .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                            )
                            
                            // Page Indicators
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .fill(currentPage == index ? colors.secondary : colors.secondary.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.vertical)
                            
                            // Swipe hint (only shown on first page)
                     
                            
                            // Main Content
                            if contentLoaded {
                                TabView(selection: $currentPage) {
                                    // Page 1: Mood Overview
                                    MoodOverviewPage(review: review)
                                        .tag(0)
                                    
                                    // Page 2: Factors Analysis
                                    FactorsAnalysisPage(review: review)
                                        .tag(1)
                                    
                                    // Page 3: Moments
                                    MomentsPage(review: review, isPresented: $isPresented)
                                        .environmentObject(viewModel)
                                        .tag(2)
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                            } else {
                                // Placeholder while content loads
                                Spacer()
                            }
                            
                            Spacer()
                        }
                        .edgesIgnoringSafeArea(.top)
                        .opacity(contentLoaded ? 1 : 0)
                        .animation(.easeIn(duration: 0.3), value: contentLoaded)
                    }
                }
                .onAppear {
                    print("📱 WeeklyReviewView appeared with review ID: \(review.id)")
                    print("📱 Review period: \(dateRangeString(from: review.weekStartDate, to: review.weekEndDate))")
                    print("📱 Highlights count: \(review.highlights.count)")
                    print("📱 Avg mood: \(review.moodSummary.averageMood)")
                    
                    // Load view in stages to ensure proper initialization
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // First mark the view as ready to build structure
                        viewReady = true
                        
                        // Then after another delay, mark content as loaded for display
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            contentLoaded = true
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
        }
    }
    
    private func dateRangeString(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Consistent Section Header Component
// MARK: - Fixed SectionHeader Component

struct SectionHeader: View {
    let title: String
    let icon: String
    
    // Fixed: Use individual color property instead of single-element labeled tuple
    private let secondaryColor = Color(red: 147/255, green: 112/255, blue: 219/255)
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(secondaryColor)
            
            Spacer()
            
            Image(systemName: icon)
                .foregroundColor(secondaryColor)
                .font(.system(size: 20))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - MoodOverviewPage with Horizontal Cards

struct MoodOverviewPage: View {
    let review: WeeklyReview
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Consistent section header
            SectionHeader(title: "Mood Overview", icon: "chart.bar.fill")
            
            // Vertical stack of horizontal cards
            VStack(spacing: 12) {
                HorizontalMoodStatCard(
                    title: "Average Mood",
                    value: review.moodSummary.averageMood,
                    icon: "chart.bar.fill",
                    color: getMoodColor(review.moodSummary.averageMood)
                )
                
                HorizontalMoodStatCard(
                    title: "Highest Mood",
                    value: review.moodSummary.highestMood,
                    icon: "sun.max.fill",
                    color: .yellow
                )
                
                HorizontalMoodStatCard(
                    title: "Lowest Mood",
                    value: review.moodSummary.lowestMood,
                    icon: "cloud.fill",
                    color: .gray
                )
                
                HorizontalMoodStatCard(
                    title: "Best Day",
                    subtitle: formattedDate(review.moodSummary.bestDay),
                    icon: "star.fill",
                    color: colors.secondary
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Swipe instruction at bottom (kept only here, removed from top)
            HStack {
                Image(systemName: "hand.draw")
                Text("Swipe left to see more")
                Image(systemName: "arrow.right")
            }
            .foregroundColor(colors.secondary)
            .font(.system(size: 15))
            .padding(.bottom, 20)
        }
        .padding(.top)
    }
    
    private func getMoodColor(_ value: Double) -> Color {
        switch value {
        case 8...10: return .yellow    // Euphoric
        case 6...8: return .green     // Good
        case 4...6: return .blue      // Neutral
        case 2...4: return .orange    // Down
        default: return .gray         // Depressed
        }
    }
}

// MARK: - Horizontal Mood Stat Card

struct HorizontalMoodStatCard: View {
    let title: String
    var value: Double? = nil
    var subtitle: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // Right side - Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                if let value = value {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Enhanced FactorsAnalysisPage

struct FactorsAnalysisPage: View {
    let review: WeeklyReview
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
    // Computed property to aggregate factor counts
    private var factorCounts: [(factor: String, positive: Int, negative: Int)] {
        var counts: [String: (positive: Int, negative: Int)] = [:]
        
        // Process all factors from highlights
        for entry in review.highlights {
            for (factor, impact) in entry.factors {
                if counts[factor] == nil {
                    counts[factor] = (positive: 0, negative: 0)
                }
                
                if impact == .positive {
                    counts[factor]!.positive += 1
                } else {
                    counts[factor]!.negative += 1
                }
            }
        }
        
        // Convert to array sorted by total occurrences
        return counts.map { (factor: $0.key, positive: $0.value.positive, negative: $0.value.negative) }
            .sorted { ($0.positive + $0.negative) > ($1.positive + $1.negative) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Consistent section header
                SectionHeader(title: "Mood Factors", icon: "list.bullet.rectangle")
                
                if factorCounts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding()
                        
                        Text("No factor data available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Factors will appear here when you record more entries with mood factors.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // VStack to control consistent padding
                    VStack(spacing: 12) {
                        ForEach(factorCounts, id: \.factor) { item in
                            FactorSummaryCard(
                                factor: item.factor,
                                positive: item.positive,
                                negative: item.negative,
                                colors: colors
                            )
                        }
                    }
                    .padding(.horizontal) // Consistent padding with other views
                }
            }
            .padding(.top)
        }
    }
}

// MARK: - Factor Summary Card

// MARK: - Fixed Factor Summary Card

struct FactorSummaryCard: View {
    let factor: String
    let positive: Int
    let negative: Int
    let colors: (
        background: Color,
        secondary: Color,
        buttonBackground: Color,
        positive: Color,
        negative: Color
    )
    
    var totalCount: Int {
        positive + negative
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with factor name and count
            HStack {
                Text(factor)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(totalCount) times")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Summary counts
            HStack(spacing: 12) {
                // Positive count
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(colors.positive)
                    
                    Text("\(positive) positive")
                        .font(.subheadline)
                        .foregroundColor(colors.positive)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(colors.positive.opacity(0.1))
                .cornerRadius(8)
                
                // Negative count
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(colors.negative)
                    
                    Text("\(negative) negative")
                        .font(.subheadline)
                        .foregroundColor(colors.negative)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(colors.negative.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            
            // Visual bar - FIX: Compute widths separately to avoid tuple access in complex expression
            let availableWidth = UIScreen.main.bounds.width - 80 // Adjusted to account for the full padding
            let positiveWidth = totalCount > 0 ? CGFloat(positive) / CGFloat(totalCount) * availableWidth : 0
            let negativeWidth = totalCount > 0 ? CGFloat(negative) / CGFloat(totalCount) * availableWidth : 0
            
            HStack(spacing: 0) {
                // Positive bar
                Rectangle()
                    .fill(colors.positive)
                    .frame(width: positiveWidth, height: 8)
                
                // Negative bar
                Rectangle()
                    .fill(colors.negative)
                    .frame(width: negativeWidth, height: 8)
            }
            .cornerRadius(4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        // Removed individual horizontal padding here since it's applied at the parent level
    }
}

// MARK: - MomentsPage with Consistent Header

struct MomentsPage: View {
    let review: WeeklyReview
    @Binding var isPresented: Bool
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Consistent section header
                SectionHeader(title: "Special Moments", icon: "photo.on.rectangle.angled")
                
                if review.highlights.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.bottom, 8)
                        
                        Text("No special moments found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Your highlights will appear here when you add photos, detailed notes, or record especially good days.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(review.highlights) { entry in
                        ImprovedMomentCard(entry: entry)
                    }
                }
                
                // Save to Memories Button
                Button(action: {
                    viewModel.weeklyReviewManager.saveReview(review)
                    isPresented = false
                }) {
                    Text("Save to Memories")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colors.secondary)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .padding(.top)
        }
    }
}

// MARK: - Improved MomentCard (unchanged)
// MARK: - Improved MomentCard with Consistent Sizing
struct ImprovedMomentCard: View {
    let entry: MoodEntry
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header
            Text(formattedDayAndDate(entry.date))
                .font(.headline)
                .foregroundColor(colors.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
            
            // Photo if exists - full size
            if let photoURL = entry.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 300)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Note - with consistent padding regardless of photo
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.body)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, 12) // Add bottom padding consistently
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        // Force cards to have the same width by filling the horizontal space
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
    
    private func formattedDayAndDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
