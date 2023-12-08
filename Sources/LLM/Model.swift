import Foundation

typealias ModelToken = Int32

public struct ModelParameters {

    let maximumContext: Int32
    let parts: Int32
    let seed: UInt32
    let numberOfThreads: Int32
    let customPromptFormat: String
    let stopPrompts: [String]
    let numberOfBatch: Int32
    let temperature: Float
    let topK: Int32
    let topP: Float
    let tfsZ: Float
    let typicalP: Float
    let repeatPenalty: Float
    let repeatLastNumber: Int32
    let penaltyFrequence: Float
    let penaltyPresence: Float
    let penalizeNL: Bool

    static let `default`: ModelParameters = ModelParameters(
        maximumContext: 4096,
        parts: -1,
        seed: 4294967295,
        numberOfThreads: 12,
        customPromptFormat: "USER: {{prompt}}\n\nAssistant:",
        stopPrompts: ["USER", "User"],
        numberOfBatch: 512,
        temperature: 0.5,
        topK: 40,
        topP: 0.95,
        tfsZ: 1,
        typicalP: 1,
        repeatPenalty: 1.1,
        repeatLastNumber: 64,
        penaltyFrequence: 0,
        penaltyPresence: 0,
        penalizeNL: false
    )

    /**
     Initializes a new instance of the Model struct.
     
     - Parameters:
         - maximumContext: The maximum context length.
         - parts: The number of parts.
         - seed: The seed value.
         - numberOfThreads: The number of threads.
         - customPromptFormat: The custom prompt format.
         - stopPrompts: The stop prompts.
         - numberOfBatch: The number of batches.
         - temperature: The temperature value.
         - topK: The top K value.
         - topP: The top P value.
         - tfsZ: The TFS Z value.
         - typicalP: The typical P value.
         - repeatPenalty: The repeat penalty value.
         - repeatLastNumber: The repeat last number value.
         - penaltyFrequence: The penalty frequency value.
         - penaltyPresence: The penalty presence value.
         - penalizeNL: A boolean value indicating whether to penalize newlines.
     */
    public init(
        maximumContext: Int32,
        parts: Int32,
        seed: UInt32,
        numberOfThreads: Int32,
        customPromptFormat: String,
        stopPrompts: [String],
        numberOfBatch: Int32,
        temperature: Float,
        topK: Int32,
        topP: Float,
        tfsZ: Float,
        typicalP: Float,
        repeatPenalty: Float,
        repeatLastNumber: Int32,
        penaltyFrequence: Float,
        penaltyPresence: Float,
        penalizeNL: Bool
    ) {
        self.maximumContext = maximumContext
        self.parts = parts
        self.seed = seed
        self.numberOfThreads = numberOfThreads
        self.customPromptFormat = customPromptFormat
        self.stopPrompts = stopPrompts
        self.numberOfBatch = numberOfBatch
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.tfsZ = tfsZ
        self.typicalP = typicalP
        self.repeatPenalty = repeatPenalty
        self.repeatLastNumber = repeatLastNumber
        self.penaltyFrequence = penaltyFrequence
        self.penaltyPresence = penaltyPresence
        self.penalizeNL = penalizeNL
    }
}

public enum ModelError: Error {
    case modelNotFound(String)
    case inputTooLong
    case failedToEval
    case contextLimit
}
