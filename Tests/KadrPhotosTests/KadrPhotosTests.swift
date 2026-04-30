import Testing
@testable import KadrPhotos

/// Placeholder for the v0.1 cycle. Real tests land alongside the video / image
/// resolvers in subsequent tier PRs.
struct KadrPhotosTests {

    @Test func moduleBuilds() {
        // If this compiles, KadrPhotos imported Kadr correctly.
        #expect(KadrPhotos.version.hasPrefix("0.1"))
    }
}
