import LLM
import VectorDB
import Foundation

public enum MobileLLMError: Error {
    case failedToFindCollection(String)
    case modelNotLoaded
}

public enum ModelType {
    case rwkv
    case testing
}

final public class MobileLLM {

    public static let shared = MobileLLM()
    private init() {}

    private var model: Model?

    public func load(model url: URL, parameters: ModelParameters, type: ModelType = .rwkv) throws {
        switch type {
        case .rwkv:
            model = try RWKV(from: url, parameters: parameters)
        case .testing:
            model = TestingModel()
        }
    }

    @MainActor public func add(document: String) throws {
        try VectorDB.shared.addDocument(text: document)
    }

    @MainActor public func delete(document: String) throws {
        try VectorDB.shared.delete(document: document)
    }

    public func ask(question: String, similarityThreshold: Double = 0.5) async throws -> (String, Double) {
        guard let model = self.model else { throw MobileLLMError.modelNotLoaded }
        let prompt = try await prompt(question: question, similarityThreshold: similarityThreshold)
        return try await model.predict(prompt)
    }

    public func prompt(question: String, similarityThreshold: Double) async throws -> String {
        let result = try await VectorDB.shared.search(searchTerm: question, similarityThreshold: similarityThreshold)

        // If result is empty, we just ask the question
        guard !result.isEmpty else {
            return "###Question: \(question)"
        }

        // Add all the results as part of the prompt to the model
        let embedding = result.map { $0.text }.joined(separator: ". ")

        return "###Question: \(question) ###Answer: \(embedding)"
    }

    public func clean() async throws {
        try await VectorDB.shared.clear()
    }

}
