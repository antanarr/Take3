import Foundation

public struct ChallengeLinkBundle {
    public let deepLink: URL
    public let universalLink: URL

    public var shareItems: [Any] {
        [universalLink, deepLink]
    }
}

public struct Challenge: Codable, CustomStringConvertible {
    public let seed: UInt32
    public let targetScore: Int

    public init(seed: UInt32, targetScore: Int) {
        self.seed = seed
        self.targetScore = max(0, targetScore)
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let seedValue = components.queryItems?.first(where: { $0.name == "seed" })?.value,
              let scoreValue = components.queryItems?.first(where: { $0.name == "score" })?.value,
              let parsedSeed = UInt32(seedValue),
              let parsedScore = Int(scoreValue) else {
            return nil
        }
        self.init(seed: parsedSeed, targetScore: parsedScore)
    }

    public func generateLinkBundle() -> ChallengeLinkBundle? {
        guard let deepLink = URL(string: "orbitflip://challenge?seed=\(seed)&score=\(targetScore)") else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "orbitflipfrenzy.fake"
        components.path = "/challenge"
        components.queryItems = [
            URLQueryItem(name: "seed", value: String(seed)),
            URLQueryItem(name: "score", value: String(targetScore)),
            URLQueryItem(name: "deepLink", value: deepLink.absoluteString)
        ]
        guard let universal = components.url else { return nil }
        return ChallengeLinkBundle(deepLink: deepLink, universalLink: universal)
    }

    public func generateLink() -> URL? {
        generateLinkBundle()?.deepLink
    }

    public var description: String {
        "Challenge(seed: \(seed), targetScore: \(targetScore))"
    }
}
