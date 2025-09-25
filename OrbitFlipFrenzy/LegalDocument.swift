import Foundation

public struct LegalSection {
    public let title: String
    public let body: String
}

public enum LegalDocument: CaseIterable {
    case privacyPolicy
    case termsOfUse

    public var buttonTitle: String {
        switch self {
        case .privacyPolicy:
            return "Privacy"
        case .termsOfUse:
            return "Terms"
        }
    }

    public var title: String {
        switch self {
        case .privacyPolicy:
            return "Privacy Policy"
        case .termsOfUse:
            return "Terms of Use"
        }
    }

    public var subtitle: String {
        "Last updated: April 15, 2024"
    }

    public var introduction: String {
        switch self {
        case .privacyPolicy:
            return "Orbit Flip Frenzy respects your privacy. This notice explains what information we collect, how we use it, and the choices you have."
        case .termsOfUse:
            return "Welcome to Orbit Flip Frenzy! These terms govern your use of the game, in-app purchases, and social features."
        }
    }

    public var sections: [LegalSection] {
        switch self {
        case .privacyPolicy:
            return [
                LegalSection(title: "1. Information We Collect", body: "We store gameplay metrics such as score, level progress, near-miss counts, and purchase history so you can track achievements and recover entitlements. We do not collect personal contact details unless you share them with support."),
                LegalSection(title: "2. How We Use Data", body: "Gameplay analytics help balance difficulty, measure the effectiveness of power-ups, and surface daily streak rewards. Purchase logs are required to restore non-consumable items. Aggregated telemetry may be used to improve future updates."),
                LegalSection(title: "3. Data Sharing", body: "We do not sell your data. Limited telemetry may be shared with service providers (such as analytics or payment partners) solely to operate the game. All partners must adhere to contractual confidentiality obligations."),
                LegalSection(title: "4. Device Permissions", body: "If you grant permission, the app may access haptics, local photo storage (for replay sharing), and network connectivity. Revoking permissions can limit certain features but will not prevent core gameplay."),
                LegalSection(title: "5. Retention & Security", body: "Scores and purchase receipts are retained while your account remains active. We use platform security features, encrypted storage, and regular audits to protect your information."),
                LegalSection(title: "6. Your Choices", body: "You can reset local data from the in-game settings, disable analytics in iOS privacy controls, or delete the app to remove stored information. Contact support@orbitflipfrenzy.com to request data export or deletion."),
                LegalSection(title: "7. Children's Privacy", body: "The game targets players 13+. If we learn that we have collected data from a younger child without guardian consent, we will delete it promptly."),
                LegalSection(title: "8. Contact", body: "Reach us at support@orbitflipfrenzy.com or Orbit Flip Frenzy Privacy, 123 Neon Way, San Francisco, CA 94107 USA.")
            ]
        case .termsOfUse:
            return [
                LegalSection(title: "1. Acceptance", body: "By installing or playing Orbit Flip Frenzy you agree to these terms and to follow applicable laws. If you disagree, uninstall the app."),
                LegalSection(title: "2. License", body: "We grant you a personal, non-transferable license to play the game for entertainment. Reverse engineering, cheating, or reselling access is prohibited."),
                LegalSection(title: "3. Virtual Goods & Purchases", body: "Gem packs and cosmetic items are virtual goods with no cash value and are non-refundable except where required by law. Keep your purchase receipts to restore entitlements across devices."),
                LegalSection(title: "4. Fair Play", body: "You agree not to exploit bugs, automate gameplay, or harass other community members. We may suspend access for misconduct."),
                LegalSection(title: "5. User Content", body: "Replay GIFs and share messages you generate remain yours, but by sharing them you grant us a worldwide license to display and promote them within the game and on social channels."),
                LegalSection(title: "6. Updates & Availability", body: "Features may change as we balance difficulty, add content, or address bugs. We are not liable for service outages or data loss beyond our reasonable control."),
                LegalSection(title: "7. Disclaimer & Liability", body: "The game is provided \"as is\" without warranties. Our liability is limited to the maximum extent permitted by law and never exceeds the amount you paid in the preceding six months."),
                LegalSection(title: "8. Governing Law", body: "These terms are governed by the laws of California, USA, excluding conflict of law rules. Disputes will be handled in San Francisco County courts."),
                LegalSection(title: "9. Support", body: "Contact support@orbitflipfrenzy.com for help with purchases, bug reports, or accessibility requests."),
                LegalSection(title: "10. Changes", body: "We may update these terms. Continued play after changes means you accept the new terms. We will post updates in the app and revise the date above.")
            ]
        }
    }
}
