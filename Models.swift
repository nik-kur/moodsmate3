import SwiftUI

// In Models.swift

enum FactorImpact: String, Codable {
    case positive = "positive"
    case negative = "negative"
    
    // Add an initializer to handle potential decoding issues
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue.lowercased() {
        case "positive":
            self = .positive
        case "negative":
            self = .negative
        default:
            // Provide a default value if the decoded value is unexpected
            self = .positive
        }
    }
}

enum AppScreen {
    case home
    case stats
    case calendar
    case profile
}

struct MoodFactorInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    
    // Implementing Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MoodFactorInfo, rhs: MoodFactorInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// Add these new structures to Models.swift
struct Achievement: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let iconName: String
    let type: AchievementType
    let color: Color
    
    init(type: AchievementType, title: String, description: String, iconName: String, color: Color) {
        self.id = UUID(uuidString: type.rawValue) ?? UUID()
        self.title = title
        self.description = description
        self.iconName = iconName
        self.type = type
        self.color = color
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type.rawValue)
    }
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}

enum AchievementType: String {
    case firstLog = "47B06C4A-A9B4-4023-A484-E3E8DC3AAF74"
    case streak3 = "1815C644-1A8D-4E51-9283-AAB72F0B1F01"
    case streak7 = "2A9BB4D5-1B8E-4E62-9283-AAB72F0B1F02"
    case streak30 = "3C9DC6E6-1C8F-4E73-9283-AAB72F0B1F03"
    case factorUseExercise = "4DAE8F7-1D90-4E84-9283-AAB72F0B1F04"
    case factorUseSocial = "5EBF9088-1E91-4E95-9283-AAB72F0B1F05"
    case factorUseFood = "6FC0A199-1F92-4EA6-9283-AAB72F0B1F06"
    case factorUseSleep = "7GD1B2AA-2093-4EB7-9283-AAB72F0B1F07"
    case factorUseWeather = "8HE2C3BB-2194-4EC8-9283-AAB72F0B1F08"
    case factorUseHealth = "9IF3D4CC-2295-4ED9-9283-AAB72F0B1F09"
    case factorSampler = "10JG4E5DD-2396-4EE0-9283-AAB72F0B1F10"
    case moodVariety = "11KH5F6EE-2497-4EF1-9283-AAB72F0B1F11"
    case dedicatedDiarist = "12LI6G7FF-2598-4EF2-9283-AAB72F0B1F12"
    case fifteenMoods = "13MJ7H8GG-2699-4EF3-9283-AAB72F0B1F13"
    case noteTaker = "14NK8I9HH-2700-4EF4-9283-AAB72F0B1F14"
}



