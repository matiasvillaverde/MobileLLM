import XCTest
@testable import Facade
@testable import LLM

final class MobileLLMTests: XCTestCase {

    var mobileLLM: MobileLLM!

    @MainActor override func setUp() {
        super.setUp()
        mobileLLM = MobileLLM.shared
        let url = URL(fileURLWithPath: "/path/to/model")
        let parameters = ModelParameters.default
        do {
            try mobileLLM.load(model: url, parameters: parameters, type: .testing)
        } catch {
            XCTAssert(true, error.localizedDescription)
        }
    }

    @MainActor override func tearDown() async throws {
        try await super.tearDown()
        try await mobileLLM.clean()
        mobileLLM = nil
    }

    @MainActor func testAdd() throws {
        try mobileLLM.add(document: "this is a test")
    }

    @MainActor func testDelete() throws {
        try mobileLLM.add(document: "this is a test")
        try mobileLLM.delete(document: "this is a test")
    }

    func testAsk() async throws {
        let question = "Test question"
        let (answer, score) = try await mobileLLM.ask(question: question)

        XCTAssertEqual(answer, "Test reply")
        XCTAssertEqual(score, 0.0)
    }

    func testPrompt() async throws {
        try await mobileLLM.add(document: "My dog is eating the shoes")
        let prompt = try await mobileLLM.prompt(question: "What is eating your dog?", similarityThreshold: 0.5)

        XCTAssertEqual(prompt, "###Question: What is eating your dog? ###Answer: My dog is eating the shoes")
    }

    func testMultipleResultsInPrompt() async throws {
        try await mobileLLM.add(document: "My dog is eating everything")
        try await mobileLLM.add(document: "My dog is called Freja and is eating your shoes")
        let prompt = try await mobileLLM.prompt(question: "What is eating your dog?", similarityThreshold: 0.5)

        XCTAssertEqual(prompt, "###Question: What is eating your dog? ###Answer: My dog is eating everything. My dog is called Freja and is eating your shoes")
    }

    func test_dog_name() async throws {
        try await mobileLLM.add(document: "The dog is called Freja")
        let url = Bundle.module.url(forResource: "RWKV", withExtension: "bin")!
        try mobileLLM.load(model: url, parameters: .default)

        let result = try await mobileLLM.ask(question: "How is the dog called?")

        XCTAssertEqual(result.0, "The dog's name is Freja.")
    }
}
