import SwiftUI

enum BloomLayout {
    static let compact: CGFloat = 4
    static let small: CGFloat = 8
    static let gap: CGFloat = 12
    static let margin: CGFloat = 16
    static let section: CGFloat = 24
    static let touch: CGFloat = 44
    static let radius: CGFloat = 16
}

/// Equal columns keep the title centered regardless of the actions' text lengths.
struct BloomPageHeader<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: BloomLayout.small) {
            leading.frame(minWidth: 0, maxWidth: .infinity, minHeight: BloomLayout.touch)
            VStack(spacing: 2) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }.frame(minWidth: 0, maxWidth: .infinity, minHeight: BloomLayout.touch)
            trailing.frame(minWidth: 0, maxWidth: .infinity, minHeight: BloomLayout.touch)
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.plain)
        .padding(.horizontal, BloomLayout.margin)
        .padding(.vertical, BloomLayout.small)
        .background(Color.bloomBackground)
    }
}

extension View {
    /// Keep scrolling thumbnails separate from the tab labels.
    func bloomTabFoundation() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.bloomBackground.frame(height: BloomLayout.small)
                .background(Color.bloomBackground.ignoresSafeArea(.container, edges: .bottom))
                .accessibilityHidden(true)
        }
    }
}
