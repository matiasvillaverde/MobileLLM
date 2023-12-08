import Foundation
import CoreLLM

public enum RWKVError: Error {
    case failedToInitializeContext
    case failedToEvaluate
    case emptyInput
    case contextLimit
}

public protocol Model {
    func predict(_ input: String) async throws -> (String, Double)
}

final public class RWKV: Model {

    private let tokenizerFromString: Tokenizer
    private let tokenizerToString: Tokenizer

    // Represented the model as a C pointer
    private var context: OpaquePointer?

    private var pointerToLogits: UnsafeMutablePointer<Float>?
    private var pointerToStateIn: UnsafeMutablePointer<Float>?
    private var pointerToStateOut: UnsafeMutablePointer<Float>?

    // Used for replying
    private let parameters: ModelParameters
    // Used to keep old context until it needs to be rotated or purge out for new tokens
    private var past: [[ModelToken]] = [] // Will house both queries and responses in order
    private var nPast: Int32 = 0

    public init(from url: URL, parameters: ModelParameters) throws {

        // Parameters
        self.parameters = parameters

        // Get Tokenizers
        let resources = get_core_bundle_path()

        let configFrom = TokenizerConfig(
            vocab: URL(fileURLWithPath: resources! + "/tokenizers/20B_tokenizer_vocab.json"),
            merges: URL(fileURLWithPath: resources! + "/tokenizers/20B_tokenizer_merges.txt")
        )
        let configTo = TokenizerConfig(
            vocab: URL(fileURLWithPath: resources! + "/tokenizers/20B_tokenizer_vocab.json"),
            merges: URL(fileURLWithPath: resources! + "/tokenizers/20B_tokenizer_merges.txt")
        )

        self.tokenizerFromString = Tokenizer(config: configFrom)
        self.tokenizerToString = Tokenizer(config: configTo)

        // Load model
        try self.loadModel(from: url)
        try self.initializeLogits()
    }

    // Refactored

    /**
     Loads a model from a given path.

     - Parameters:
    - path: The URL of the model to load.

     - Throws: An error if the model fails to load.

     - Returns: `true` if the model was loaded successfully, `false` otherwise.
     */
    private func loadModel(from url: URL) throws {
        guard let context = rwkv_init_from_file(url.path, UInt32(parameters.numberOfThreads)) else {
            throw RWKVError.failedToInitializeContext
        }
        self.context = context
    }

    /**
    Initializes the logits for the model.

    This function allocates memory for the logits and state,
    initializes the state, and evaluates the model with the beginning and end of sentence tokens.

    - Throws: An `RWKVError.failedToEvaluate` error if the model fails to evaluate.
     */
    private func initializeLogits() throws {
        let vocabularySize = rwkv_get_logits_len(self.context)
        let stateSize = rwkv_get_state_len(self.context)

        self.pointerToLogits = UnsafeMutablePointer<Float>.allocate(capacity: Int(vocabularySize))
        self.pointerToStateIn = UnsafeMutablePointer<Float>.allocate(capacity: Int(stateSize))
        self.pointerToStateOut = UnsafeMutablePointer<Float>.allocate(capacity: Int(stateSize))

        rwkv_init_state(self.context, pointerToStateIn)

        let inputs = [gpt_base_token_bos(), gpt_base_token_eos()]
        evaluate(inputBatch: inputs)
    }

    /**
    Evaluates the model with a batch of input tokens.

    This function splits the input batch into chunks of 64 tokens each, and evaluates the model with each chunk.

    - Parameter inputBatch: An array of input tokens to evaluate.

    Note: The function currently does not return any value or throw errors. 
    You might want to add error handling code to make the function more robust.
     */
    func evaluate(inputBatch: [ModelToken]) {
        let chunkSize = 64
        let tokenChunks = inputBatch.chunked(into: chunkSize)

        for chunk in tokenChunks {
            rwkv_eval_sequence(
                    context,
                    chunk.map { UInt32($0) },
                    Int(Int32(chunk.count)),
                    self.pointerToStateIn,
                    self.pointerToStateIn,
                    self.pointerToLogits
                )
        }
    }

    private func tokenize(input: String) throws -> [ModelToken] {

        var formatedInput = self.parameters.customPromptFormat.replacingOccurrences(of: "{{prompt}}", with: input)
        formatedInput = formatedInput.replacingOccurrences(of: "\\n", with: "\n")

        let tokens = tokenizerFromString.encode(text: formatedInput)

        guard !tokens.isEmpty else {
            throw RWKVError.emptyInput
        }

        guard tokens.count < parameters.maximumContext else {
            throw ModelError.inputTooLong
        }

        past.append(tokens)

        return tokens
    }

    private func evaluateBatches(tokens: [ModelToken]) {
        var tokens = tokens
        var inputBatch: [ModelToken] = []
        while tokens.count > 0 {
            inputBatch.removeAll()
            // Move tokens to batch
            let evalCount = min(tokens.count, Int(parameters.numberOfBatch))
            inputBatch.append(contentsOf: tokens[0 ..< evalCount])

            tokens.removeFirst(evalCount)
            if nPast + Int32(inputBatch.count) >= parameters.maximumContext {
                nPast = 0
                evaluate(inputBatch: [gpt_base_token_eos()])
            }
            evaluate(inputBatch: inputBatch)
            nPast += Int32(evalCount)
        }
    }

    public func predict(_ input: String) async throws -> (String, Double) {
        let inputTokens = try tokenize(input: input)
        evaluateBatches(tokens: inputTokens)

        // Output
        var outputRepeatTokens: [ModelToken] = []
        var outputTokens: [ModelToken] = []
        var output = [String]()
        var time: Double = 0.0

        // Loop until we get token eos or a stop token
        outerLoop: while true {
            // Pull a generation from context
            var outputToken: Int32 = -1
            try ExceptionCather.catchException {
                outputToken = calculateToken(
                    lastTokens: &outputRepeatTokens
                )
            }

            // Add output token to array
            outputTokens.append(outputToken)

            // Repeat tokens update
            outputRepeatTokens.append(outputToken)
            if outputRepeatTokens.count > parameters.repeatLastNumber {
                outputRepeatTokens.removeFirst()
            }

            // Convert token to string
            let prediction = tokenizerToString.decode(tokens: [outputToken])

            // Calculate how long it took to create
            let (_, timeTaken) = Utils.time {
                return prediction
            }
            time = timeTaken

            // Here return the prediction and the time taken and continue with the loop

            // Check for EOS to finish the loop
            guard outputToken != gpt_base_token_eos() else {
                break
            }

            // Check that the token is not the reverse prompt
            // TODO: This is a bit a hacky, I need to understand why sometimes it continues without an EOS

            for stopWord in parameters.stopPrompts {
                if prediction == stopWord || prediction.hasSuffix(stopWord) {
                    break outerLoop
                }
            }

            // Only if it is a valid token we add it
            output.append(prediction)

            // Check if the context is under the limit
            guard nPast <= parameters.maximumContext - 4 else {
                nPast /= 2
                outputToken = gpt_base_token_eos()
                evaluate(inputBatch: [outputToken])
                throw RWKVError.contextLimit
            }

            evaluate(inputBatch: [outputToken])

            // Increment past count
            nPast += 1
        }

        // Update past with most recent response
        past.append(outputTokens) // TODO: also clean the tokens
        return (clean(output: output).joined(), time)
    }

    private func clean(output: [String]) -> [String] {
        guard var message = output.first else { return output }

        // Remove the first character because it is a space
        message.removeFirst()
        var newOutput = output
        newOutput[0] = message

        // Remove last items if they are new lines
        while newOutput.last == "\n" {
            newOutput.removeLast()
        }

        return newOutput
    }

    // Mark - Prompting

    private func calculateToken(lastTokens: inout [ModelToken]) -> ModelToken {

        // Model input context size
        let contextSize: Int32 = 4096
        let vocabularySize = Int32(rwkv_get_logits_len(self.context))

        // Determine the values of topK and repeatLast based on provided parameters.
        let topK = parameters.topK <= 0 ? vocabularySize : parameters.topK
        let repeatLast = parameters.repeatLastNumber < 0 ? contextSize : parameters.repeatLastNumber

        // Determine the size of the model's vocabulary.
        guard let probabilityDistribution = pointerToLogits else {
            print("Error: The probability distribution returned is nil.")
            return 0
        }

        // Create a list to store all potential tokens.
        var tokensList = [llama_dadbed9_token_data]()
        tokensList = (0..<vocabularySize).map { id in
            llama_dadbed9_token_data(id: id, logit: probabilityDistribution[Int(id)], p: 0.0)
        }

        var organizedTokens = llama_dadbed9_token_data_array(
            data: tokensList.mutPtr,
            size: tokensList.count,
            sorted: false
            )

        // Tempt potential penalties.
        let penaltyToken = Int(13)
        let penaltyLogit = probabilityDistribution[penaltyToken]
        let lastPenaltyRepeat = min(min(Int32(lastTokens.count), repeatLast), contextSize)

        // Apply repetition and frequency penalties.
        llama_dadbed9_sample_repetition_penalty(
            &organizedTokens,
            lastTokens.mutPtr.advanced(by: lastTokens.count - Int(repeatLast)),
            Int(repeatLast), parameters.repeatPenalty)
        llama_dadbed9_sample_frequency_and_presence_penalties(
            context,
            &organizedTokens,
            lastTokens.mutPtr.advanced(by: lastTokens.count - Int(repeatLast)),
            Int(lastPenaltyRepeat), parameters.penaltyFrequence, parameters.penaltyPresence)

        // If the penalty for NL is disabled, restore the original logit.
        if !parameters.penalizeNL {
            probabilityDistribution[penaltyToken] = penaltyLogit
        }

        // Temperature sampling
        llama_dadbed9_sample_top_k(context, &organizedTokens, topK, 1)
        llama_dadbed9_sample_tail_free(context, &organizedTokens, parameters.tfsZ, 1)
        llama_dadbed9_sample_typical(context, &organizedTokens, parameters.typicalP, 1)
        llama_dadbed9_sample_top_p(context, &organizedTokens, parameters.topP, 1)
        llama_dadbed9_sample_temperature(context, &organizedTokens, parameters.temperature)
        return llama_dadbed9_sample_token(context, &organizedTokens)
    }
}
