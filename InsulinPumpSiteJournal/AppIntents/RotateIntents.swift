import AppIntents

/// "How long has my pump been on?"
///
/// Answers from the shared snapshot rather than the journal: a Siri question
/// shouldn't need to open the SwiftData store, spin up CloudKit, or show any UI.
struct AskSiteAgeIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Check site age"
    nonisolated static let description = IntentDescription(
        "How long the current pump or sensor site has been on."
    )
    nonisolated static let openAppWhenRun = false

    @Parameter(title: "Track", default: DeviceType.pump)
    var device: DeviceType

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let track = SiteSnapshot.load().track(for: device) else {
            return .result(dialog: IntentDialog(
                "No \(device.noun) site is recorded in Rotate right now."
            ))
        }
        let spoken = WearDuration.spokenText(at: .now, since: track.placedAt)
        return .result(dialog: IntentDialog(
            "Your \(device.noun) has been on \(spoken), on your \(track.siteTitle.lowercased())."
        ))
    }
}

/// "Start a new pump site." Opens Rotate on the site picker — choosing where the
/// next site goes is the whole point of the flow, so this hands over rather than
/// writing anything.
struct StartPlacementIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start a new site"
    nonisolated static let description = IntentDescription(
        "Opens Rotate on the site picker for your next pump or sensor placement."
    )
    nonisolated static let openAppWhenRun = true

    @Parameter(title: "Track", default: DeviceType.pump)
    var device: DeviceType

    @Dependency private var router: AppRouter

    // The router is main-actor state; an async requirement may be satisfied by
    // an isolated implementation.
    @MainActor
    func perform() async throws -> some IntentResult {
        router.requestNewPlacement(for: device)
        return .result()
    }
}

/// The phrases Siri recognises without the user building a shortcut first.
struct RotateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskSiteAgeIntent(),
            phrases: [
                "How long has my site been on in \(.applicationName)",
                "Check my site age in \(.applicationName)",
                "\(.applicationName) site age",
            ],
            shortTitle: "Check site age",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: StartPlacementIntent(),
            phrases: [
                "Start a new site in \(.applicationName)",
                "Log a new site in \(.applicationName)",
                "New site in \(.applicationName)",
            ],
            shortTitle: "Start a new site",
            systemImageName: "plus.circle"
        )
    }
}
