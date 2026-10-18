import Foundation
import UniformTypeIdentifiers
import CryptoKit

enum ContentKind: String, Sendable {
    case link, text, image, file
    var label: String {
        switch self {
        case .link: return "Link"
        case .text: return "Testo"
        case .image: return "Immagine"
        case .file: return "File"
        }
    }
    var symbol: String {
        switch self {
        case .link: return "link"
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

enum ImportError: LocalizedError {
    case tooLarge, invalidFile, emptyText, missingData, unreadableImage
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Il contenuto supera il limite di 25 MB per elemento."
        case .invalidFile: return "Questo elemento non è un file leggibile. Seleziona un altro file."
        case .emptyText: return "Inserisci del testo da salvare."
        case .missingData: return "Il contenuto locale non è disponibile. L’originale non è stato modificato."
        case .unreadableImage: return "Non è possibile generare un’anteprima di questa immagine."
        }
    }
}

struct AttachmentPayload: Sendable {
    let data: Data
    let name: String
    let type: String
    let kind: ContentKind
    let fingerprint: String
    init(data: Data, name: String, type: String, kind: ContentKind) {
        self.data = data
        self.name = name
        self.type = type
        self.kind = kind
        self.fingerprint = ContentFingerprint.make(data, kind: kind)
    }
}

enum ContentFingerprint {
    static func make(_ data: Data, kind: ContentKind) -> String {
        kind.rawValue + ":" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum AttachmentLoader {
    static let maximumBytes = 25 * 1024 * 1024

    static func readCoordinated(_ url: URL) throws -> AttachmentPayload {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<AttachmentPayload, Error>?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readableURL in
            result = Result { try read(readableURL) }
        }
        if let result { return try result.get() }
        if let coordinationError { throw coordinationError }
        throw ImportError.invalidFile
    }

    static func read(_ url: URL) throws -> AttachmentPayload {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey])
        guard values.isRegularFile == true else { throw ImportError.invalidFile }
        if let size = values.fileSize, size > maximumBytes { throw ImportError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: min(64 * 1024, maximumBytes + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
            guard data.count <= maximumBytes else { throw ImportError.tooLarge }
        }
        let type = values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .data
        return AttachmentPayload(data: data, name: url.lastPathComponent, type: type.identifier,
                                 kind: type.conforms(to: .image) ? .image : .file)
    }
}
