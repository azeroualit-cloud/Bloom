import SwiftUI
import SwiftData
import UIKit

struct FramedImage: View {
    let data: Data?
    let framing: ImageFraming
    var zoomable = false
    var maximumPixel = 4096
    var contentMode: ContentMode = .fit
    @State private var image: UIImage?
    @State private var original: UIImage?
    @State private var finished = false
    var body: some View {
        Group {
            if let image {
                if zoomable { ZoomImage(image: image).accessibilityLabel("Immagine; pizzica per ingrandire") }
                else { Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode) }
            } else if finished { Label("Immagine non leggibile", systemImage: "photo.badge.exclamationmark") }
            else { ProgressView("Preparazione immagine…") }
        }.task(id: data) {
            finished = false
            let decoded = await CachedPreviewImage.decode(data, maximumPixel: maximumPixel)
            guard !Task.isCancelled else { return }
            original = decoded
            applyFraming()
            finished = true
        }
        .onChange(of: framing) { _, _ in applyFraming() }
    }
    private func applyFraming() {
        guard let original = original?.cgImage else { return }
        let rect = CGRect(x: Double(original.width) * framing.left, y: Double(original.height) * framing.top,
                          width: Double(original.width) * (1 - framing.left - framing.right),
                          height: Double(original.height) * (1 - framing.top - framing.bottom))
        image = UIImage(cgImage: original.cropping(to: rect) ?? original)
    }
}

private struct ZoomImage: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> ImageScrollView { ImageScrollView() }
    func updateUIView(_ view: ImageScrollView, context: Context) { view.show(image) }
}

private final class ImageScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var previousSize = CGSize.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        accessibilityIdentifier = "image-original"
        accessibilityLabel = "Immagine completa, pizzica per ingrandire"
        addSubview(imageView)
        showsVerticalScrollIndicator = false; showsHorizontalScrollIndicator = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2; addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func show(_ image: UIImage) {
        guard imageView.image !== image else { return }
        imageView.image = image
        zoomScale = 1; imageView.frame = CGRect(origin: .zero, size: image.size)
        previousSize = .zero; setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0 else { return }
        if previousSize != bounds.size {
            previousSize = bounds.size
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            minimumZoomScale = fit; maximumZoomScale = fit * 8; zoomScale = fit
            contentSize = imageView.frame.size
        }
        contentInset = UIEdgeInsets(top: max(0, (bounds.height - contentSize.height) / 2), left: max(0, (bounds.width - contentSize.width) / 2), bottom: 0, right: 0)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        accessibilityValue = "\(Int((zoomScale / max(minimumZoomScale, 0.001) * 100).rounded()))%"
        setNeedsLayout()
    }
    @objc private func doubleTap(_ sender: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.1 { setZoomScale(minimumZoomScale, animated: true) }
        else {
            let point = sender.location(in: imageView)
            let scale = min(maximumZoomScale, minimumZoomScale * 3)
            zoom(to: CGRect(x: point.x - bounds.width / scale / 2, y: point.y - bounds.height / scale / 2, width: bounds.width / scale, height: bounds.height / scale), animated: true)
        }
    }
}

struct ImageFramingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    var file: NoteFile? = nil
    @State private var framing: ImageFraming
    @State private var error: String?
    init(item: CapturedLink, file: NoteFile? = nil) { self.item = item; self.file = file; _framing = State(initialValue: file?.framing ?? (file == nil ? item.imageFraming : ImageFraming())) }
    var body: some View {
        NavigationStack {
            Form {
                Section { FramedImage(data: file?.data ?? item.attachmentData, framing: framing).frame(height: 260) }
                Section("Nascondi i bordi dello screenshot") {
                    slider("Alto", value: $framing.top, maximum: 0.9 - framing.bottom)
                    slider("Basso", value: $framing.bottom, maximum: 0.9 - framing.top)
                    slider("Sinistra", value: $framing.left, maximum: 0.9 - framing.right)
                    slider("Destra", value: $framing.right, maximum: 0.9 - framing.left)
                    Button("Mostra originale") { framing = ImageFraming() }
                    Text("L’originale resta intatto. L’inquadratura vale anche nella Libreria.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Inquadratura").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") {
                            do {
                                if var file { file.framing = framing; try LinkStore.updateNoteFile(file, for: item, in: context) }
                                else { try LinkStore.setImageFraming(framing, for: item, in: context) }
                                dismiss()
                            }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
        }
    }
    private func slider(_ title: String, value: Binding<Double>, maximum: Double) -> some View {
        VStack(alignment: .leading) { Text(title).font(.subheadline); Slider(value: value, in: 0...min(0.8, max(0.01, maximum))).accessibilityLabel(title) }
    }
}
