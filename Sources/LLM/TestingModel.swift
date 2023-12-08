import Foundation

final public class TestingModel: Model {
    public var prediction: (String, Double)

    public init(prediction: (String, Double) = ("Test reply", 0.0) ) {
        self.prediction = prediction
    }

    public func predict(_ input: String) async throws -> (String, Double) {
        prediction
    }
}
