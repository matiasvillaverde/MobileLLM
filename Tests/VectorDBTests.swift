import XCTest
@testable import VectorDB

final class VectorDBTests: XCTestCase {

    @MainActor override func setUpWithError() throws {
        try super.setUpWithError()
        try VectorDB.shared.clear()
    }

    func test_add_document() async throws {
        try await VectorDB.shared.addDocument(text: "This is a test document")

        // Verify that the document is added
        let result = try await VectorDB.shared.search(searchTerm: "test")
        XCTAssertEqual(result.first?.text, "This is a test document")
        XCTAssertEqual(result.count, 1)
    }

    func test_delete_document() async throws {
        try await VectorDB.shared.addDocument(text: "This is a test document")
        try await VectorDB.shared.delete(document: "This is a test document")

        // Verify that the document is deleted
        let result = try await VectorDB.shared.search(searchTerm: "This is a test document")
        XCTAssertEqual(result.count, 0)
    }

    func test_search_only_2_results() async throws {
        try await VectorDB.shared.addDocument(text: "This is a test document")
        try await VectorDB.shared.addDocument(text: "This is another test document")
        try await VectorDB.shared.addDocument(text: "Horse is blue")

        let result = try await VectorDB.shared.search(searchTerm: "test", similarityThreshold: 0.3)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.text, "This is a test document")
        XCTAssertEqual(result.last?.text, "This is another test document")
    }

}
