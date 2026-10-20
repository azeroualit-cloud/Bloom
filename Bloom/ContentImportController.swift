import Foundation
import CoreTransferable

struct ImportedPhoto: Transferable, Sendable {
    let payload: AttachmentPayload
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            ImportedPhoto(payload: try AttachmentLoader.read(received.file))
        }
        FileRepresentation(importedContentType: .image) { received in
            ImportedPhoto(payload: try AttachmentLoader.read(received.file))
        }
    }
}
