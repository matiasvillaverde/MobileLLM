import XCTest
@testable import VectorDB

final class MathTests: XCTestCase {

    func test_cosineSimilarity() {
        let a = [1.0, 2.0, 3.0]
        let b = [4.0, 5.0, 6.0]
        let magnitudeA = 3.7416573867739413
        let magnitudeB = 8.774964387392123

        let result = MathFunctions.cosineSimilarity(a, b, magnitudeA: magnitudeA, magnitudeB: magnitudeB)

        XCTAssertEqual(result, 0.9746318461970762, accuracy: 0.0001)
    }

}
