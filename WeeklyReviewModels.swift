// WeeklyReviewModels.swift
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct WeeklyReview: Identifiable, Codable {
    let id: UUID
    let weekStartDate: Date
    let weekEndDate: Date
    let moodSummary: MoodSummary
    let highlights: [MoodEntry]
    let photos: [String] // URLs of photos
    let notes: [String]
    var hasBeenViewed: Bool
    
    struct MoodSummary: Codable {
        let averageMood: Double
        let highestMood: Double
        let lowestMood: Double
        let bestDay: Date
        
        struct FactorImpactPair: Codable {
            let factor: String
            let impact: FactorImpact
        }
        
        let mostFrequentFactors: [FactorImpactPair]
        
        init(averageMood: Double, highestMood: Double, lowestMood: Double, mostFrequentFactors: [(factor: String, impact: FactorImpact)], bestDay: Date) {
            self.averageMood = averageMood
            self.highestMood = highestMood
            self.lowestMood = lowestMood
            self.bestDay = bestDay
            self.mostFrequentFactors = mostFrequentFactors.map { FactorImpactPair(factor: $0.factor, impact: $0.impact) }
        }
    }
}

class WeeklyReviewManager: ObservableObject {
    @Published var currentReview: WeeklyReview?
    @Published var showReview = false
    @Published var savedReviews: [WeeklyReview] = []
    private let db = Firestore.firestore()
    
    // Improved getDisplayableReviews function for WeeklyReviewManager
    // Replace the existing function with this in WeeklyReviewModels.swift

    func getDisplayableReviews() -> [WeeklyReview] {
        print("🔍 Getting displayable reviews - total count: \(savedReviews.count)")
        
        // If there are no reviews, return empty array
        if savedReviews.isEmpty {
            print("⚠️ No reviews available")
            return []
        }
        
        // Log all reviews to help debug
        for (index, review) in savedReviews.enumerated() {
            print("📊 Review \(index): ID=\(review.id)")
            print("    Start=\(review.weekStartDate)")
            print("    End=\(review.weekEndDate)")
            print("    Avg=\(review.moodSummary.averageMood)")
            print("    Highlights=\(review.highlights.count)")
        }
        
        // Sort reviews by date (newest first)
        let sortedReviews = savedReviews.sorted { $0.weekStartDate > $1.weekStartDate }
        print("📊 Sorted by date: \(sortedReviews.count) reviews")
        
        // Get unique reviews by week start date
        var uniqueReviews: [WeeklyReview] = []
        var seenDates: Set<String> = []
        
        // Create a formatter to get the date as string to use as a unique key
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for review in sortedReviews {
            let dateString = dateFormatter.string(from: review.weekStartDate)
            if !seenDates.contains(dateString) {
                seenDates.insert(dateString)
                uniqueReviews.append(review)
                print("✅ Added unique review for week starting \(dateString)")
            } else {
                print("⚠️ Skipping duplicate review for week starting \(dateString)")
            }
        }
        
        print("📊 After removing duplicates: \(uniqueReviews.count) unique reviews")
        
        return uniqueReviews
    }

    // This function helps diagnose issues with weekly review data
    func debugCheckReview(_ review: WeeklyReview) {
        print("🔬 DEBUG REVIEW: \(review.id)")
        print("   Date Range: \(review.weekStartDate) to \(review.weekEndDate)")
        print("   Avg Mood: \(review.moodSummary.averageMood)")
        print("   Highest: \(review.moodSummary.highestMood)")
        print("   Lowest: \(review.moodSummary.lowestMood)")
        print("   Best Day: \(review.moodSummary.bestDay)")
        print("   Factors: \(review.moodSummary.mostFrequentFactors.count)")
        print("   Highlights: \(review.highlights.count)")
        
        // Check for any potential issues
        if review.highlights.isEmpty {
            print("⚠️ WARNING: Review has no highlights")
        }
        
        if review.moodSummary.mostFrequentFactors.isEmpty {
            print("⚠️ WARNING: Review has no factors")
        }
        
        let calendar = Calendar.current
        let today = Date()
        let weeksSince = calendar.dateComponents([.weekOfYear], from: review.weekEndDate, to: today).weekOfYear ?? 0
        
        print("   Weeks since end date: \(weeksSince)")
        
        if weeksSince < 0 {
            print("⚠️ WARNING: Review end date is in the future")
        }
    }
    
    func checkAndGenerateWeeklyReview(entries: [MoodEntry]) {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's Sunday (weekday 1 in Calendar)
        guard calendar.component(.weekday, from: now) == 1 else {
            print("Not Sunday, skipping weekly review")
            return
        }
        
        // Get last week's date range
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let startOfLastWeek = calendar.startOfDay(for: weekAgo)
        let endOfLastWeek = calendar.startOfDay(for: now)
        
        // Check if a review for this week has already been created
        let existingReview = savedReviews.first { review in
            calendar.isDate(calendar.startOfDay(for: review.weekStartDate), inSameDayAs: startOfLastWeek)
        }
        
        if existingReview != nil {
            print("Weekly review for last week already exists, skipping generation")
            return
        }
        
        // Filter entries for last week
        let weekEntries = entries.filter { entry in
            entry.date >= startOfLastWeek && entry.date < endOfLastWeek
        }
        
        guard !weekEntries.isEmpty else {
            print("No entries for last week")
            return
        }
        
        // Calculate summary statistics
        let moodLevels = weekEntries.map { $0.moodLevel }
        let averageMood = moodLevels.reduce(0, +) / Double(moodLevels.count)
        let highestMood = moodLevels.max() ?? 0
        let lowestMood = moodLevels.min() ?? 0
        
        // Get most frequent factors
        var factorCounts: [String: (positive: Int, negative: Int)] = [:]
        for entry in weekEntries {
            for (factor, impact) in entry.factors {
                if factorCounts[factor] == nil {
                    factorCounts[factor] = (positive: 0, negative: 0)
                }
                if impact == .positive {
                    factorCounts[factor]!.positive += 1
                } else {
                    factorCounts[factor]!.negative += 1
                }
            }
        }
        
        let mostFrequent = factorCounts.map { factor, counts in
            (
                factor: factor,
                impact: counts.positive > counts.negative ? FactorImpact.positive : FactorImpact.negative
            )
        }
        .sorted { $0.factor < $1.factor }
        .prefix(3)
        
        // Find best day (highest mood)
        let bestDay = weekEntries.max { $0.moodLevel < $1.moodLevel }?.date ?? now
        
        // Create the weekly review
        let review = WeeklyReview(
            id: UUID(),
            weekStartDate: startOfLastWeek,
            weekEndDate: endOfLastWeek,
            moodSummary: WeeklyReview.MoodSummary(
                averageMood: averageMood,
                highestMood: highestMood,
                lowestMood: lowestMood,
                mostFrequentFactors: Array(mostFrequent),
                bestDay: bestDay
            ),
            highlights: selectHighlights(from: weekEntries),
            photos: weekEntries.compactMap { $0.photoURL },
            notes: weekEntries.map { $0.note }.filter { !$0.isEmpty },
            hasBeenViewed: false
        )
        
        // Save and show the review
        saveReview(review)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentReview = review
            self?.showReview = true
        }
    }
    
    private func selectHighlights(from entries: [MoodEntry]) -> [MoodEntry] {
        // Select entries with photos or substantial notes or high mood levels
        return entries.filter { entry in
            entry.photoURL != nil ||
            !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        }
    }
    
    func saveReview(_ review: WeeklyReview) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // First check if a review with the same week start date already exists
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: review.weekStartDate)
        
        // Check if a review for this week already exists locally
        let existingReview = savedReviews.first { existingReview in
            let existingStartDay = calendar.startOfDay(for: existingReview.weekStartDate)
            return calendar.isDate(existingStartDay, inSameDayAs: startOfDay)
        }
        
        // If a review for this week already exists, don't save again
        if existingReview != nil {
            print("Review for week starting \(startOfDay) already exists. Not saving duplicate.")
            return
        }
        
        // Save to Firestore
        do {
            try db.collection("users")
                .document(userId)
                .collection("weeklyReviews")
                .document(review.id.uuidString)
                .setData(from: review)
            
            DispatchQueue.main.async { [weak self] in
                // Before appending, double check it doesn't already exist
                if !(self?.savedReviews.contains(where: { $0.id == review.id }) ?? false) {
                    self?.savedReviews.append(review)
                    print("Saved new weekly review starting \(startOfDay)")
                }
            }
        } catch {
            print("Error saving weekly review: \(error)")
        }
    }
    

    
    func fetchSavedReviews() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        print("📊 Fetching weekly reviews from Firestore...")
        
        db.collection("users")
            .document(userId)
            .collection("weeklyReviews")
            .order(by: "weekStartDate", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching reviews: \(error)")
                    return
                }
                
                // Get reviews from Firestore
                var reviews = [WeeklyReview]()
                
                for document in snapshot?.documents ?? [] {
                    do {
                        let review = try document.data(as: WeeklyReview.self)
                        reviews.append(review)
                        print("✅ Successfully decoded review for week: \(review.weekStartDate)")
                    } catch {
                        print("❌ Error decoding review: \(error)")
                    }
                }
                
                // Filter out duplicates based on week start date
                let calendar = Calendar.current
                var uniqueReviews: [WeeklyReview] = []
                var seenDates: Set<String> = []
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                for review in reviews {
                    let dateString = dateFormatter.string(from: review.weekStartDate)
                    if !seenDates.contains(dateString) {
                        seenDates.insert(dateString)
                        uniqueReviews.append(review)
                    }
                }
                
                DispatchQueue.main.async {
                    print("📊 Fetched \(reviews.count) reviews, \(uniqueReviews.count) unique reviews")
                    self?.savedReviews = uniqueReviews
                }
            }
    }
    // Add this method to WeeklyReviewManager class in WeeklyReviewModels.swift

    // MARK: - Update Reviews After Entry Edit
    func updateReviewsAfterEntryEdit(editedEntry: MoodEntry) {
        print("🔄 Updating weekly reviews after entry edit")
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Find all reviews that might contain this entry
        let entryDate = editedEntry.date
        let calendar = Calendar.current
        
        // First, fetch all reviews to work with
        db.collection("users")
            .document(userId)
            .collection("weeklyReviews")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching reviews for update: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self, let documents = snapshot?.documents else { return }
                
                // Find reviews that include the edited entry's date
                var reviewsToUpdate: [WeeklyReview] = []
                
                for document in documents {
                    do {
                        let review = try document.data(as: WeeklyReview.self)
                        // Check if entry falls within this review's date range
                        if entryDate >= review.weekStartDate && entryDate < review.weekEndDate {
                            reviewsToUpdate.append(review)
                            print("📝 Found review to update: \(review.id), date range: \(review.weekStartDate) - \(review.weekEndDate)")
                        }
                    } catch {
                        print("❌ Error decoding review: \(error.localizedDescription)")
                    }
                }
                
                // For each review that needs updating
                for reviewToUpdate in reviewsToUpdate {
                    self.rebuildAndSaveReview(reviewToUpdate: reviewToUpdate)
                }
            }
    }

    // Helper method to rebuild and save a review with fresh data
    private func rebuildAndSaveReview(reviewToUpdate: WeeklyReview) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Fetch all entries for the week to recalculate everything
        let startDate = reviewToUpdate.weekStartDate
        let endDate = reviewToUpdate.weekEndDate
        
        print("🔄 Rebuilding review for week: \(startDate) - \(endDate)")
        
        // Query for all entries in the week
        db.collection("users")
            .document(userId)
            .collection("moodEntries")
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThan: endDate)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error fetching entries for review update: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self, let documents = snapshot?.documents else { return }
                
                var weekEntries: [MoodEntry] = []
                
                // Parse entries
                for document in documents {
                    do {
                        var entry = try document.data(as: MoodEntry.self)
                        entry.id = document.documentID
                        weekEntries.append(entry)
                    } catch {
                        print("❌ Error decoding entry: \(error.localizedDescription)")
                    }
                }
                
                // Skip if no entries
                guard !weekEntries.isEmpty else {
                    print("⚠️ No entries found for review period")
                    return
                }
                
                // Recalculate review data
                
                // 1. Calculate summary statistics
                let moodLevels = weekEntries.map { $0.moodLevel }
                let averageMood = moodLevels.reduce(0, +) / Double(moodLevels.count)
                let highestMood = moodLevels.max() ?? 0
                let lowestMood = moodLevels.min() ?? 0
                
                // 2. Find best day (highest mood)
                let bestDay = weekEntries.max { $0.moodLevel < $1.moodLevel }?.date ?? Date()
                
                // 3. Get most frequent factors
                var factorCounts: [String: (positive: Int, negative: Int)] = [:]
                
                for entry in weekEntries {
                    for (factor, impact) in entry.factors {
                        if factorCounts[factor] == nil {
                            factorCounts[factor] = (positive: 0, negative: 0)
                        }
                        
                        if impact == .positive {
                            factorCounts[factor]!.positive += 1
                        } else {
                            factorCounts[factor]!.negative += 1
                        }
                    }
                }
                
                let mostFrequent = factorCounts.map { factor, counts in
                    (
                        factor: factor,
                        impact: counts.positive > counts.negative ? FactorImpact.positive : FactorImpact.negative
                    )
                }
                .sorted { $0.factor < $1.factor }
                .prefix(3)
                
                // 4. Get highlights
                let highlights = self.selectHighlights(from: weekEntries)
                
                // 5. Get notes and photos
                let notes = weekEntries.map { $0.note }.filter { !$0.isEmpty }
                let photos = weekEntries.compactMap { $0.photoURL }
                
                // Create updated review
                let updatedReview = WeeklyReview(
                    id: reviewToUpdate.id,
                    weekStartDate: startDate,
                    weekEndDate: endDate,
                    moodSummary: WeeklyReview.MoodSummary(
                        averageMood: averageMood,
                        highestMood: highestMood,
                        lowestMood: lowestMood,
                        mostFrequentFactors: Array(mostFrequent),
                        bestDay: bestDay
                    ),
                    highlights: highlights,
                    photos: photos,
                    notes: notes,
                    hasBeenViewed: true // Mark as viewed since it's already been seen
                )
                
                // Save updated review
                do {
                    try self.db.collection("users")
                        .document(userId)
                        .collection("weeklyReviews")
                        .document(reviewToUpdate.id.uuidString)
                        .setData(from: updatedReview)
                    
                    // Update local cache
                    if let index = self.savedReviews.firstIndex(where: { $0.id == updatedReview.id }) {
                        self.savedReviews[index] = updatedReview
                        print("✅ Successfully updated review")
                    } else {
                        self.savedReviews.append(updatedReview)
                        print("✅ Added updated review to cache")
                    }
                } catch {
                    print("❌ Error saving updated review: \(error.localizedDescription)")
                }
            }
    }
}
