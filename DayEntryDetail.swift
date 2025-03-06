import SwiftUI

// MARK: - DayEntryDetail

struct DayEntryDetail: View {
    let entry: MoodEntry
    
    // Provide your environment object
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingEditView = false
    
    // Same color scheme logic
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255)
    )
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1) Mood Level
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mood Level")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(colors.secondary)
                        
                        HStack {
                            Text(String(format: "%.1f", entry.moodLevel))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(moodColor(entry.moodLevel))
                            
                            Spacer()
                            
                            Image(systemName: moodIcon(entry.moodLevel))
                                .font(.system(size: 34))
                                .foregroundColor(moodColor(entry.moodLevel))
                        }
                        .padding()
                        .background(colors.buttonBackground)
                        .cornerRadius(16)
                    }
                    
                    // 2) Note
                    if !entry.note.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Note")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            
                            Text(entry.note)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colors.buttonBackground)
                                .cornerRadius(12)
                        }
                    }
                    
                    // 3) Photo
                    if let photoURL = entry.photoURL,
                       let url = URL(string: photoURL) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView().frame(height: 200)
                                case .success(let image):
                                    image.resizable()
                                         .scaledToFit()
                                         .frame(maxWidth: .infinity)
                                         .cornerRadius(12)
                                case .failure(_):
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    
                    // 4) Factors
                    if !entry.factors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mood Factors")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(colors.secondary)
                            
                            VStack(spacing: 12) {
                                ForEach(entry.factors.keys.sorted(), id: \.self) { factorName in
                                    HStack {
                                        Text(factorName)
                                            .font(.system(size: 17))
                                        
                                        Spacer()
                                        
                                        if let impact = entry.factors[factorName] {
                                            Text(impact == .positive ? "Positive" : "Negative")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    impact == .positive
                                                    ? colors.positive
                                                    : colors.negative
                                                )
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding()
                                    .background(colors.buttonBackground)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                }
                .dismissKeyboardOnTap()
                .padding()
            }
            .background(colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Close
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(colors.secondary)
                    }
                }
                // Date
                ToolbarItem(placement: .principal) {
                    Text(formattedDate(entry.date))
                        .font(.headline)
                        .foregroundColor(colors.secondary)
                }
                // Edit
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        isShowingEditView = true
                    }
                    .foregroundColor(colors.secondary)
                }
            }
            .sheet(isPresented: $isShowingEditView) {
                EditDayEntryView(entry: entry)
                    .environmentObject(viewModel)
            }
        }
    }
    
    // MARK: - Private
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: date)
    }
    
    /// Matches your homeview logic:
    /// (1–2 depressed, 2–4 down, 4–6 neutral, 6–8 good, 8–10 euphoric)
    private func moodColor(_ level: Double) -> Color {
        switch level {
        case 8...10:
            return Color(red: 255/255, green: 215/255, blue: 0/255) // euphoric
        case 6...8:
            return Color(red: 98/255, green: 182/255, blue: 183/255) // good
        case 4...6:
            return Color(red: 135/255, green: 206/255, blue: 235/255) // neutral
        case 2...4:
            return Color(red: 176/255, green: 196/255, blue: 222/255) // down
        default:
            return Color(red: 169/255, green: 169/255, blue: 169/255) // depressed
        }
    }
    
    private func moodIcon(_ level: Double) -> String {
        switch level {
        case 8...10: return "sun.max.fill"
        case 6...8:  return "sun.and.horizon.fill"
        case 4...6:  return "cloud.sun.fill"
        case 2...4:  return "cloud.fill"
        default:     return "cloud.rain.fill"
        }
    }
}


// MARK: - EditDayEntryView

struct EditDayEntryView: View {
    @EnvironmentObject var viewModel: MoodTrackerViewModel
    @Environment(\.dismiss) private var dismiss
    
    let entry: MoodEntry
    
    private var isNewEntry: Bool {
        entry.id == nil
    }

    // Local states
    @State private var moodLevel: Double
    @State private var noteText: String
    @State private var selectedFactors: [String: FactorImpact]
    @State private var selectedUIImage: UIImage?
    
    // Factor swiping
    @State private var dragOffset: [String: CGFloat] = [:]
    @State private var selectedInfoFactor: String? = nil
    @State private var showingFactorInfo = false
    @State private var showImagePicker = false
    
    // Same color tuple as your HomeView
    private let colors = (
        background: Color(red: 250/255, green: 248/255, blue: 245/255),
        secondary: Color(red: 147/255, green: 112/255, blue: 219/255),
        buttonBackground: Color(red: 245/255, green: 245/255, blue: 250/255),
        positive: Color(red: 126/255, green: 188/255, blue: 137/255),
        negative: Color(red: 255/255, green: 182/255, blue: 181/255),
        euphoric: Color(red: 255/255, green: 215/255, blue: 0/255),
        good: Color(red: 98/255, green: 182/255, blue: 183/255),
        neutral: Color(red: 135/255, green: 206/255, blue: 235/255),
        down: Color(red: 176/255, green: 196/255, blue: 222/255),
        depressed: Color(red: 169/255, green: 169/255, blue: 169/255),
        text: Color.primary,
        textSecondary: Color.secondary
    )
    
    // Factor name array (no MoodFactorInfo struct).
    // These match your "factors" from HomeView.
    private let factorNames = [
        "Work", "Exercise", "Weather", "Sleep",
        "Social", "Food", "Health", "News"
    ]
    
    private let factorIcons: [String: String] = [
        "Work": "briefcase",
        "Exercise": "figure.run",
        "Weather": "cloud.sun",
        "Sleep": "bed.double",
        "Social": "person.2",
        "Food": "fork.knife",
        "Health": "heart",
        "News": "newspaper"
    ]
    
    // Mood level ranges from 1–10 with same color logic as your HomeView
    private let moodRanges: [(ClosedRange<Double>, (name: String, icon: String, desc: String, color: Color))] = [
        (0...2, ("Depressed", "cloud.rain.fill", "Feeling very low and overwhelmed", Color(red: 169/255, green: 169/255, blue: 169/255))),
        (2...4, ("Down", "cloud.fill", "Having a rough time", Color(red: 176/255, green: 196/255, blue: 222/255))),
        (4...6, ("Neutral", "cloud.sun.fill", "Neither high nor low", Color(red: 135/255, green: 206/255, blue: 235/255))),
        (6...8, ("Good", "sun.and.horizon.fill", "Feeling positive", Color(red: 98/255, green: 182/255, blue: 183/255))),
        (8...10, ("Euphoric", "sun.max.fill", "On top of the world!", Color(red: 255/255, green: 215/255, blue: 0/255)))
    ]
    
    // Derived property for "current mood" in the same style
    private var currentMood: (name: String, icon: String, desc: String, color: Color) {
        moodRanges.first { $0.0.contains(moodLevel) }?.1
        ?? ("Neutral", "cloud.sun.fill", "Neither high nor low", colors.neutral)
    }
    
    init(entry: MoodEntry) {
        self.entry = entry
        _moodLevel = State(initialValue: entry.moodLevel)
        _noteText = State(initialValue: entry.note)
        _selectedFactors = State(initialValue: entry.factors)
    }
    
    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    
                    // Purple Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Edit Entry")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Update your mood data")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            Spacer()
                            
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 24)
                    .background(
                        colors.secondary
                            .cornerRadius(30, corners: [.bottomLeft, .bottomRight])
                    )
                    
                    VStack(spacing: 32) {
                        
                        // Mood Section
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
                                    
                                    Text(currentMood.desc)
                                        .font(.system(size: 16))
                                        .foregroundColor(colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                            .background(colors.buttonBackground)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                            .padding(.horizontal)
                            
                            // Slider
                            VStack(spacing: 10) {
                                Slider(value: $moodLevel, in: 0...10, step: 0.5)
                                    .tint(currentMood.color)
                                    .padding(.horizontal)
                                
                                HStack {
                                    Text("0").font(.system(size: 15)).foregroundColor(colors.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.1f", moodLevel))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(currentMood.color)
                                    Spacer()
                                    Text("10").font(.system(size: 15)).foregroundColor(colors.textSecondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Factor section
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
                            
                            LazyVGrid(columns: [GridItem(.flexible(), spacing:16),
                                                GridItem(.flexible(), spacing:16)],
                                      spacing:16) {
                                ForEach(factorNames, id: \.self) { name in
                                    factorButton(factorName: name)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Note
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
                            
                            TextEditor(text: $noteText)
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
                        
                        // Photo
                        if selectedUIImage != nil {
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
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            Text("Attach Photo")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(colors.secondary)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // Save Changes
                        Button {
                            updateEntry()
                        } label: {
                            Text("Save Changes")
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
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedUIImage)
            }
            // Show factor info popup if needed
            if showingFactorInfo, let selectedFactor = selectedInfoFactor {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingFactorInfo = false
                    }
                
                // Show some info about factor
                // If you want the full text like in HomeView, add a dictionary mapping factorName->desc
                infoPopupForFactorName(selectedFactor)
            }
        }
    }
    
    // MARK: - Factor Button (Swipe)
    
    private func factorButton(factorName: String) -> some View {
        let impact = selectedFactors[factorName]
        let offset = dragOffset[factorName] ?? 0
        
        return VStack {
            HStack {
                // left arrow
                Image(systemName: "chevron.left")
                    .foregroundColor(colors.positive)
                    .opacity(offset < 0 ? 1 : 0)
                
                Spacer()
                
                VStack(spacing: 8) {
                    // Instead of "questionmark.circle", do this:
                    let iconName = factorIcons[factorName] ?? "questionmark.circle"

                    // Then when you create the Image:
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(impact == nil ? colors.secondary : .white)

                        .frame(width: 30, height: 30)
                    
                    Text(factorName)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // right arrow
                Image(systemName: "chevron.right")
                    .foregroundColor(colors.negative)
                    .opacity(offset > 0 ? 1 : 0)
            }
            .frame(height: 72)
            .foregroundColor(impact == nil ? colors.text : .white)
            .background(
                Group {
                    switch impact {
                    case .positive: colors.positive
                    case .negative: colors.negative
                    case nil:       colors.buttonBackground
                    }
                }
            )
            .cornerRadius(12)
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    dragOffset[factorName] = gesture.translation.width
                }
                .onEnded { gesture in
                    let dist = gesture.translation.width
                    if abs(dist) > 50 {
                        toggleFactor(name: factorName, impact: dist < 0 ? .positive : .negative)
                    }
                    dragOffset[factorName] = 0
                }
        )
        .onTapGesture {
            // optional: show factor info
            selectedInfoFactor = factorName
            showingFactorInfo = true
        }
    }
    
    private func toggleFactor(name: String, impact: FactorImpact) {
        if selectedFactors[name] == impact {
            selectedFactors.removeValue(forKey: name)
        } else {
            selectedFactors[name] = impact
        }
    }
    
    // MARK: - Save
    private func updateEntry() {
        if isNewEntry {
            // If it's a new entry, save it as a new record
            viewModel.saveNewEntry(
                date: entry.date,
                moodLevel: moodLevel,
                note: noteText,
                factors: selectedFactors,
                photo: selectedUIImage
            ) {
                dismiss()
            }
        } else {
            // If it's an existing entry, update it
            if let uiImage = selectedUIImage {
                viewModel.uploadNewPhotoAndUpdate(
                    entry: entry,
                    newMoodLevel: moodLevel,
                    newNote: noteText,
                    newFactors: selectedFactors,
                    newImage: uiImage
                ) {
                    dismiss()
                }
            } else {
                viewModel.updateExistingEntry(
                    existingEntry: entry,
                    newMoodLevel: moodLevel,
                    newNote: noteText,
                    newFactors: selectedFactors,
                    newPhotoURL: entry.photoURL
                )
                dismiss()
            }
        }
    }

    
    // MARK: - Info Popup
    private func infoPopupForFactorName(_ factorName: String) -> some View {
        // Show a quick snippet
        // If you want more detailed text, use a dictionary or etc.
        VStack(spacing: 16) {
            Text("About \(factorName)")
                .font(.headline)
                .padding(.top)
            
            Text("This factor influences your mood by: ...")
                .font(.body)
                .padding()
            
            Button("Got it") {
                showingFactorInfo = false
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colors.secondary)
            .cornerRadius(10)
        }
        .frame(maxWidth: 300)
        .padding()
        .background(.thinMaterial)
        .cornerRadius(16)
        .shadow(radius: 8)
    }
}

