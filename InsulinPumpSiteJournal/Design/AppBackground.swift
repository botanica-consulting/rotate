import SwiftUI

/// Soft teal atmosphere behind every screen. Liquid Glass elements only read
/// as glass when there is color and content behind them to refract — a flat
/// system background makes glass photograph like a plain filled control.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color.mint.opacity(0.14), .clear],
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
