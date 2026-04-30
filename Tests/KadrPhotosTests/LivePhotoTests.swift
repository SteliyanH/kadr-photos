import Testing
import Foundation
import CoreMedia
import Kadr
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.2 Tier 1 — Live Photo support. Pure helpers; PHAsset-dependent paths
/// require a real photo library and are covered by integration testing.
struct LivePhotoTests {

    // MARK: - .notALivePhoto error

    @Test func notALivePhotoIsEquatable() {
        #expect(PhotosClipError.notALivePhoto == .notALivePhoto)
        #expect(PhotosClipError.notALivePhoto != .missingMedia)
        #expect(PhotosClipError.notALivePhoto != .unauthorized)
    }

    // MARK: - Temp URL generation

    #if canImport(Photos)
    @Test func makeTempLivePhotoMotionURLProducesUniquePaths() {
        let a = PhotosClipResolver.makeTempLivePhotoMotionURL()
        let b = PhotosClipResolver.makeTempLivePhotoMotionURL()
        #expect(a != b)
    }

    @Test func makeTempLivePhotoMotionURLHasMOVExtension() {
        let url = PhotosClipResolver.makeTempLivePhotoMotionURL()
        #expect(url.pathExtension == "mov")
    }

    @Test func makeTempLivePhotoMotionURLLivesInTemporaryDirectory() {
        let url = PhotosClipResolver.makeTempLivePhotoMotionURL()
        let tempDir = FileManager.default.temporaryDirectory.standardizedFileURL.path
        #expect(url.standardizedFileURL.path.hasPrefix(tempDir))
    }
    #endif

    // MARK: - Surface presence (compile-time signature checks)

    #if canImport(Photos)
    @Test func livePhotoMotionHasExpectedSignature() {
        let _: (PHAsset) async throws -> VideoClip = { asset in
            try await PhotosClipResolver.livePhotoMotion(asset: asset)
        }
    }

    @Test func livePhotoStillHasCMTimeAndTimeIntervalOverloads() {
        let cmTimeForm: (PHAsset, CMTime) async throws -> ImageClip = { asset, dur in
            try await PhotosClipResolver.livePhotoStill(asset: asset, duration: dur)
        }
        let intervalForm: (PHAsset, TimeInterval) async throws -> ImageClip = { asset, dur in
            try await PhotosClipResolver.livePhotoStill(asset: asset, duration: dur)
        }
        _ = cmTimeForm
        _ = intervalForm
    }
    #endif
}
