import Accelerate
import CoreML
import NaturalLanguage
import SwiftData

public final class VectorDB {

    public static let shared = VectorDB()
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)!
    private let container = try! ModelContainer(for: Document.self)

    private init() {}

    /// Adds a document to the VectorDB.
    ///
    /// - Parameters:
    ///   - id: The ID of the document. If not provided, a new UUID will be generated.
    ///   - text: The text content of the document.
    ///
    /// - Throws: `DatabaseError.failedToCalculateEmbedding` if the embedding vector cannot be calculated.
    @MainActor public func addDocument(id: UUID = UUID(), text: String) throws {
        guard let vector = embedding.vector(for: text) else {
            throw DatabaseError.failedToCalculateEmbedding
        }

        let document = Document(
            id: id,
            text: text,
            embedding: vector
        )

        save(document: document)
    }

    /**
     Deletes a document from the VectorDB.

     - Parameters:
        - document: The identifier of the document to delete.

     - Throws: An error if the deletion fails.

     - Note: This method operates on the main actor.
     */
    @MainActor public func delete(document: String) throws {
        let context = container.mainContext

        var fetchDescriptor = FetchDescriptor<Document>(predicate: #Predicate { $0.text == document })
        fetchDescriptor.includePendingChanges = true

        guard let documentToDelete = try container.mainContext.fetch(fetchDescriptor).first else {
            throw DatabaseError.canNotFindDocumentToDelete(document)
        }

        context.delete(documentToDelete)
        try context.save()
    }

    /**
    Clears all documents in the VectorDB.
     */
    @MainActor public func clear() throws {
        try container.mainContext.delete(model: Document.self)
    }

    /**
     Searches for results in the VectorDB based on the provided search term.

     - Parameters:
        - searchTerm: The term to search for.
        - limit: The maximum number of search results to return. Default is 10.
        - similarityThreshold: The similarity threshold for search results. Default is nil.

     - Returns: An array of SearchResult objects matching the search term.
     - Throws: An error if the search operation fails.
     */
    @MainActor public func search(
        searchTerm: String,
        limit: Int = 10,
        similarityThreshold: Double = 0.5
    ) throws -> [SearchResult] {
        // Calculate the query vector for the search term
        guard let searchTermVector = embedding.vector(for: searchTerm) else {
            throw DatabaseError.failedToCalculateEmbedding
        }

        // Compute the magnitude of the search term vector
        let searchTermVectorMagnitude = sqrt(searchTermVector.reduce(0) { $0 + $1 * $1 })

        // Search documents that are similar
        let documents = try loadDocuments()

        let searchResults: [SearchResult] = documents.compactMap { document in
            computeSimilarity(
                document: document,
                searchTermVector: searchTermVector,
                searchTermVectorMagnitude: searchTermVectorMagnitude,
                similarityThreshold: similarityThreshold
            )
        }

        // Sort, limit, and return the search results
        return Array(searchResults.sorted(by: { $0.score > $1.score }).prefix(limit))
    }

    private func computeSimilarity(
        document: Document,
        searchTermVector: [Double],
        searchTermVectorMagnitude: Double,
        similarityThreshold: Double = 0.5
    ) -> SearchResult? {
        let documentVectorMagnitude = sqrt(document.embedding.reduce(0) { $0 + $1 * $1 })
        let cosineSimilarity = MathFunctions.cosineSimilarity(
            searchTermVector,
            document.embedding,
            magnitudeA: searchTermVectorMagnitude,
            magnitudeB: documentVectorMagnitude
        )

        if cosineSimilarity >= similarityThreshold {
            return SearchResult(id: document.id, text: document.text, score: cosineSimilarity)
        }

        return nil
    }

    @MainActor private func loadDocuments() throws -> [Document] {
        let context = container.mainContext

        var documents = FetchDescriptor<Document>()
        documents.includePendingChanges = true

        return try context.fetch(documents)
    }

    @MainActor private func save(document: Document) {
        container.mainContext.insert(document)
    }
}
