import Testing
import Foundation
import AVFoundation
import Kadr
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.5 Tier 1 — slow-motion preservation. The PHAsset-dependent
/// paths (`slowMotion(asset:)`, `videoFrameRate(of:)`) require the Photos
/// framework + a real high-frame-rate asset, so they're integration-tested in
/// the example app. Pure-helper tests live here.
struct SlowMotionTests {

    // MARK: - slowMotionSpeed math

    @Test func slowMotionSpeed240fpsSourceClassicQuarter() {
        // The classic iOS Photos slow-mo: 240 fps source rendered at 60 fps
        // playback → consumer applies `clip.speed(0.25)`.
        let speed = PhotosClipResolver.slowMotionSpeed(
            originalFrameRate: 240,
            playbackFrameRate: 60
        )
        #expect(speed == 0.25)
    }

    @Test func slowMotionSpeed120fpsSourceHalf() {
        let speed = PhotosClipResolver.slowMotionSpeed(
            originalFrameRate: 120,
            playbackFrameRate: 60
        )
        #expect(speed == 0.5)
    }

    @Test func slowMotionSpeedDefaultPlaybackIs30fps() {
        // Caller omits `playbackFrameRate` → 30 fps default.
        // 60 fps source @ 30 fps playback = 0.5× (mild slow-mo).
        let speed = PhotosClipResolver.slowMotionSpeed(originalFrameRate: 60)
        #expect(speed == 0.5)
    }

    @Test func slowMotionSpeedDefendsAgainstZeroOriginal() {
        let speed = PhotosClipResolver.slowMotionSpeed(
            originalFrameRate: 0,
            playbackFrameRate: 30
        )
        #expect(speed == 1.0)
    }

    @Test func slowMotionSpeedDefendsAgainstNegativeInputs() {
        #expect(PhotosClipResolver.slowMotionSpeed(originalFrameRate: -1) == 1.0)
        #expect(PhotosClipResolver.slowMotionSpeed(
            originalFrameRate: 240,
            playbackFrameRate: -30
        ) == 1.0)
    }

    @Test func slowMotionSpeedAt1xWhenSourceMatchesPlayback() {
        let speed = PhotosClipResolver.slowMotionSpeed(
            originalFrameRate: 60,
            playbackFrameRate: 60
        )
        #expect(speed == 1.0)
    }

    // MARK: - notSlowMotion error case shape

    @Test func notSlowMotionErrorRoundTrips() {
        let lhs: PhotosClipError = .notSlowMotion
        let rhs: PhotosClipError = .notSlowMotion
        #expect(lhs == rhs)
    }

    @Test func notSlowMotionDistinctFromOtherErrors() {
        #expect(PhotosClipError.notSlowMotion != PhotosClipError.notALivePhoto)
        #expect(PhotosClipError.notSlowMotion != PhotosClipError.unauthorized)
        #expect(PhotosClipError.notSlowMotion != PhotosClipError.missingMedia)
    }

    // MARK: - Subtype passthrough confirmation

    /// Sanity check: the existing `PhotoAssetSubtypes.highFrameRate` flag
    /// already maps from `PHAssetMediaSubtype.videoHighFrameRate` (added in
    /// v0.4). The slow-motion entry point relies on the consumer detecting
    /// this flag from `metadata(of:)`.
    @Test func highFrameRateSubtypeAlreadyExposed() {
        let subtypes = PhotoAssetSubtypes.highFrameRate
        #expect(subtypes.contains(.highFrameRate))
        #expect(!subtypes.contains(.livePhoto))
    }
}
