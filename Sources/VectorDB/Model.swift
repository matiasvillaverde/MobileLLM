import Foundation
import SwiftData

@Model
class Document {
    @Attribute(.unique) let id: UUID
    let text: String
    let embedding: [Double]
    let magnitude: Double

    init(id: UUID = UUID(), text: String, embedding: [Double]) {
        self.id = id
        self.text = text
        self.embedding = embedding
        self.magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
    }
}

public struct SearchResult {
    public let id: UUID
    public let text: String
    public let score: Double
}

public enum DatabaseError: Error {
    case fileNotFound
    case loadFailed(String)
    case failedToCalculateEmbedding
    case canNotFindDocumentToDelete(String)
}
