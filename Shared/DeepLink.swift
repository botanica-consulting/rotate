import Foundation

/// The app's own URL scheme, `rotate://new?device=pump`.
///
/// Both ends live here because they are built and parsed in different processes:
/// the widget extension composes the URL, the app resolves it.
nonisolated enum DeepLink {
    nonisolated static let scheme = "rotate"
    nonisolated private static let newPlacementHost = "new"

    nonisolated static func newPlacement(for device: DeviceType) -> URL? {
        URL(string: "\(scheme)://\(newPlacementHost)?device=\(device.rawValue)")
    }

    /// The track a new-placement link asks for, or nil if the URL isn't one.
    /// A link with no (or an unknown) track falls back to the pump.
    nonisolated static func newPlacementDevice(from url: URL) -> DeviceType? {
        guard url.scheme == scheme else { return nil }
        guard url.host == newPlacementHost || url.path == "/\(newPlacementHost)" else { return nil }
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "device" }?
            .value
        return DeviceType(rawValue: raw ?? "") ?? .pump
    }
}
