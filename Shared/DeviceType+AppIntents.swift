import AppIntents

/// Lets the pump/sensor split be a parameter — on a Siri phrase, on a widget's
/// configuration, and in the Shortcuts app. Kept apart from `DeviceType` itself
/// so the model stays free of the AppIntents import.
nonisolated extension DeviceType: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Track")
    }

    nonisolated static var caseDisplayRepresentations: [DeviceType: DisplayRepresentation] {
        [
            .pump: DisplayRepresentation(title: "Pump"),
            .cgm: DisplayRepresentation(title: "Sensor"),
        ]
    }
}
