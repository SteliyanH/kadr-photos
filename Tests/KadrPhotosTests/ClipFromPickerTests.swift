import Testing
import Foundation
import CoreMedia
import Kadr
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.3 Tier 2 — `PhotosClipResolver.clip(from:)` and `clips(from:)`. The
/// PHAsset-resolving path requires a real photo library and is covered by manual
/// integration testing; what we can unit-test is the public-surface signature
/// presence and the empty-array fast path.
struct ClipFromPickerTests {

    #if canImport(Photos)

    @Test func clipFromHasCMTimeAndTimeIntervalOverloads() {
        // Compile-time signature presence — both overloads exist on
        // PhotosClipResolver.
        let cmTimeForm: (PhotoPickerResult, CMTime) async throws -> any Clip = { result, dur in
            try await PhotosClipResolver.clip(from: result, imageDuration: dur)
        }
        let intervalForm: (PhotoPickerResult, TimeInterval) async throws -> any Clip = { result, dur in
            try await PhotosClipResolver.clip(from: result, imageDuration: dur)
        }
        _ = cmTimeForm
        _ = intervalForm
    }

    @Test func clipsFromHasCMTimeAndTimeIntervalOverloads() {
        let cmTimeForm: ([PhotoPickerResult], CMTime) async throws -> [any Clip] = { results, dur in
            try await PhotosClipResolver.clips(from: results, imageDuration: dur)
        }
        let intervalForm: ([PhotoPickerResult], TimeInterval) async throws -> [any Clip] = { results, dur in
            try await PhotosClipResolver.clips(from: results, imageDuration: dur)
        }
        _ = cmTimeForm
        _ = intervalForm
    }

    @Test func clipsFromEmptyArrayReturnsEmpty() async throws {
        // Fast path that doesn't touch PHAsset at all.
        let out = try await PhotosClipResolver.clips(from: [])
        #expect(out.isEmpty)
    }

    #endif
}
