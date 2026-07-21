import Foundation
import Testing
@testable import InsulinPumpSiteJournal

/// The home screen's hero/history snap decision, tested through the pure
/// function the ScrollTargetBehavior delegates to. Geometry: an 800pt
/// container; long content (2000pt) puts the snap boundary at 800.
@MainActor
struct HeroPagingBehaviorTests {
    private func snap(proposed: CGFloat, from: CGFloat, content: CGFloat = 2_000) -> CGFloat? {
        HeroPagingBehavior.snapOffset(
            proposed: proposed,
            from: from,
            containerHeight: 800,
            contentHeight: content
        )
    }

    @Test func flickFromHeroLandsExactlyOnHistoryTop() {
        #expect(snap(proposed: 300, from: 40) == 800)
    }

    @Test func hugeFlickFromHeroNeverOvershootsThePage() {
        #expect(snap(proposed: 1_600, from: 0) == 800)
    }

    @Test func smallDragSettlesBackOnHero() {
        #expect(snap(proposed: 60, from: 10) == 0)
    }

    @Test func dragPastHalfwayCommitsToHistory() {
        #expect(snap(proposed: 450, from: 430) == 800)
    }

    @Test func scrollingDeepInHistoryStaysFree() {
        #expect(snap(proposed: 1_400, from: 1_000) == nil)
    }

    @Test func flickBackFromHistoryLandsOnHero() {
        #expect(snap(proposed: 650, from: 800) == 0)
    }

    @Test func nudgeAtHistoryTopHoldsThePage() {
        #expect(snap(proposed: 770, from: 800) == 800)
    }

    @Test func shortHistorySnapsToDeepestReachableOffset() {
        // Content barely taller than the container: boundary = 200.
        #expect(snap(proposed: 150, from: 0, content: 1_000) == 200)
    }

    @Test func contentShorterThanContainerNeverSnaps() {
        #expect(snap(proposed: 50, from: 0, content: 600) == nil)
    }
}
