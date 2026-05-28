import Testing
import Foundation
import ImageIO
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.6 Tier 3 — Live Photos depth-channel extraction. Pure helpers and
/// fallback behavior on inputs that don't carry depth; the PHAsset-dependent path
/// (real Live Photo with disparity aux) requires a photo library and is covered by
/// integration testing in a host app.
struct DepthExtractionTests {

    #if canImport(Photos)

    // MARK: - Aux-type preference

    @Test func depthAuxiliaryTypePreferenceIsDisparityFirst() {
        let order = PhotosClipResolver.depthAuxiliaryTypePreference
        #expect(order[0] == kCGImageAuxiliaryDataTypeDisparity as String)
        #expect(order[1] == kCGImageAuxiliaryDataTypeDepth as String)
        #expect(order[2] == kCGImageAuxiliaryDataTypePortraitEffectsMatte as String)
    }

    @Test func selectPrefersDisparityOverDepth() {
        let chosen = PhotosClipResolver.selectDepthAuxiliaryType(from: [
            kCGImageAuxiliaryDataTypeDepth as String,
            kCGImageAuxiliaryDataTypeDisparity as String,
        ])
        #expect(chosen == kCGImageAuxiliaryDataTypeDisparity as String)
    }

    @Test func selectPrefersDepthOverMatte() {
        let chosen = PhotosClipResolver.selectDepthAuxiliaryType(from: [
            kCGImageAuxiliaryDataTypePortraitEffectsMatte as String,
            kCGImageAuxiliaryDataTypeDepth as String,
        ])
        #expect(chosen == kCGImageAuxiliaryDataTypeDepth as String)
    }

    @Test func selectFallsBackToMatte() {
        let chosen = PhotosClipResolver.selectDepthAuxiliaryType(from: [
            kCGImageAuxiliaryDataTypePortraitEffectsMatte as String,
        ])
        #expect(chosen == kCGImageAuxiliaryDataTypePortraitEffectsMatte as String)
    }

    @Test func selectReturnsNilWhenNoMatch() {
        #expect(PhotosClipResolver.selectDepthAuxiliaryType(from: []) == nil)
        #expect(PhotosClipResolver.selectDepthAuxiliaryType(from: ["com.apple.something.else"]) == nil)
    }

    // MARK: - depthPixelBuffer(fromImageData:) — non-depth inputs

    @Test func depthPixelBufferReturnsNilForGarbageData() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        #expect(PhotosClipResolver.depthPixelBuffer(fromImageData: garbage) == nil)
    }

    @Test func depthPixelBufferReturnsNilForEmptyData() {
        #expect(PhotosClipResolver.depthPixelBuffer(fromImageData: Data()) == nil)
    }

    @Test func depthPixelBufferReturnsNilForPlainImageWithoutAux() throws {
        // 1×1 PNG with no auxiliary data — exercises the "image source created but no
        // depth aux found" branch.
        let png = try makeTinyPNG()
        #expect(PhotosClipResolver.depthPixelBuffer(fromImageData: png) == nil)
    }

    // MARK: - Helpers

    private func makeTinyPNG() throws -> Data {
        // 1×1 black PNG, base64-encoded.
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
        guard let data = Data(base64Encoded: base64) else {
            throw POSIXError(.EINVAL)
        }
        return data
    }

    #endif
}
