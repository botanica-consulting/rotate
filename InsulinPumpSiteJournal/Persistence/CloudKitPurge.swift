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
/// Turning sync off rebuilds the model container, which can tear the Settings
/// sheet's view state down mid-flight, so the work is owned by this singleton
/// instead of by the view that started it.
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

    private(set) var state: State = .idle
    private var task: Task<Void, Never>?

    private init() {}

    /// Starts a purge, or does nothing if one is already running.
    func start() {
        guard state != .running else { return }
        state = .running
        task = Task { [weak self] in
            do {
                try await CloudKitPurge.removeMirroredCopy()
                self?.state = .succeeded
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    /// Clears a finished result so the next attempt starts from a clean slate.
    func acknowledge() {
        guard state != .running else { return }
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

    private static func isAlreadyGone(_ error: Error) -> Bool {
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
