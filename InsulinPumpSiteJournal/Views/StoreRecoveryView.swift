import SwiftUI

/// Shown instead of the app when the data store fails to open. Offers a
/// retry and, as a last resort, a confirmed store reset — never a crash loop.
struct StoreRecoveryView: View {
    let error: Error
    let retry: () -> Void
    let resetAndRetry: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label("Can't open your journal", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("The data store failed to open. Try again — if this keeps happening, you can reset the store.\n\n\(error.localizedDescription)")
            }

            Button {
                retry()
            } label: {
                Text("Try Again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("retryStoreButton")

            Button("Reset data…", role: .destructive) {
                confirmingReset = true
            }
            .accessibilityIdentifier("resetStoreButton")
        }
        .padding()
        .confirmationDialog(
            "Delete the data store?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete and start over", role: .destructive) {
                resetAndRetry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every Pod record on this device.")
        }
    }
}
