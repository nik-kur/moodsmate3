import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage


struct MoodEntry: Codable, Identifiable {
    var id: String?
    let date: Date
    let moodLevel: Double
    let factors: [String: FactorImpact]
    let note: String
    let photoURL: String? // Points to a Firebase Storage download URL if user uploaded a photo
    
    init(
        id: String? = nil,
        date: Date,
        moodLevel: Double,
        factors: [String: FactorImpact],
        note: String,
        photoURL: String? = nil
    ) {
        self.id = id
        self.date = date
        self.moodLevel = moodLevel
        self.factors = factors
        self.note = note
        self.photoURL = photoURL
    }
    
    // Add CodingKeys to handle the custom FactorImpact enum
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case moodLevel
        case factors
        case note
        case photoURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        moodLevel = try container.decode(Double.self, forKey: .moodLevel)
        note = try container.decode(String.self, forKey: .note)
        
        // Custom decoding for factors to handle FactorImpact enum
        let factorsDict = try container.decode([String: String].self, forKey: .factors)
        factors = factorsDict.mapValues { FactorImpact(rawValue: $0) ?? .positive }
        // ✅ Initialize photoURL
            photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(moodLevel, forKey: .moodLevel)
        try container.encode(note, forKey: .note)
        try container.encode(photoURL, forKey: .photoURL)
        // Custom encoding for factors
        let factorsDict = factors.mapValues { $0.rawValue }
        try container.encode(factorsDict, forKey: .factors)
    }
}

// Analytics data structures
struct MoodTrendEntry: Identifiable {
    let id = UUID()
    let date: Date
    let moodLevel: Double
}

struct FactorImpactEntry: Identifiable {
    let id = UUID()
    let name: String
    let impact: Double
}

struct WeeklyAverageEntry: Identifiable {
    let id = UUID()
    let week: String
    let average: Double
}

final class MoodTrackerViewModel: ObservableObject {
   
    // Published properties for UI
    @Published var moodLevel: Double = 5.0
    @Published var currentScreen: AppScreen = .home
    @Published var selectedFactors: [String: FactorImpact] = [:]
    @Published var noteText: String = ""
    @Published var showingAchievementNotification = false
    @Published var lastUnlockedAchievement: Achievement?
    @Published var showDuplicateEntryAlert = false
    @Published var pendingMoodEntry: MoodEntry?
    @Published var currentWeeklyReview: WeeklyReview?
        @Published var showWeeklyReview = false
   
    public let weeklyReviewManager: WeeklyReviewManager
       
    init() {
        self.weeklyReviewManager = WeeklyReviewManager()
        
        // Add observer for weeklyReviewManager's properties
        weeklyReviewManager.$currentReview
            .assign(to: &$currentWeeklyReview)
        
        weeklyReviewManager.$showReview
            .assign(to: &$showWeeklyReview)
        
        // Setup achievements
        setupAchievements()
        
        // Try to load achievements from UserDefaults first
        loadAchievementsFromUserDefaults()
        
        // Load achievements from Firebase
        if Auth.auth().currentUser != nil {
            loadAchievementsFromFirebase()
        }
        
        // Only setup mock data if no user is logged in
        if Auth.auth().currentUser == nil {
            setupMockData()
        }
        
        // Debug print achievement state
        debugPrintAchievements()
        
        // Fetch real entries if user is logged in
        if Auth.auth().currentUser != nil {
            fetchMoodEntries()
        }
        
        // IMPORTANT: Remove the checkAchievements() call from here!
        // We'll only check achievements after entries are loaded
    }
    
    
    
    // Achievement tracking
    @Published var unlockedAchievements: Set<UUID> = []


    @Published var achievements: [Achievement] = []
    
    // Data storage
    @Published private(set) var moodEntries: [MoodEntry] = []
    private var streakCount: Int = 0
    private var usedFactors: Set<String> = []
    
    @Published var errorMessage: String?
    @Published var showError = false
    private let networkMonitor = NetworkMonitor()
    
    // Firestore reference
    private let db = Firestore.firestore()
    private var achievementsKey: String {
        if let userId = Auth.auth().currentUser?.uid {
            return "unlockedAchievements_\(userId)"
        } else {
            // For users not logged in
            return "unlockedAchievements_guest"
        }
    }

    
    
    
    // MARK: - Firestore Data Management
    
    private func saveAchievementsToUserDefaults() {
        print("📝 Saving achievements to UserDefaults")
        let achievementIDs = unlockedAchievements.map { $0.uuidString }
        UserDefaults.standard.set(achievementIDs, forKey: self.achievementsKey)
        print("Saved \(achievementIDs.count) achievement IDs")
    }
        
    private func loadAchievementsFromUserDefaults() {
        print("📖 Loading achievements from UserDefaults")
        if let storedAchievements = UserDefaults.standard.array(forKey: self.achievementsKey) as? [String] {
            print("Found \(storedAchievements.count) stored achievements")
            let restoredAchievements = Set(storedAchievements.compactMap { UUID(uuidString: $0) })
            
            DispatchQueue.main.async { [weak self] in
                self?.unlockedAchievements = restoredAchievements
                self?.objectWillChange.send()
            }
        } else {
            print("No stored achievements found in UserDefaults")
        }
    }

    struct AchievementState: Codable {
        let achievementId: String
        let unlockedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case achievementId = "id"
            case unlockedAt = "timestamp"
        }
    }
    
    // Save unlocked achievements to Firestore
    private func saveAchievementsToFirebase() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            // Convert unlockedAchievements to an array of achievement type raw values
            let unlockedTypes = unlockedAchievements.compactMap { id in
                achievements.first(where: { $0.id == id })?.type.rawValue
            }
            
            // Store the achievement type raw values
            let data: [String: Any] = [
                "unlockedAchievementTypes": unlockedTypes
            ]
            
            print("🔥 Saving achievement types to Firebase: \(unlockedTypes)")
            
            db.collection("users").document(userId).setData(data, merge: true) { [weak self] error in
                if let error = error {
                    print("❌ Error saving achievements: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully saved \(unlockedTypes.count) achievements to Firebase")
                    self?.debugPrintAchievements()
                }
            }
        }

        func loadAchievementsFromFirebase() {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            print("📥 Starting Firebase achievements load")
            
            db.collection("users").document(userId).getDocument { [weak self] document, error in
                if let error = error {
                    print("❌ Error fetching achievements: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self else { return }
                
                if let data = document?.data(),
                   let achievementTypes = data["unlockedAchievementTypes"] as? [String] {
                    
                    print("📦 Found achievement types in Firebase: \(achievementTypes)")
                    
                    // Convert achievement types back to Achievement IDs
                    let loadedAchievements = Set(
                        achievementTypes.compactMap { typeString in
                            self.achievements.first(where: { $0.type.rawValue == typeString })?.id
                        }
                    )
                    
                    print("✅ Parsed \(loadedAchievements.count) achievement IDs")
                    
                    DispatchQueue.main.async {
                        // Merge with existing achievements from UserDefaults
                        var mergedAchievements = self.unlockedAchievements
                        mergedAchievements.formUnion(loadedAchievements)
                        
                        print("🔄 Setting unlockedAchievements to: \(mergedAchievements.count) achievements")
                        self.unlockedAchievements = mergedAchievements
                        
                        // Force UI update
                        self.objectWillChange.send()
                        
                        // Save merged state back to UserDefaults
                        self.saveAchievementsToUserDefaults()
                        
                        // Debug print
                        self.debugPrintAchievements()
                    }
                } else {
                    print("ℹ️ No achievements found in Firebase")
                }
            }
        }

    // Add this function to your MoodTrackerViewModel class
    func checkWeeklyReview() {
        weeklyReviewManager.checkAndGenerateWeeklyReview(entries: moodEntries)
    }
    
    func debugState() {
        print("Current Achievement State:")
        print("Total achievements: \(achievements.count)")
        print("Unlocked achievements: \(unlockedAchievements.count)")
        print("Achievement IDs:")
        for achievement in achievements {
            let status = unlockedAchievements.contains(achievement.id) ? "🔓" : "🔒"
            print("\(status) \(achievement.title) - \(achievement.id)")
        }
    }

    
    func saveMood() {
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            showError = true
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No logged-in user"
            showError = true
            return
        }
        
        let newEntry = MoodEntry(
            date: Date(),
            moodLevel: moodLevel,
            factors: selectedFactors,
            note: noteText
        )
        
        let calendar = Calendar.current
        if let todayEntry = moodEntries.first(where: {
            calendar.isDate($0.date, inSameDayAs: Date())
        }) {
            // ✅ An entry for today already exists, ask user to confirm replacement
            pendingMoodEntry = newEntry
            showDuplicateEntryAlert = true
        } else {
            // ✅ No existing entry, proceed with saving
            saveEntryToFirebase(entry: newEntry, userId: currentUser.uid, replaceExisting: false)
        }
    }
    /// Saves a mood entry that includes an optional UIImage to be uploaded to Firebase Storage first.
    func saveMood(with uiImage: UIImage?) {
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            showError = true
            return
        }
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No logged-in user"
            showError = true
            return
        }
        
        // 1. If no image was selected, just do your normal save (no photoURL).
        if uiImage == nil {
            self.saveMood()  // uses your existing function
            return
        }
        
        // 2. If an image was chosen, upload it to Firebase Storage first.
        let storageRef = Storage.storage().reference()
        // We'll store images in "userPhotos/{uid}/{timestamp}.jpg"
        let fileName = "\(currentUser.uid)/\(Date().timeIntervalSince1970).jpg"
        let photoRef = storageRef.child("userPhotos").child(fileName)
        
        guard let imageData = uiImage!.jpegData(compressionQuality: 0.8) else {
            // fallback: cannot get data from UIImage, so just save without photo
            self.saveMood()
            return
        }
        
        photoRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                // fallback: save an entry without photo
                self.saveMood()
                return
            }
            
            // 3. On success, retrieve the download URL
            photoRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    // fallback: save an entry without photo
                    self.saveMood()
                    return
                }
                guard let downloadURL = url else {
                    // fallback
                    self.saveMood()
                    return
                }
                
                // 4. Now we have a valid photo URL from Storage.
                self.saveMood(photoURL: downloadURL.absoluteString)
            }
        }
    }
    /// A helper that saves a mood entry, optionally with a photoURL.
    private func saveMood(photoURL: String?) {
        guard networkMonitor.isConnected else {
            errorMessage = "No internet connection"
            showError = true
            return
        }
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No logged-in user"
            showError = true
            return
        }
        
        let newEntry = MoodEntry(
            date: Date(),
            moodLevel: moodLevel,
            factors: selectedFactors,
            note: noteText,
            photoURL: photoURL // <— here's the difference
        )
        
        let calendar = Calendar.current
        if let todayEntry = moodEntries.first(where: {
            calendar.isDate($0.date, inSameDayAs: Date())
        }) {
            // If an entry already exists for today, prompt user to replace
            pendingMoodEntry = newEntry
            showDuplicateEntryAlert = true
        } else {
            // Otherwise proceed
            saveEntryToFirebase(entry: newEntry, userId: currentUser.uid, replaceExisting: false)
        }
    }

    
    // Make sure this properly updates both Firebase and local array
    func confirmSaveExistingDayMood() {
        guard let entry = pendingMoodEntry, let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let calendar = Calendar.current
        let todayEntries = moodEntries.filter {
            calendar.isDate($0.date, inSameDayAs: Date()) // ✅ Get ALL entries for today
        }

        if let latestEntry = todayEntries.max(by: { $0.date < $1.date }), let latestEntryId = latestEntry.id {
            // ✅ Delete the most recent entry for today before saving the new one
            db.collection("users")
                .document(userId)
                .collection("moodEntries")
                .document(latestEntryId)
                .delete { [weak self] error in
                    if error == nil {
                        // ✅ Remove the old entry from local list
                        self?.moodEntries.removeAll { $0.id == latestEntryId }

                        // ✅ Save the new entry
                        self?.saveEntryToFirebase(entry: entry,
                                                  userId: userId,
                                                  replaceExisting: true,
                                                  existingDocID: latestEntryId)
                    } else {
                        self?.errorMessage = "Error replacing entry: \(error!.localizedDescription)"
                        self?.showError = true
                    }
                }
        } else {
            // ✅ If no existing entry found, just save the new one
            saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: false)
        }

        pendingMoodEntry = nil
    }

    

    
    private func saveEntryToFirebase(
        entry: MoodEntry,
        userId: String,
        replaceExisting: Bool,
        existingDocID: String? = nil
    ) {
        // Decide whether to reuse an existing doc ID or make a new one
        let documentRef: DocumentReference
        if replaceExisting, let docID = existingDocID {
            // Reuse the old doc ID (overwrites that document)
            documentRef = db.collection("users")
                            .document(userId)
                            .collection("moodEntries")
                            .document(docID)
        } else {
            // Generate a new doc ID
            documentRef = db.collection("users")
                            .document(userId)
                            .collection("moodEntries")
                            .document()
        }

        do {
            try documentRef.setData(from: entry) { [weak self] error in
                if let error = error {
                    self?.errorMessage = "Error saving entry: \(error.localizedDescription)"
                    self?.showError = true
                    return
                }
                // Success
                DispatchQueue.main.async {
                    // Optionally reset local UI states if needed
                    self?.moodLevel = 5.0
                    self?.selectedFactors.removeAll()
                    self?.noteText = ""

                    // If it’s overwriting, you may want to remove the old day’s data from moodEntries, etc.
                    if replaceExisting {
                        self?.moodEntries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }
                    }

                    // Append or re-insert the updated entry
                    self?.moodEntries.append(entry)

                    // Update usedFactors
                    self?.usedFactors.formUnion(entry.factors.keys)

                    // Check achievements, refresh analytics, etc.
                    self?.checkAchievements()
                    self?.objectWillChange.send()
                }
            }
        } catch {
            // Encoding error
            errorMessage = "Error encoding mood entry: \(error.localizedDescription)"
            showError = true
        }
    }


    func saveNewEntry(
        date: Date,
        moodLevel: Double,
        note: String,
        factors: [String: FactorImpact],
        photo: UIImage?,
        completion: @escaping () -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion()
            return
        }

        let newEntry = MoodEntry(
            date: date,
            moodLevel: moodLevel,
            factors: factors,
            note: note
        )

        if let photo = photo {
            // If the user added a photo, upload it first
            uploadPhotoAndSave(entry: newEntry, image: photo, userId: userId, completion: completion)
        } else {
            // Save directly if there's no photo
            saveEntryToFirebase(entry: newEntry, userId: userId, replaceExisting: false)
            completion()
        }
    }

    private func uploadPhotoAndSave(entry: MoodEntry, image: UIImage, userId: String, completion: @escaping () -> Void) {
        let storageRef = Storage.storage().reference()
        let fileName = "\(userId)/\(entry.date.timeIntervalSince1970).jpg"
        let photoRef = storageRef.child("userPhotos").child(fileName)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: false)
            completion()
            return
        }

        photoRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                self.saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: false)
                completion()
                return
            }

            photoRef.downloadURL { url, error in
                guard let downloadURL = url, error == nil else {
                    self.saveEntryToFirebase(entry: entry, userId: userId, replaceExisting: false)
                    completion()
                    return
                }

                let updatedEntry = MoodEntry(
                    id: entry.id,
                    date: entry.date,
                    moodLevel: entry.moodLevel,
                    factors: entry.factors,
                    note: entry.note,
                    photoURL: downloadURL.absoluteString // ✅ Now assigning the new photo URL
                )


                self.saveEntryToFirebase(entry: updatedEntry, userId: userId, replaceExisting: false)
                completion()
            }
        }
    }

    
    func fetchMoodEntries() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No logged-in user")
            return
        }

        db.collection("users")
          .document(currentUser.uid)
          .collection("moodEntries")
          .order(by: "date", descending: true)
          .getDocuments { [weak self] (querySnapshot, error) in
              if let error = error {
                  print("Error fetching mood entries: \(error.localizedDescription)")
                  return
              }

              guard let documents = querySnapshot?.documents else {
                  print("No mood entries found in Firebase.")
                  return
              }

              let updatedMoodEntries = documents.compactMap { document -> MoodEntry? in
                  do {
                      var entry = try document.data(as: MoodEntry.self)
                      entry.id = document.documentID
                      return entry
                  } catch {
                      print("Error decoding mood entry: \(error.localizedDescription)")
                      return nil
                  }
              }

              DispatchQueue.main.async {
                  self?.objectWillChange.send()
                  self?.moodEntries = updatedMoodEntries
                  
                  // Now that we have the real entries, check for achievements
                  // Only run achievement checks for users with entries
                  if !(updatedMoodEntries.isEmpty) {
                      self?.checkAchievements()
                  }
              }
          }
    }



    
    // MARK: - Analytics Methods
    
    func getMoodTrendData(for timeRange: TimeRange) -> [MoodTrendEntry] {
        let calendar = Calendar.current
        let today = Date()

        // Always get Monday of the current week
        var startOfWeek: Date = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        // Always get the following Sunday
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today

        let filteredEntries = moodEntries.filter { entry in
            switch timeRange {
            case .week:
                return entry.date >= startOfWeek && entry.date <= endOfWeek // ✅ Always within Monday to Sunday
            case .month:
                return calendar.dateComponents([.day], from: entry.date, to: today).day ?? 0 <= 30
            }
        }

        return filteredEntries
            .sorted { $0.date < $1.date }
            .map { MoodTrendEntry(date: $0.date, moodLevel: $0.moodLevel) }
    }






    func getFactorImpactData() -> [FactorImpactEntry] {
       guard networkMonitor.isConnected else {
           errorMessage = "No internet connection"
           showError = true
           return []
       }
       
       var factorImpacts: [String: (positive: Int, negative: Int)] = [:]
       
       for entry in moodEntries {
           for (factor, impact) in entry.factors {
               if factorImpacts[factor] == nil {
                   factorImpacts[factor] = (positive: 0, negative: 0)
               }
               
               if impact == .positive {
                   factorImpacts[factor]!.positive += 1
               } else {
                   factorImpacts[factor]!.negative += 1
               }
           }
       }
       
       return factorImpacts.map { factor, counts in
           let netImpact = Double(counts.positive - counts.negative)
           return FactorImpactEntry(name: factor, impact: netImpact)
       }.sorted { abs($0.impact) > abs($1.impact) }
    }

    func getWeeklyAverages() -> [WeeklyAverageEntry] {
       guard networkMonitor.isConnected else {
           errorMessage = "No internet connection"
           showError = true
           return []
       }
       
       let calendar = Calendar.current
       var weeklyMoods: [String: [Double]] = [:]
       
       for entry in moodEntries {
           let weekComponent = calendar.component(.weekOfYear, from: entry.date)
           let month = calendar.component(.month, from: entry.date)
           let weekKey = "W\(weekComponent)\n\(getMonthAbbreviation(month))"
           
           weeklyMoods[weekKey, default: []].append(entry.moodLevel)
       }
       
       return weeklyMoods.map { week, moods in
           let average = moods.reduce(0.0, +) / Double(moods.count)
           return WeeklyAverageEntry(week: week, average: average)
       }
       .sorted { $0.week < $1.week }
    }
    
    private func getMonthAbbreviation(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return dateFormatter.string(from: date)
    }
    
    func getMoodInsights() -> [String] {
        var insights: [String] = []
        
        // Factor analysis - Count all factor occurrences
        var factorCounts: [String: (positive: Int, negative: Int)] = [:]
        
        for entry in moodEntries {
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
        
        // Find highest positive and negative impact factors
        let maxPositive = factorCounts.values.map { $0.positive }.max() ?? 0
        let maxNegative = factorCounts.values.map { $0.negative }.max() ?? 0

        let topPositiveFactors = factorCounts
            .filter { $0.value.positive == maxPositive && maxPositive > 0 }
            .map { "\($0.key) (\($0.value.positive))" }
        
        let topNegativeFactors = factorCounts
            .filter { $0.value.negative == maxNegative && maxNegative > 0 }
            .map { "\($0.key) (\($0.value.negative))" }

        // Add insights to the list
        if !topPositiveFactors.isEmpty {
            insights.append("Top positive factors: \(topPositiveFactors.joined(separator: ", "))")
        }
        if !topNegativeFactors.isEmpty {
            insights.append("Top negative factors: \(topNegativeFactors.joined(separator: ", "))")
        }

        // Weekly Mood Average Analysis
        let trend = getMoodTrendData(for: .week)
        if trend.count >= 7 {
            let recentAvg = trend.map { $0.moodLevel }.reduce(0, +) / Double(trend.count)
            insights.append("Your average mood for the past week is \(String(format: "%.1f", recentAvg))")
        }

        return insights
    }

    
    // MARK: - Entry Management
    
    func getEntry(for date: Date) -> MoodEntry? {
        moodEntries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func toggleFactor(_ factor: String, impact: FactorImpact) {
        if selectedFactors[factor] == impact {
            selectedFactors.removeValue(forKey: factor)
        } else {
            selectedFactors[factor] = impact
        }
    }
    
    func getFactorImpact(_ factor: String) -> FactorImpact? {
        selectedFactors[factor]
    }
    
    // MARK: - Achievement Methods
    
    private func checkAchievements() {
        print("Checking achievements: \(moodEntries.count) entries")

        // -------------------------------------------------
        // 1) First log: "First Step"
        // -------------------------------------------------
        if moodEntries.count == 1 {
            unlockAchievement(type: .firstLog)
        }

        // -------------------------------------------------
        // 2) Streak achievements (3,7,30 days)
        // -------------------------------------------------
        updateStreakCount()
        
        // If the user has at least a 3-day streak
        if streakCount >= 3 {
            unlockAchievement(type: .streak3) // NEW
        }
        if streakCount >= 7 {
            unlockAchievement(type: .streak7)
        }
        if streakCount >= 30 {
            unlockAchievement(type: .streak30)
        }

        // -------------------------------------------------
        // 3) Factor-based achievements
        // -------------------------------------------------
        // usedFactors is updated each time we save a new mood entry
        // We'll check if each factor is in usedFactors
        // "Exercise Explorer" is your existing factorUse
        if usedFactors.contains("Exercise") {
            unlockAchievement(type: .factorUseExercise)
        }
        
        // NEW
        if usedFactors.contains("Social") {
            unlockAchievement(type: .factorUseSocial)
        }
        if usedFactors.contains("Food") {
            unlockAchievement(type: .factorUseFood)
        }
        if usedFactors.contains("Sleep") {
            unlockAchievement(type: .factorUseSleep)
        }
        if usedFactors.contains("Weather") {
            unlockAchievement(type: .factorUseWeather)
        }
        if usedFactors.contains("Health") {
            unlockAchievement(type: .factorUseHealth)
        }

        // Factor Sampler: must contain all 8 of your app's factors
        // (Work, Exercise, Weather, Sleep, Social, Food, Health, News)
        let allFactors = ["Work","Exercise","Weather","Sleep","Social","Food","Health","News"]
        if allFactors.allSatisfy({ usedFactors.contains($0) }) {
            unlockAchievement(type: .factorSampler)
        }

        // -------------------------------------------------
        // 4) Mood variety (existing code)
        // -------------------------------------------------
        checkMoodVariety()
        // inside that method, it calls unlockAchievement(.moodVariety) if enough unique levels

        // -------------------------------------------------
        // 5) Day counts for logging
        // -------------------------------------------------
        // "Dedicated Diarist" => 10 total days
        // "Fifteen Moods"     => 15 total days
        //
        // Because you only store unique days in moodEntries, each entry is already a distinct day.
        // If you allow multiple entries per day, you might want to do:
        //   let uniqueDays = Set(moodEntries.map { Calendar.current.startOfDay(for:$0.date) }).count
        //
        // But let's assume each day is unique in moodEntries.
        if moodEntries.count >= 10 {
            unlockAchievement(type: .dedicatedDiarist) // NEW
        }
        if moodEntries.count >= 15 {
            unlockAchievement(type: .fifteenMoods) // NEW
        }

        // -------------------------------------------------
        // 6) Note Taker (10 non-empty notes)
        // -------------------------------------------------
        let noteCount = moodEntries.filter {
            !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        if noteCount >= 10 {
            unlockAchievement(type: .noteTaker) // NEW
        }
    }

    
    private func unlockAchievement(type: AchievementType) {
        if let achievement = achievements.first(where: { $0.type == type }),
           !unlockedAchievements.contains(achievement.id) {
            
            print("🎯 Unlocking achievement: \(achievement.title)")
            
            DispatchQueue.main.async { [weak self] in
                self?.unlockedAchievements.insert(achievement.id)
                self?.objectWillChange.send()
                self?.saveAchievementsToFirebase()
                self?.saveAchievementsToUserDefaults()
                
                // Show notification
                self?.lastUnlockedAchievement = achievement
                self?.showingAchievementNotification = true
                
                print("🎉 Achievement unlocked: \(achievement.title)")
                self?.debugPrintAchievements()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.showingAchievementNotification = false
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateStreakCount() {
        guard !moodEntries.isEmpty else {
            streakCount = 0
            return
        }
        let calendar = Calendar.current
        let sortedEntries = moodEntries.sorted { $0.date < $1.date }

        var currentStreak = 1
        var previousDate = sortedEntries[0].date

        for entry in sortedEntries.dropFirst() {
            let daysBetween = calendar.dateComponents([.day], from: previousDate, to: entry.date).day ?? 0
            
            if daysBetween == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            previousDate = entry.date
        }
        streakCount = currentStreak
    }

    
    private func checkMoodVariety() {
        let uniqueMoodLevels = Set(moodEntries.map { entry in
            switch entry.moodLevel {
            case 0...2: return "Very Low"
            case 2...4: return "Low"
            case 4...6: return "Neutral"
            case 6...8: return "High"
            case 8...10: return "Very High"
            default: return "Unknown"
            }
        })
        
        if uniqueMoodLevels.count >= 5 {
            unlockAchievement(type: .moodVariety)
        }
    }
    
    private func setupAchievements() {
        achievements = [

            // MARK: Existing 5

            Achievement(
                type: .firstLog,
                title: "First Step",
                description: "Log your first mood entry",
                iconName: "star.fill",
                
                color: Color(red: 255/255, green: 215/255, blue: 0/255)
            ),
            Achievement(
                type: .streak7,
                title: "Week Warrior",
                description: "Complete a 7-day logging streak",
                iconName: "flame.fill",
                
                color: Color(red: 255/255, green: 140/255, blue: 0/255)
            ),
            Achievement(
                type: .streak30,
                title: "Monthly Master",
                description: "Complete a 30-day logging streak",
                iconName: "crown.fill",
              
                color: Color(red: 255/255, green: 165/255, blue: 0/255)
            ),
            Achievement(
                type: .factorUseExercise,
                title: "Exercise Explorer",
                description: "Use the Exercise factor for the first time",
                iconName: "figure.run",
           
                color: Color(red: 50/255, green: 205/255, blue: 50/255)
            ),
            Achievement(
                type: .moodVariety,
                title: "Mood Range",
                description: "Experience the full range of moods",
                iconName: "chart.bar.fill",
     
                color: Color(red: 70/255, green: 130/255, blue: 180/255)
            ),

            // MARK: 10 New

            Achievement(
                type: .streak3,
                title: "3-Day Spree",
                description: "Log moods 3 days in a row",
                iconName: "3.circle.fill",
               
                color: .blue
            ),
            Achievement(
                type: .dedicatedDiarist,
                title: "Dedicated Diarist",
                description: "Log moods on 10 different days",
                iconName: "book.fill",
         
                color: .purple
            ),
            Achievement(
                type: .factorUseSocial,
                title: "Social Butterfly",
                description: "Use the Social factor for the first time",
                iconName: "person.2.fill",
       
                color: .pink
            ),
            Achievement(
                type: .factorUseFood,
                title: "Foodie",
                description: "Use the Food factor for the first time",
                iconName: "fork.knife",
            
                color: .orange
            ),
            Achievement(
                type: .factorSampler,
                title: "Factor Sampler",
                description: "Use all available factors at least once",
                iconName: "rectangle.3.group.fill",
   
                color: Color(red: 0/255, green: 180/255, blue: 180/255)
            ),
            Achievement(
                type: .noteTaker,
                title: "Note Taker",
                description: "Save 10 notes in total",
                iconName: "note.text",
         
                color: Color(red: 160/255, green: 32/255, blue: 240/255)
            ),
            Achievement(
                type: .factorUseSleep,
                title: "Well-Rested",
                description: "Use the Sleep factor for the first time",
                iconName: "bed.double.fill",
                
                color: Color(red: 138/255, green: 43/255, blue: 226/255)
            ),
            Achievement(
                type: .factorUseWeather,
                title: "Weather Watcher",
                description: "Use the Weather factor for the first time",
                iconName: "cloud.sun.fill",
              
                color: Color(red: 0/255, green: 191/255, blue: 255/255)
            ),
            Achievement(
                type: .fifteenMoods,
                title: "Fifteen Moods",
                description: "Log moods on 15 different days",
                iconName: "15.circle.fill",
               
                color: Color(red: 100/255, green: 149/255, blue: 237/255)
            ),
            Achievement(
                type: .factorUseHealth,
                title: "Health Advocate",
                description: "Use the Health factor for the first time",
                iconName: "heart.fill",
              
                color: Color(red: 255/255, green: 20/255, blue: 147/255)
            )
        ]
    }

    
    private func setupMockData() {
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in (-30...0).reversed() {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let mockEntry = MoodEntry(
                    date: date,
                    moodLevel: Double.random(in: 3...9),
                    factors: [
                        "Exercise": Bool.random() ? .positive : .negative,
                        "Sleep": Bool.random() ? .positive : .negative
                    ],
                    note: "Mock entry for testing"
                )
                moodEntries.append(mockEntry)
            }
        }
    }
    
    // MARK: - Logout Method
    
    func logout() {
        // Clear achievements for the current user from UserDefaults before logging out
        if let userId = Auth.auth().currentUser?.uid {
            UserDefaults.standard.removeObject(forKey: "unlockedAchievements_\(userId)")
        }
        
        do {
            try Auth.auth().signOut()
            // Reset view model state
            moodEntries.removeAll()
            unlockedAchievements.removeAll()
            selectedFactors.removeAll()
            noteText = ""
            moodLevel = 5.0
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func uploadNewPhotoAndUpdate(
            entry: MoodEntry,
            newMoodLevel: Double,
            newNote: String,
            newFactors: [String: FactorImpact],
            newImage: UIImage,
            completion: @escaping () -> Void
        ) {
            guard let userId = Auth.auth().currentUser?.uid else {
                completion()
                return
            }
            guard let docID = entry.id else {
                completion()
                return
            }
            
            let storageRef = Storage.storage().reference()
            let fileName = "\(userId)/\(Date().timeIntervalSince1970).jpg"
            let photoRef = storageRef.child("userPhotos").child(fileName)
            
            guard let imageData = newImage.jpegData(compressionQuality: 0.8) else {
                // fallback: keep old photoURL
                self.updateExistingEntry(
                    existingEntry: entry,
                    newMoodLevel: newMoodLevel,
                    newNote: newNote,
                    newFactors: newFactors,
                    newPhotoURL: entry.photoURL
                )
                completion()
                return
            }
            
            photoRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading new image: \(error.localizedDescription)")
                    self.updateExistingEntry(
                        existingEntry: entry,
                        newMoodLevel: newMoodLevel,
                        newNote: newNote,
                        newFactors: newFactors,
                        newPhotoURL: entry.photoURL
                    )
                    completion()
                    return
                }
                
                photoRef.downloadURL { url, error in
                    guard let downloadURL = url, error == nil else {
                        self.updateExistingEntry(
                            existingEntry: entry,
                            newMoodLevel: newMoodLevel,
                            newNote: newNote,
                            newFactors: newFactors,
                            newPhotoURL: entry.photoURL
                        )
                        completion()
                        return
                    }
                    
                    self.updateExistingEntry(
                        existingEntry: entry,
                        newMoodLevel: newMoodLevel,
                        newNote: newNote,
                        newFactors: newFactors,
                        newPhotoURL: downloadURL.absoluteString
                    )
                    completion()
                }
            }
        }
        
        func updateExistingEntry(
            existingEntry: MoodEntry,
            newMoodLevel: Double,
            newNote: String,
            newFactors: [String: FactorImpact],
            newPhotoURL: String?
        ) {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            guard let docID = existingEntry.id else { return }
            
            let docRef = db.collection("users")
                .document(userId)
                .collection("moodEntries")
                .document(docID)
            
            // Build a new MoodEntry with updated fields but the same ID + date
            let updatedEntry = MoodEntry(
                id: docID,
                date: existingEntry.date,
                moodLevel: newMoodLevel,
                factors: newFactors,
                note: newNote,
                photoURL: newPhotoURL
            )
            
            do {
                try docRef.setData(from: updatedEntry) { [weak self] error in
                    if let error = error {
                        print("Error updating entry: \(error.localizedDescription)")
                        return
                    }
                    DispatchQueue.main.async {
                        if let index = self?.moodEntries.firstIndex(where: { $0.id == docID }) {
                            self?.moodEntries[index] = updatedEntry
                            self?.weeklyReviewManager.updateReviewsAfterEntryEdit(editedEntry: updatedEntry)
                        }
                    }
                }
            } catch {
                print("Error encoding updated entry: \(error.localizedDescription)")
            }
        }

    
    // Add these methods to your MoodTrackerViewModel class

    // MARK: - Notification Support

    // Call this when a new achievement is unlocked
    private func notifyAchievementUnlocked(_ achievement: Achievement) {
        NotificationManager.shared.sendAchievementNotification(
            title: achievement.title,
            description: achievement.description
        )
    }

    // Update the existing unlockAchievement method to include notification
    

    // Check for inactivity - call this when the app becomes active
    func checkInactivity() {
        let calendar = Calendar.current
        let today = Date()
        
        // Sort entries by date (descending)
        let sortedEntries = moodEntries.sorted { $0.date > $1.date }
        
        // If we have entries, check the most recent one
        if let mostRecentEntry = sortedEntries.first {
            let daysSinceLastEntry = calendar.dateComponents([.day], from: mostRecentEntry.date, to: today).day ?? 0
            
            // Send re-engagement notification if inactive for exactly 7 or 14 days
            if daysSinceLastEntry == 7 || daysSinceLastEntry == 14 {
                NotificationManager.shared.sendReengagementNotification(daysInactive: daysSinceLastEntry)
            }
        }
    }

    // Check for patterns - call this after saving new entries
    func checkForPatterns() {
        // Only proceed if pattern insights are enabled
        guard NotificationManager.shared.settings.patternInsightsEnabled,
              moodEntries.count >= 10 else { return }
        
        // Look for exercise-mood correlation
        detectExerciseMoodCorrelation()
        
        // Look for social-mood correlation
        detectSocialMoodCorrelation()
        
        // Look for sleep-mood correlation
        detectSleepMoodCorrelation()
    }

    // Detect if exercise correlates with better mood
    private func detectExerciseMoodCorrelation() {
        let exerciseEntries = moodEntries.filter { $0.factors["Exercise"] != nil }
        guard exerciseEntries.count >= 5 else { return } // Need at least 5 entries with exercise data
        
        let exercisePositive = exerciseEntries.filter { $0.factors["Exercise"] == .positive }
        let exerciseNegative = exerciseEntries.filter { $0.factors["Exercise"] == .negative }
        
        // Calculate average moods
        let avgWithPositiveExercise = exercisePositive.map { $0.moodLevel }.reduce(0, +) / Double(exercisePositive.count)
        let avgWithNegativeExercise = exerciseNegative.map { $0.moodLevel }.reduce(0, +) / Double(exerciseNegative.count)
        let avgMoodOverall = moodEntries.map { $0.moodLevel }.reduce(0, +) / Double(moodEntries.count)
        
        // Is positive exercise associated with significantly higher mood?
        if exercisePositive.count >= 3 && // Need at least 3 positive exercise entries
           avgWithPositiveExercise > avgMoodOverall + 1.0 { // At least 1 point higher mood
            
            let insightMessage = "You tend to feel better on days when you exercise. Your mood averages \(String(format: "%.1f", avgWithPositiveExercise)) with exercise vs \(String(format: "%.1f", avgMoodOverall)) overall."
            
            NotificationManager.shared.sendPatternInsight(insight: insightMessage)
        }
    }

    // Detect if social activities correlate with better mood
    private func detectSocialMoodCorrelation() {
        let socialEntries = moodEntries.filter { $0.factors["Social"] != nil }
        guard socialEntries.count >= 5 else { return }
        
        let socialPositive = socialEntries.filter { $0.factors["Social"] == .positive }
        
        if socialPositive.count >= 3 {
            let avgWithPositiveSocial = socialPositive.map { $0.moodLevel }.reduce(0, +) / Double(socialPositive.count)
            let avgMoodOverall = moodEntries.map { $0.moodLevel }.reduce(0, +) / Double(moodEntries.count)
            
            if avgWithPositiveSocial > avgMoodOverall + 1.0 {
                let insightMessage = "Social activities appear to boost your mood. Consider scheduling more time with friends!"
                
                NotificationManager.shared.sendPatternInsight(insight: insightMessage)
            }
        }
    }

    // Detect if good sleep correlates with better mood
    private func detectSleepMoodCorrelation() {
        let sleepEntries = moodEntries.filter { $0.factors["Sleep"] != nil }
        guard sleepEntries.count >= 5 else { return }
        
        let sleepPositive = sleepEntries.filter { $0.factors["Sleep"] == .positive }
        let sleepNegative = sleepEntries.filter { $0.factors["Sleep"] == .negative }
        
        if sleepPositive.count >= 3 && sleepNegative.count >= 3 {
            let avgWithGoodSleep = sleepPositive.map { $0.moodLevel }.reduce(0, +) / Double(sleepPositive.count)
            let avgWithBadSleep = sleepNegative.map { $0.moodLevel }.reduce(0, +) / Double(sleepNegative.count)
            
            if avgWithGoodSleep > avgWithBadSleep + 1.5 {
                let insightMessage = "Quality sleep makes a big difference in your mood. Your mood is \(String(format: "%.1f", avgWithGoodSleep - avgWithBadSleep)) points higher after good sleep."
                
                NotificationManager.shared.sendPatternInsight(insight: insightMessage)
            }
        }
    }
}

extension MoodTrackerViewModel {
    func debugPrintAchievements() {
        print("🏆 Total Achievements: \(achievements.count)")
        print("🔓 Unlocked Achievements: \(unlockedAchievements.count)")
        print("Unlocked IDs: \(unlockedAchievements.map { $0.uuidString })")
        
        // Print each achievement status
        for achievement in achievements {
            let status = unlockedAchievements.contains(achievement.id) ? "🔓" : "🔒"
            print("\(status) \(achievement.title)")
        }
    }
}
