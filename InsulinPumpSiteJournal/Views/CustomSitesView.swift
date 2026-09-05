import SwiftUI
import SwiftData

/// Manage one track's own sites, for spots the body figure doesn't cover.
/// Each behaves like a catalog site everywhere else — suggested, recency-
/// tracked, includable — it just draws as a floating area rather than a place
/// on the silhouette.
///
/// Scoped to a track: reached from the Pump or Sensor screen, and only that
/// track's sites are listed or created here.
struct CustomSitesView: View {
    let device: DeviceType

    @Environment(\.modelContext) private var modelContext
    /// Filtered in memory rather than by predicate — `device` is derived from
    /// the stored raw string, and these lists are a handful of rows.
    @Query(sort: \CustomSite.createdAt, order: .forward)
    private var allSites: [CustomSite]

    private var sites: [CustomSite] { allSites.filter { $0.device == device } }

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
                Text("Custom sites appear as plain area markers on the map.")
            }

            if !active.isEmpty {
                Section {
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
                    Text("Not offered for new placements. Past entries keep the name.")
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
            try JournalStore(context: modelContext).addCustomSite(name: trimmedNewName, for: device)
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
        CustomSitesView(device: .pump)
    }
    .modelContainer(for: CustomSite.self, inMemory: true)
}
