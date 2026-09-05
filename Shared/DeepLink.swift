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
    ///
    /// An *omitted* track falls back to the pump — that is a link that simply
    /// didn't say. A track that is present but unrecognised is rejected instead:
    /// it is a malformed request, and quietly opening the wrong track is worse
    /// than ignoring the link.
    nonisolated static func newPlacementDevice(from url: URL) -> DeviceType? {
        guard url.scheme == scheme else { return nil }
        guard url.host == newPlacementHost || url.path == "/\(newPlacementHost)" else { return nil }
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "device" })?
            .value
        else { return .pump }
        return DeviceType(rawValue: raw)
    }
}
