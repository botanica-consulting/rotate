import Foundation

/// Which silhouette artwork the app renders. Stored app-wide via AppStorage;
/// "neutral" is the default and covers "rather not say".
enum BodyType: String, CaseIterable, Identifiable {
    case neutral
    case woman
    case man

    var id: String { rawValue }

    /// Silhouettes are offered as neutral numbered options; the internal
    /// names stay descriptive for assets and code.
    var displayName: String {
        switch self {
        case .neutral: "1"
        case .woman: "2"
        case .man: "3"
        }
    }

    func assetName(for bodyView: PumpSite.BodyView) -> String {
        "body-\(rawValue)-\(bodyView == .front ? "front" : "rear")"
    }

    static let storageKey = "bodyType"
}
