import AppIntents

/// Which track a widget instance shows, so someone wearing both can add one
/// widget for the pump and another for the sensor.
struct SelectTrackIntent: WidgetConfigurationIntent {
    nonisolated static let title: LocalizedStringResource = "Track"
    nonisolated static let description = IntentDescription(
        "Show the pump site or the sensor site."
    )

    @Parameter(title: "Track", default: DeviceType.pump)
    var device: DeviceType
}
