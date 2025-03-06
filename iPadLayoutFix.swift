import SwiftUI

// Extension to apply proper iPad layout
extension View {
    func fixIPadLayout() -> some View {
        self.modifier(IPadLayoutModifier())
    }
}

// Modifier that handles iPad-specific layout
struct IPadLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            GeometryReader { geometry in
                content
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.all)
            }
        } else {
            content
        }
    }
}
