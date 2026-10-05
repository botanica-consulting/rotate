import SwiftUI

/// "What's new", shown once after an upgrade. Existing users never walk the
/// setup wizard again, so this is the only place a change in wording — or a new
/// privacy switch — can reach them.
struct WhatsNewView: View {
    let notes: [ReleaseNotes]
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("What's new")
                            .font(.title.bold())
                            .padding(.top, 8)

                        ForEach(notes) { release in
                            VStack(alignment: .leading, spacing: 28) {
                                // Only labelled when catching up across more
                                // than one release, so the common case is clean.
                                if notes.count > 1 {
                                    Text("Version \(release.version)")
                                        .font(.caption.smallCaps())
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(Array(release.points.enumerated()), id: \.offset) { _, point in
                                    FeaturePoint(icon: point.icon, title: point.title, text: point.text)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }

                Button(action: onDismiss) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .accessibilityIdentifier("whatsNewButton")
            }
            .background(AppBackground())
        }
        .fontDesign(.rounded)
        .interactiveDismissDisabled()
    }
}

#Preview("What's new") {
    WhatsNewView(notes: ReleaseNotes.all, onDismiss: {})
}
