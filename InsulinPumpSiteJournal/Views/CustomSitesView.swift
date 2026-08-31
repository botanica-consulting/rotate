import SwiftUI
import SwiftData

/// Manage the sites you added yourself, for spots the body figure doesn't
/// cover. Each one behaves like a catalog site everywhere else in the app —
/// it can be suggested, it collects recency heat, and it can be excluded from
/// either track — it just draws as a floating area instead of a place on the
/// silhouette.
struct CustomSitesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomSite.createdAt, order: .forward)
    private var sites: [CustomSite]

    @State private var newName = ""
    @State private var renaming: CustomSite?
    @State private var renameText = ""
    @State private var saveError: Error?

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var active: [CustomSite] { sites.filter { !$0.isArchived } }
    private var archived: [CustomSite] { sites.filter(\.isArchived) }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Site name", text: $newName)
                        .submitLabel(.done)
                        .onSubmit(add)
                        .accessibilityIdentifier("customSiteNameField")
                    Button("Add", action: add)
                        .disabled(trimmedNewName.isEmpty)
                        .accessibilityIdentifier("addCustomSiteButton")
                }
            } footer: {
                Text("Name it however you'd recognise it — \"left calf\", \"right hip\". Custom sites have no drawing on the figure, so they show as a plain area instead.")
            }

            if !active.isEmpty {
                Section("Your sites") {
                    ForEach(active) { site in
                        row(for: site)
                    }
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { site in
                        HStack {
                            Text(site.name)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore") {
                                perform { try JournalStore(context: modelContext).setArchived(site, false) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Removed")
                } footer: {
                    Text("Removed sites aren't offered for new placements, but they're kept so past entries still show their name.")
                }
            }
        }
        .navigationTitle("Custom sites")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Rename site",
            isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )
        ) {
            TextField("Site name", text: $renameText)
            Button("Save") {
                if let site = renaming, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    perform { try JournalStore(context: modelContext).rename(site, to: renameText) }
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .alert(
            "Couldn't save your sites",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func row(for site: CustomSite) -> some View {
        HStack(spacing: 12) {
            CustomSiteThumbnail(fill: AppTheme.restedShade)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(site.name)
            Spacer()
        }
        .contentShape(.rect)
        .onTapGesture {
            renameText = site.name
            renaming = site
        }
        .swipeActions {
            Button("Remove", role: .destructive) {
                perform { try JournalStore(context: modelContext).setArchived(site, true) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(site.name)
        .accessibilityHint("Double-tap to rename.")
        .accessibilityIdentifier("customSite-\(site.id.uuidString)")
    }

    private func add() {
        guard !trimmedNewName.isEmpty else { return }
        perform {
            try JournalStore(context: modelContext).addCustomSite(name: trimmedNewName)
            newName = ""
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            saveError = error
        }
    }
}

#Preview("Custom sites") {
    NavigationStack {
        CustomSitesView()
    }
    .modelContainer(for: CustomSite.self, inMemory: true)
}
