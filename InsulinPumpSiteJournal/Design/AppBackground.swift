import SwiftUI

/// Soft blue atmosphere behind every screen, drawn from Loop's accent and
/// glucose tints. Liquid Glass elements only read as glass when there is
/// color and content behind them to refract — a flat system background makes
/// glass photograph like a plain filled control.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.20), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [AppTheme.glucose.opacity(0.13), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

#Preview("Background") {
    AppBackground()
}
