import SwiftUI

struct AdaptiveColors {
    // Core color palette with adaptive backgrounds
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    
    // Preserve your original base colors, but use adaptive variants where needed
    static let secondary = Color(red: 147/255, green: 112/255, blue: 219/255)
    static let buttonBackground = Color(UIColor.tertiarySystemBackground)
    
    // Adaptive text colors
    static let primaryText = Color(UIColor.label)
    static let secondaryText = Color(UIColor.secondaryLabel)
    
    // Preserved mood and accent colors
    static let positive = Color(red: 126/255, green: 188/255, blue: 137/255)
    static let negative = Color(red: 255/255, green: 182/255, blue: 181/255)
    
    // Mood color ranges (consistent across dark and light modes)
    static let moodColors = [
        Color(red: 169/255, green: 169/255, blue: 169/255),   // Depressed
        Color(red: 176/255, green: 196/255, blue: 222/255),   // Down
        Color(red: 135/255, green: 206/255, blue: 235/255),   // Neutral
        Color(red: 98/255, green: 182/255, blue: 183/255),    // Good
        Color(red: 255/255, green: 215/255, blue: 0/255)      // Euphoric
    ]
}
