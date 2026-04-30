import Testing
import Foundation
import AVFoundation
import Kadr
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.1 Tier 1 — pure helpers around `PhotosClipResolver`. The PHAsset-
/// dependent paths require the Photos framework + a real photo library, so they're
/// covered by manual / integration testing in the example app rather than here.
struct PhotosClipResolverTests {

    // MARK: - PhotosMediaKind mapping

    #if canImport(Photos)
    @Test func mapsPHAssetMediaTypeCases() {
        #expect(PhotosMediaKind.from(.video) == .video)
        #expect(PhotosMediaKind.from(.image) == .image)
        #expect(PhotosMediaKind.from(.audio) == .audio)
        #expect(PhotosMediaKind.from(.unknown) == .unknown)
    }
    #endif

    // MARK: - Options defaults

    @Test func optionsDefaultMatchesExpectedShape() {
        let opts = PhotosClipResolver.Options.default
        #expect(opts.imageTargetSize == .maximumSize)
        #expect(opts.imageContentMode == .aspectFill)
        #expect(opts.imageDeliveryMode == .highQualityFormat)
        #expect(opts.videoExportPreset == AVAssetExportPresetHighestQuality)
    }

    @Test func optionsAreEquatable() {
        #expect(PhotosClipResolver.Options.default == PhotosClipResolver.Options.default)
        var custom = PhotosClipResolver.Options.default
        custom.imageDeliveryMode = .fastFormat
        #expect(custom != PhotosClipResolver.Options.default)
    }

    // MARK: - TargetSize

    @Test func explicitPixelTargetResolvesToCGSize() {
        let target = PhotosClipResolver.TargetSize.pixels(width: 1080, height: 1920)
        #expect(target.cgSize == CGSize(width: 1080, height: 1920))
    }

    #if canImport(Photos)
    @Test func maximumTargetResolvesToPHImageManagerMaximumSize() {
        let target = PhotosClipResolver.TargetSize.maximumSize
        #expect(target.cgSize == PHImageManagerMaximumSize)
    }
    #endif

    // MARK: - ImageContentMode bridge

    #if canImport(Photos)
    @Test func imageContentModeMapsToPHContentMode() {
        #expect(PhotosClipResolver.ImageContentMode.aspectFit.phContentMode == .aspectFit)
        #expect(PhotosClipResolver.ImageContentMode.aspectFill.phContentMode == .aspectFill)
        #expect(PhotosClipResolver.ImageContentMode.default.phContentMode == .default)
    }
    #endif

    // MARK: - ImageDeliveryMode bridge

    #if canImport(Photos)
    @Test func imageDeliveryModeMapsToPHDeliveryMode() {
        #expect(PhotosClipResolver.ImageDeliveryMode.opportunistic.phDeliveryMode == .opportunistic)
        #expect(PhotosClipResolver.ImageDeliveryMode.highQualityFormat.phDeliveryMode == .highQualityFormat)
        #expect(PhotosClipResolver.ImageDeliveryMode.fastFormat.phDeliveryMode == .fastFormat)
    }
    #endif

    // MARK: - Temp URL generation

    #if canImport(Photos)
    @Test func makeTempVideoURLProducesUniquePaths() {
        let a = PhotosClipResolver.makeTempVideoURL()
        let b = PhotosClipResolver.makeTempVideoURL()
        #expect(a != b)
    }

    @Test func makeTempVideoURLHasMP4Extension() {
        let url = PhotosClipResolver.makeTempVideoURL()
        #expect(url.pathExtension == "mp4")
    }

    @Test func makeTempVideoURLLivesInTemporaryDirectory() {
        let url = PhotosClipResolver.makeTempVideoURL()
        let tempDir = FileManager.default.temporaryDirectory.standardizedFileURL.path
        #expect(url.standardizedFileURL.path.hasPrefix(tempDir))
    }
    #endif

    // MARK: - Errors

    @Test func errorEqualityHonorsAssociatedValues() {
        let a = PhotosClipError.iCloudDownload(localizedDescription: "x")
        let b = PhotosClipError.iCloudDownload(localizedDescription: "x")
        let c = PhotosClipError.iCloudDownload(localizedDescription: "y")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func wrongMediaTypeCarriesExpectedAndActual() {
        let err = PhotosClipError.wrongMediaType(expected: .video, actual: .image)
        if case .wrongMediaType(let expected, let actual) = err {
            #expect(expected == .video)
            #expect(actual == .image)
        } else {
            Issue.record("expected .wrongMediaType")
        }
    }

    @Test func unauthorizedHasNoPayload() {
        #expect(PhotosClipError.unauthorized == .unauthorized)
        #expect(PhotosClipError.unauthorized != .missingMedia)
    }

    // MARK: - Image resolver overloads (compile-time / signature presence)

    #if canImport(Photos)
    @Test func imageResolverHasCMTimeAndTimeIntervalOverloads() {
        // We can't exercise these without a real PHAsset, but we can confirm the two
        // overloads are present in the public surface — closures of the exact types
        // type-check below.
        let cmTimeForm: (PHAsset, CMTime) async throws -> ImageClip = { asset, dur in
            try await PhotosClipResolver.image(asset: asset, duration: dur)
        }
        let intervalForm: (PHAsset, TimeInterval) async throws -> ImageClip = { asset, dur in
            try await PhotosClipResolver.image(asset: asset, duration: dur)
        }
        _ = cmTimeForm  // suppress unused warnings
        _ = intervalForm
    }
    #endif
}
