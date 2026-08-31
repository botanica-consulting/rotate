import Foundation
import Observation

/// Where "open the new-placement flow" requests arrive from outside the UI: a
/// Siri shortcut, and a tap on the widget.
///
/// A shared object rather than a value passed inward, because both entry points
/// can fire before any view exists — a cold launch from the widget runs the URL
/// handler before `HistoryHomeView` appears — so the request has to be able to
/// wait somewhere until the journal is on screen and can consume it.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    /// Track whose flow should open. Set from an intent or a deep link, cleared
    /// by the view that acts on it.
    var pendingNewDevice: DeviceType?

    private init() {}

    func requestNewPlacement(for device: DeviceType) {
        pendingNewDevice = device
    }

    /// Handles a widget tap: `rotate://new?device=pump`. Returns whether the URL
    /// was one of ours.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let device = DeepLink.newPlacementDevice(from: url) else { return false }
        requestNewPlacement(for: device)
        return true
    }
}
