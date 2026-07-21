import Foundation

/// Which silhouette artwork the app renders. Stored app-wide via AppStorage;
/// "neutral" is the default and covers "rather not say".
enum BodyType: String, CaseIterable, Identifiable {
    case neutral
    case woman
    case man

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neutral: "Neutral"
        case .woman: "Woman"
        case .man: "Man"
        }
    }

    func assetName(for bodyView: PumpSite.BodyView) -> String {
        "body-\(rawValue)-\(bodyView == .front ? "front" : "rear")"
    }

    static let storageKey = "bodyType"
}
