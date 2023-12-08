import Foundation

struct BytePair: Hashable {
    let a: String
    let b: String
    init(_ a: String, _ b: String) {
        self.a = a
        self.b = b
    }

    init(tuple: [String]) {
        a = tuple[0]
        b = tuple[1]
    }

    static func == (lhs: BytePair, rhs: BytePair) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
    }
}

private extension String {
    func ranges(of string: String, options: CompareOptions = .regularExpression) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var start = startIndex
        while let range = range(of: string, options: options, range: start ..< endIndex) {
            result.append(range)
            start = range.lowerBound < range.upperBound ? range.upperBound : index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

class Tokenizer {
    let bpeRanks: [BytePair: Int32]
    private let encoder: [String: Int32]
    private let decoder: [Int32: String]

    init(config: TokenizerConfig) {
        let bpeMergesTxt = try! String(contentsOf: config.merges)
        let arr = bpeMergesTxt.split(separator: "\n").map { String($0) }
        var bpeRanks: [BytePair: Int32] = [:]
        if arr.count>0 {
            for i in 1 ..< arr.count {
                let tuple = arr[i].split(separator: " ").map { String($0) }
                let bp = BytePair(tuple: tuple)
                bpeRanks[bp] = Int32(i - 1)
            }
        }
        self.bpeRanks = bpeRanks

        encoder = {
            let json = try! Data(contentsOf: config.vocab)
            let decoder = JSONDecoder()
            let vocab = try! decoder.decode([String: Int32].self, from: json)
            return vocab
        }()
        decoder = TokenizeUtils.invert(encoder)
    }

    func byteEncode(text: String) -> [String] {
        let RE = #"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"#
        let tokens = text.ranges(of: RE).map { String(text[$0]) }
        return tokens.map { token -> String in
            Array(token.utf8).map { byteEncoder[$0]! }.joined()
        }
    }

    private func getPairs(word: [String]) -> Set<BytePair> {
        var s = Set<BytePair>()
        for i in 0 ..< word.count - 1 {
            let bp = BytePair(
                word[i],
                word[i + 1]
            )
            s.insert(bp)
        }
        return s
    }

    func bpe(token: String) -> String {
        if token.count <= 1 {
            return token
        }

        var word = Array(token).map { String($0) }
        var pairs = Array(getPairs(word: word))

        while true {
            let bigrams = pairs.filter { bp -> Bool in bpeRanks[bp] != nil }
            if bigrams.count == 0 {
                break
            }
            let bigram = bigrams.min { bp1, bp2 -> Bool in
                bpeRanks[bp1]! < bpeRanks[bp2]!
            }!
            let first = bigram.a
            let second = bigram.b
            var newWord: [String] = []
            var i = 0
            while i < word.count {
                if let j = word[i ..< word.count].firstIndex(of: first) {
                    newWord.append(contentsOf: word[i ..< j])
                    i = j
                } else {
                    newWord.append(contentsOf: word[i ..< word.count])
                    break
                }

                if word[i] == first && i < word.count - 1 && word[i + 1] == second {
                    newWord.append(first + second)
                    i += 2
                } else {
                    newWord.append(word[i])
                    i += 1
                }
            }
            word = newWord
            if word.count == 1 {
                break
            } else {
                pairs = Array(getPairs(word: word))
            }
        }
        return word.joined(separator: " ")
    }

    func appendBOS(tokens: [Int32]) -> [Int32] {
        return [encoder["<s>"]!] + tokens
    }

    func appendEOS(tokens: [Int32]) -> [Int32] {
        return tokens + [encoder["</s>"]!]
    }

    func stripBOS(tokens: [Int32]) -> [Int32] {
        if tokens[0] == encoder["<s>"]! {
            return Array(tokens[1 ..< tokens.count])
        }
        return tokens
    }

    func stripEOS(tokens: [Int32]) -> [Int32] {
        if tokens[tokens.count - 1] == encoder["</s>"]! {
            return Array(tokens[0 ..< tokens.count - 1])
        }
        return tokens
    }

    func tokenize(text: String) -> [String] {
        var tokens: [String] = []
        for token in byteEncode(text: text) {
            let xx = bpe(token: token).split(separator: " ").map { String($0) }
            tokens.append(contentsOf: xx)
        }
        return tokens
    }

    func encode(text: String) -> [Int32] {
        return tokenize(text: text).map {
            let encoded = encoder[$0]
            if encoded != nil {return encoded!} else {return 0}
        }
    }

    func decode(tokens: [Int32]) -> String {
        let text = tokens.map {
                let decoded=decoder[$0]
                if decoded != nil {return decoded!} else {return ""}
            }
            .joined(separator: "")
        let utfCodepoints = text.map { byteDecoder[String($0)]! }
        return String(decoding: utfCodepoints, as: UTF8.self)
    }
}

/**
    TokenizerConfig is a struct that contains the URLs to the vocab.json and merges.txt files in the bundle.
    - Parameters:
        - vocab: resource URL to vocab.json file in the bundle (e.g. Bundle.module.url(forResource: "vocab", withExtension: "json")!)
        - merges: resource URL to merges.txt file in the bundle (e.g. Bundle.module.url(forResource: "merges", withExtension: "txt")!)
*/
struct TokenizerConfig {
    let vocab: URL
    let merges: URL
}

struct TokenizeUtils {
    /// Time a block in ms
    static func time<T>(label: String, _ block: () -> T) -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = block()
        let diff = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[\(label)] \(diff)ms")
        return result
    }

    /// Time a block in seconds and return (output, time)
    static func time<T>(_ block: () -> T) -> (T, Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = block()
        let diff = CFAbsoluteTimeGetCurrent() - startTime
        return (result, diff)
    }

    /// Return unix timestamp in ms
    static func dateNow() -> Int64 {
        // Use `Int` when we don't support 32-bits devices/OSes anymore.
        // Int crashes on iPhone 5c.
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Clamp a val to [min, max]
    static func clamp<T: Comparable>(_ val: T, _ vmin: T, _ vmax: T) -> T {
        return min(max(vmin, val), vmax)
    }

    /// Fake func that can throw.
    static func fakeThrowable<T>(_ input: T) throws -> T {
        return input
    }

    /// Substring
    static func substr(_ s: String, _ r: Range<Int>) -> String? {
        let stringCount = s.count
        if stringCount < r.upperBound || stringCount < r.lowerBound {
            return nil
        }
        let startIndex = s.index(s.startIndex, offsetBy: r.lowerBound)
        let endIndex = s.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return String(s[startIndex ..< endIndex])
    }

    /// Invert a (k, v) dictionary
    static func invert<K, V>(_ dict: [K: V]) -> [V: K] {
        var inverted: [V: K] = [:]
        for (k, v) in dict {
            inverted[v] = k
        }
        return inverted
    }
}
