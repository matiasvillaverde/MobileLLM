import XCTest
@testable import LLM

final class RWKVTests: XCTestCase {

    private let model = try! RWKV(from: Bundle.module.url(forResource: "RWKV", withExtension: "bin")!, parameters: .default)

    func testOpenRWKVModel() async throws {
        let result = try await model.predict("Hola")
        XCTAssertEqual(result.0, "Hello! How can I assist you? Please tell me a bit about your question.")
    }

    func test_write_poem() async throws {
        let result = try await model.predict("Write a poem")
        XCTAssertEqual(result.0, """
                       A poem of love,
                       A piece to say,
                       A feeling,
                       A thought,
                       A melody,
                       A story,
                       A tale,
                       A tale to tell,
                       A tale to tell.
                       """)
    }
}
