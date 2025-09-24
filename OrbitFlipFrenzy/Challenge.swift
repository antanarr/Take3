import Foundation

public struct Challenge: Codable, CustomStringConvertible {
    public let seed: UInt32
    public let targetScore: Int

    public init(seed: UInt32, targetScore: Int) {
        self.seed = seed
        self.targetScore = max(0, targetScore)
    }

    public func generateLink() -> URL? {
        URL(string: "orbitflip://challenge?seed=\(seed)&score=\(targetScore)")
    }

    public var description: String {
        "Challenge(seed: \(seed), targetScore: \(targetScore))"
    }
}
