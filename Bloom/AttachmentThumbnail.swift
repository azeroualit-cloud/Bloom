import SwiftUI
import ImageIO
import UIKit

/// Shared bounded image preview for the local viewer and rediscovery cards.
@MainActor
struct AttachmentThumbnail: View {
    let item: CapturedLink
    let maximumPixelSize: Int
    @State private var image: UIImage?
    @State private var finished = false
    @State private var error: String?

    init(item: CapturedLink, maximumPixelSize: Int = 2048) {
        self.item = item
        self.maximumPixelSize = maximumPixelSize
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityLabel(item.displayTitle)
            } else if !finished { ProgressView("Caricamento immagine…") }
            else { Label(error ?? "Anteprima non disponibile", systemImage: "photo.badge.exclamationmark") }
        }
        .task(id: item.id) {
            finished = false
            defer { finished = true }
            guard let data = item.attachmentData else { error = ImportError.missingData.localizedDescription; return }
            let pixelLimit = maximumPixelSize
            let thumbnail = await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: pixelLimit
                      ] as CFDictionary) else { return Optional<UIImage>.none }
                return UIImage(cgImage: cgImage)
            }.value
            guard !Task.isCancelled else { return }
            image = thumbnail
            if thumbnail == nil { error = ImportError.unreadableImage.localizedDescription }
        }
    }
}
