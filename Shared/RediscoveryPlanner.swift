import Foundation

/// Metadata only: planning never reads attachment bytes or opens a web page.
struct RediscoveryCandidate {
    let id: UUID
    let kind: ContentKind
    let collectionID: UUID?
    let host: String?
    let isArchived: Bool
}

enum RediscoveryPlanner {
    static let maximumItems = 30

    static func select(_ candidates: [RediscoveryCandidate], day: Int, round: Int = 0) -> [UUID] {
        var used = Set<UUID>()
        var remaining = candidates.filter { !$0.isArchived && used.insert($0.id).inserted }
        remaining.sort {
            let left = rank($0.id, day: day, round: round)
            let right = rank($1.id, day: day, round: round)
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }
        var selected: [RediscoveryCandidate] = []
        while !remaining.isEmpty && selected.count < maximumItems {
            let recent = selected.suffix(2)
            var bestIndex = 0
            var bestPenalty = Int.max
            for (index, candidate) in remaining.enumerated() {
                let penalty = recent.reduce(0) { total, previous in
                    total + (candidate.kind == previous.kind ? 3 : 0)
                        + (candidate.collectionID != nil && candidate.collectionID == previous.collectionID ? 2 : 0)
                        + (candidate.host != nil && candidate.host == previous.host ? 2 : 0)
                }
                if penalty < bestPenalty { bestIndex = index; bestPenalty = penalty }
                if penalty == 0 { break }
            }
            selected.append(remaining.remove(at: bestIndex))
        }
        return selected.map(\.id)
    }

    private static func rank(_ id: UUID, day: Int, round: Int) -> UInt64 {
        // Stable across launches; Swift Hasher deliberately changes between processes.
        var value: UInt64 = 14695981039346656037
        for byte in "\(day):\(round):\(id.uuidString)".utf8 {
            value = (value ^ UInt64(byte)) &* 1099511628211
        }
        return value
    }
}
