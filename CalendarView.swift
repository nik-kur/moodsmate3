import SwiftUI
import FirebaseAuth

struct CalendarView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date?
    @State private var showingEntryDetail = false
    @State private var showingEditView = false
    @StateObject private var networkMonitor = NetworkMonitor()
    
    private let calendar = Calendar.current
    private let colors = (
        background: Color(UIColor.systemBackground),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(UIColor.secondarySystemBackground),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
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
                                    Text("Calendar")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Your mood journey")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "calendar")
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
                            // Month Navigation
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(colors.secondary)
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                
                                Spacer()
                                
                                Text(monthYearString(from: selectedMonth))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(colors.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(colors.secondary)
                                        .font(.system(size: 20, weight: .semibold))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            // Weekday Headers
                            HStack {
                                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                                    Text(day)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(colors.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Calendar Grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                ForEach(daysInMonth(), id: \.self) { date in
                                    if let date = date {
                                        DayCell(
                                            date: date,
                                            moodEntry: viewModel.getEntry(for: date),
                                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date())
                                        )
                                        .onTapGesture {
                                            let today = Calendar.current.startOfDay(for: Date())
                                            let tappedDay = Calendar.current.startOfDay(for: date)
                                            
                                            if tappedDay > today {
                                                return
                                            }
                                            
                                            selectedDate = date
                                            
                                            if let entry = viewModel.getEntry(for: tappedDay) {
                                                // ✅ Entry exists → Open DayEntryDetail
                                                showingEntryDetail = true
                                            } else {
                                                // ✅ No entry exists → Show Edit View for creating a new entry
                                                showingEditView = true
                                            }
                                        }
                                        
                                        
                                    } else {
                                        Color.clear
                                            .aspectRatio(1, contentMode: .fill)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        Divider()
                            .padding(.vertical)
                        
                        // Add Weekly Memories section
                        WeeklyMemoriesSection()
                            .environmentObject(viewModel)
                    }
                    .padding(.bottom, 90)
                }
                .ignoresSafeArea()
                .onAppear {
                    // This ensures that weekly reviews are fetched both when the view appears for the first time
                    // and when the user returns to this view from other tabs
                    DispatchQueue.main.async {
                        viewModel.weeklyReviewManager.fetchSavedReviews()
                        
                        // Also check if a weekly review should be generated - fix the method call here
                        viewModel.weeklyReviewManager.checkAndGenerateWeeklyReview(entries: viewModel.moodEntries)
                    }
                }
                .sheet(isPresented: $showingEntryDetail) {
                    if let selectedDate = selectedDate,
                       let entry = viewModel.getEntry(for: selectedDate) {
                        DayEntryDetail(entry: entry)
                    }
                }
                
                .sheet(isPresented: $showingEditView) {
                    if let selectedDate = selectedDate {
                        let newEntry = MoodEntry(
                            date: selectedDate,
                            moodLevel: 5.0, // Default mood level
                            factors: [:],
                            note: ""
                        )
                        EditDayEntryView(entry: newEntry)
                            .environmentObject(viewModel)
                    }
                }
            }
        }
    }
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        
        // Get weekday of the first day (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        var firstWeekday = calendar.component(.weekday, from: firstDay)
        
        // Convert to Monday-based (0 = Monday, 1 = Tuesday, ..., 6 = Sunday)
        firstWeekday = (firstWeekday + 5) % 7 // Transform from Sunday-based to Monday-based
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        let trailingSpaces = 7 - (days.count % 7)
        if trailingSpaces < 7 {
            days.append(contentsOf: Array(repeating: nil, count: trailingSpaces))
        }
        
        return days
    }
    
    private func getSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }
}

struct DayCell: View {
    let date: Date
    let moodEntry: MoodEntry?
    let isSelected: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            if let entry = moodEntry {
                Circle()
                    .fill(getMoodColor(for: entry.moodLevel))
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? .white : .clear, lineWidth: 2)
                    )
            }
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: moodEntry != nil ? .bold : .regular))
                .foregroundColor(moodEntry != nil ? .white : Color(UIColor.label))
        }
        .aspectRatio(1, contentMode: .fill)
        .frame(height: 45) // Add fixed height
                .frame(maxWidth: .infinity) // Ensure width fills space
    }
    
    private func getMoodColor(for level: Double) -> Color {
        // Match the colors from your mood levels
        switch level {
        case 8...10:
            return Color(red: 255/255, green: 215/255, blue: 0/255)
        case 6...8:
            return Color(red: 98/255, green: 182/255, blue: 183/255)
        case 4...6:
            return Color(red: 135/255, green: 206/255, blue: 235/255)
        case 2...4:
            return Color(red: 176/255, green: 196/255, blue: 222/255)
        default:
            return Color(red: 169/255, green: 169/255, blue: 169/255)
        }
    }
}




struct WeeklyMemoriesSection: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @State private var selectedReview: WeeklyReview?
    @State private var showingReview = false
    @State private var reviewsLoaded = false
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header without refresh button
            HStack {
                Text("Weekly Memories")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colors.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if !reviewsLoaded {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Spacer()
                }
            } else if viewModel.weeklyReviewManager.savedReviews.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.bottom, 8)
                        
                        Text("No weekly memories yet")
                            .font(.callout)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                        
                        Text("Continue tracking your moods to see weekly reviews")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                // Display review cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Get displayable reviews
                        let displayableReviews = viewModel.weeklyReviewManager.getDisplayableReviews()
                        
                        ForEach(displayableReviews) { review in
                            Button {
                                // Handle card tap with automatic refresh
                                handleCardTap(review)
                            } label: {
                                WeekMemoryCard(review: review)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingReview) {
            if let review = selectedReview {
                WeeklyReviewView(review: review, isPresented: $showingReview)
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            print("📅 WeeklyMemoriesSection appeared, fetching reviews...")
            
            // Reset state
            selectedReview = nil
            showingReview = false
            
            // Fetch reviews
            viewModel.weeklyReviewManager.fetchSavedReviews()
            
            // Set reviewsLoaded to true after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                reviewsLoaded = true
            }
        }
    }
    
    // Handle card tap with built-in refresh
    private func handleCardTap(_ review: WeeklyReview) {
        print("📝 Card tapped for review ID: \(review.id)")
        
        // Show loading indicator
        reviewsLoaded = false
        
        // Refresh data in background
        viewModel.weeklyReviewManager.fetchSavedReviews()
        
        // Wait for refresh to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Get fresh data if available
            if let updatedReview = viewModel.weeklyReviewManager.getDisplayableReviews().first(where: { $0.id == review.id }) {
                // Make a deep copy for safety
                let freshReview = deepCopyReview(updatedReview)
                selectedReview = freshReview
                
                // Debug the review to ensure it's valid
                viewModel.weeklyReviewManager.debugCheckReview(freshReview)
                
                print("📊 Using freshly loaded review data")
            } else {
                // Fallback to original review if not found
                selectedReview = review
                print("⚠️ Using original review data (refresh may have failed)")
            }
            
            // Show the review and restore UI
            reviewsLoaded = true
            showingReview = true
        }
    }
    
    // Helper function to create a deep copy of the review
    private func deepCopyReview(_ original: WeeklyReview) -> WeeklyReview {
        return WeeklyReview(
            id: original.id,
            weekStartDate: original.weekStartDate,
            weekEndDate: original.weekEndDate,
            moodSummary: original.moodSummary,
            highlights: original.highlights,
            photos: original.photos,
            notes: original.notes,
            hasBeenViewed: original.hasBeenViewed
        )
    }
}

// MARK: - Loading View

// MARK: - Loading View (Fixed Version)



// Note: Removed the duplicate View extension and RoundedCorner declarations
// since they are already declared earlier in the file


struct WeekMemoryCard: View {
    let review: WeeklyReview
    
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255)
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date range
            Text(dateRangeString(from: review.weekStartDate, to: review.weekEndDate))
                .font(.headline)
                .foregroundColor(colors.secondary)
            
            HStack {
                // Average mood
                VStack(alignment: .leading) {
                    Text(String(format: "%.1f", review.moodSummary.averageMood))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colors.secondary)
                    Text("Avg Mood")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Highlights count
                VStack(alignment: .trailing) {
                    Text("\(review.highlights.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(colors.secondary)
                    Text("Moments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // "Tap to view details" text
            Text("Tap to view details")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding()
        .frame(width: 200)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func dateRangeString(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
#Preview {
    CalendarView()
        .environmentObject(MoodTrackerViewModel())
}
