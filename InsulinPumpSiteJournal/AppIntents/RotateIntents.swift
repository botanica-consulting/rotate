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
///
/// The track is interpolated into the phrase rather than left to the parameter's
/// default: with `\(.applicationName)` alone, "how long has my sensor been on"
/// still resolved to the pump, silently, because `device` defaults to `.pump`
/// and nothing in the phrase could override it. The sensor is half the app, so
/// it needs to be sayable. Each intent keeps one un-parameterised shorthand,
/// which is the only phrase the pump default still answers.
struct RotateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskSiteAgeIntent(),
            phrases: [
                "How long has my \(\.$device) been on in \(.applicationName)",
                "How long has my \(\.$device) site been on in \(.applicationName)",
                "Check my \(\.$device) site age in \(.applicationName)",
                "\(.applicationName) site age",
            ],
            shortTitle: "Check site age",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: StartPlacementIntent(),
            phrases: [
                "Start a new \(\.$device) site in \(.applicationName)",
                "Log a new \(\.$device) site in \(.applicationName)",
                "New \(\.$device) site in \(.applicationName)",
                "Start a new site in \(.applicationName)",
            ],
            shortTitle: "Start a new site",
            systemImageName: "plus.circle"
        )
    }
}
