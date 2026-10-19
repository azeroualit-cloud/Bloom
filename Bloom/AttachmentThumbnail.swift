import SwiftUI
import ImageIO
import UIKit

/// Shared bounded image preview for the local viewer and rediscovery cards.
@MainActor
struct AttachmentThumbnail: View {
    let item: CapturedLink
    let maximumPixelSize: Int
    var contentMode: ContentMode = .fit
    @State private var image: UIImage?
    @State private var finished = false
    @State private var error: String?

    init(item: CapturedLink, maximumPixelSize: Int = 2048, contentMode: ContentMode = .fit) {
        self.item = item
        self.maximumPixelSize = maximumPixelSize
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    .accessibilityLabel(item.displayTitle)
            } else if !finished { ProgressView("Caricamento immagine…") }
            else { Label(error ?? "Anteprima non disponibile", systemImage: "photo.badge.exclamationmark") }
        }
        .task(id: "\(item.id)-\(item.imageFraming)") {
            finished = false
            defer { finished = true }
            guard let data = item.attachmentData else { error = ImportError.missingData.localizedDescription; return }
            let pixelLimit = maximumPixelSize
            let framing = item.imageFraming
            let thumbnail = await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: pixelLimit
                      ] as CFDictionary) else { return Optional<UIImage>.none }
                let rect = CGRect(x: Double(cgImage.width) * framing.left, y: Double(cgImage.height) * framing.top,
                                  width: Double(cgImage.width) * (1 - framing.left - framing.right),
                                  height: Double(cgImage.height) * (1 - framing.top - framing.bottom))
                return UIImage(cgImage: cgImage.cropping(to: rect) ?? cgImage)
            }.value
            guard !Task.isCancelled else { return }
            image = thumbnail
            if thumbnail == nil { error = ImportError.unreadableImage.localizedDescription }
        }
    }
}
