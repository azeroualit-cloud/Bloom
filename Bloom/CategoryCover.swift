import SwiftUI

/// A category is a destination, with identity and count in one compact card.
struct CategoryCover: View {
    let name: String
    let symbol: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: BloomLayout.small) {
            Image(systemName: Self.symbol(for: name, fallback: symbol))
                .font(.title2.weight(.medium)).foregroundStyle(BloomBrand.gradient)
                .frame(width: BloomLayout.touch, height: BloomLayout.touch)
                .background(Color.bloomRaised, in: RoundedRectangle(cornerRadius: BloomLayout.gap))
                .accessibilityHidden(true)
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.bloomText)
            Text(ContentLabels.noteCount(count)).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(BloomLayout.margin)
        .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomLayout.radius))
    }

    static func symbol(for name: String, fallback: String) -> String {
        symbols[name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)] ?? fallback
    }
    private static let symbols = [
        "looks": "tshirt", "luoghi": "mappin.and.ellipse", "foto/video": "photo.on.rectangle.angled",
        "salute": "heart", "alimentazione": "carrot", "studio": "book",
        "lavoro": "briefcase", "progetti": "hammer", "casa": "house",
        "tecnologia": "desktopcomputer", "comunicazione": "bubble.left.and.bubble.right",
        "dating": "heart", "psicologia": "brain.head.profile", "viaggi": "airplane"
    ]
}
