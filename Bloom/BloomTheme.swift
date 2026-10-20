import SwiftUI

enum BloomBrand {
    static var gradient: LinearGradient {
        LinearGradient(colors: [Color("BrandBlue"), Color("AccentColor"), Color("BrandWine")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    static let bloomBackground = Color("BloomBackground")
    static let bloomSurface = Color("BloomSurface")
    static let bloomRaised = Color("BloomRaised")
    static let bloomText = Color("BloomText")
}

extension View {
    /// Semantic colors follow the system appearance; navigation controls retain native materials.
    func bloomCanvas() -> some View {
        self.scrollContentBackground(.hidden)
            .background(Color.bloomBackground)
            .toolbarBackground(Color.bloomBackground, for: .navigationBar, .tabBar)
    }
}
