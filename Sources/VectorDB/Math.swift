import Accelerate

/// A collection of math functions.
enum MathFunctions {

    /// Calculates the cosine similarity between two vectors.
    ///
    /// - Parameters:
    ///   - a: The first vector.
    ///   - b: The second vector.
    ///   - magnitudeA: The magnitude of vector `a`.
    ///   - magnitudeB: The magnitude of vector `b`.
    /// - Returns: The cosine similarity between the two vectors.
    static func cosineSimilarity(_ a: [Double], _ b: [Double], magnitudeA: Double, magnitudeB: Double) -> Double {
        var result = 0.0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(a.count))
        return result / (magnitudeA * magnitudeB)
    }
}
