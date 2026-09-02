import CloudKit
import Foundation

/// Removes the mirrored copy from the user's private iCloud without touching
/// the journal on this device.
///
/// SwiftData's CloudKit mirror has no "wipe the cloud, keep the local copy"
/// operation: the local store *is* what the mirror exports, so deleting records
/// deletes them everywhere. What can be removed is the mirror's own record
/// zone — CloudKit keeps everything the mirror writes in one zone, and deleting
/// that zone is a single server-confirmed request.
///
/// Order matters, and it is the reason this is a controller rather than a
/// function: sync must be switched off *first*, so no live mirror is running
/// that could notice the zone vanish and helpfully re-upload the whole store.
/// Writing the preference is not enough on its own — the mirror lives on the
/// `ModelContainer`, which is only rebuilt on the next SwiftUI update. So the
/// flow is two-step: Settings *arms* the purge, and `AppRootView` starts it
/// after it has rebuilt the container without the mirror. Turning sync off also
/// tears the Settings sheet's view state down mid-flight, which is the other
/// reason the work is owned by this singleton rather than by the view.
///
/// One thing this cannot do is speak for the user's *other* devices. A device
/// still syncing treats the missing zone as a fresh setup and uploads its own
/// copy again, so the copy only stays gone if sync is off everywhere. The
/// Settings copy says so.
@MainActor
@Observable
final class CloudKitPurgeController {
    static let shared = CloudKitPurgeController()

    enum State: Equatable {
        case idle
        case running
        case succeeded
        case failed(String)
    }

    private(set) var state: State
    private var task: Task<Void, Never>?
    /// Set when Settings turns sync off and asks for a purge; consumed once the
    /// container has been rebuilt without the mirror.
    private var isArmed = false

    private init() {
        // A purge that already finished stays finished across launches.
        state = SyncSettings.copyWasRemoved() ? .succeeded : .idle
    }

    /// Records that a purge should run as soon as the mirror is actually down.
    /// Shows as in-progress immediately, because from here on it will run.
    func arm() {
        guard state != .running else { return }
        isArmed = true
        state = .running
    }

    /// Runs an armed purge. Called by `AppRootView` after it has rebuilt the
    /// container for the new sync setting, so no mirror is live to undo it.
    func startIfArmed() {
        guard isArmed else { return }
        isArmed = false
        run()
    }

    /// Starts a purge now — the retry path, where sync is already off and the
    /// container was rebuilt long ago.
    func start() {
        guard state != .running else { return }
        state = .running
        run()
    }

    private func run() {
        task = Task { [weak self] in
            do {
                try await CloudKitPurge.removeMirroredCopy()
                SyncSettings.setCopyWasRemoved(true)
                self?.state = .succeeded
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    /// Clears a finished result so the next attempt starts from a clean slate.
    /// Turning sync back on uploads the journal again, so a past purge stops
    /// being true at that point.
    func acknowledge() {
        guard state != .running else { return }
        isArmed = false
        SyncSettings.setCopyWasRemoved(false)
        state = .idle
    }
}

enum CloudKitPurge {
    /// The zone SwiftData's CloudKit mirror writes into. Fixed by Core Data, not
    /// something the app chooses.
    static let zoneName = "com.apple.coredata.cloudkit.zone"

    /// Deletes the mirror's zone from the user's private database.
    ///
    /// A missing zone is success, not a failure: it means nothing was ever
    /// mirrored, or a previous attempt already finished the job.
    static func removeMirroredCopy() async throws {
        let database = CKContainer(identifier: SyncSettings.cloudKitContainerID).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        do {
            let (_, deleteResults) = try await database.modifyRecordZones(
                saving: [],
                deleting: [zoneID]
            )
            for (_, result) in deleteResults {
                if case .failure(let error) = result, !isAlreadyGone(error) {
                    throw error
                }
            }
        } catch let error where isAlreadyGone(error) {
            return
        }
    }

    /// Whether an error means the zone is already gone. Not private: the
    /// partial-failure recursion is the subtlest logic here and is worth a test.
    static func isAlreadyGone(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .zoneNotFound, .unknownItem:
            return true
        case .partialFailure:
            // A partial failure whose only complaint is the missing zone.
            let perZone = Array((ckError.partialErrorsByItemID ?? [:]).values)
            return !perZone.isEmpty && perZone.allSatisfy { isAlreadyGone($0) }
        default:
            return false
        }
    }
}
