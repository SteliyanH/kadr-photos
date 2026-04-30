import Testing
import Foundation
import CoreMedia
import Kadr
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.4 Tier 2 — `PhotosClipResolver.imageOverlay(asset:)` /
/// `stickerOverlay(asset:)`. The PHAsset-resolving path requires a real photo
/// library; what we can unit-test is signature presence + closure form.
struct OverlayHelpersTests {

    #if canImport(Photos)

    @Test func imageOverlayHasExpectedSignature() {
        // Compile-time signature check — confirms the public surface exists with
        // the documented defaults and parameter labels.
        let signature: (PHAsset) async throws -> ImageOverlay = { asset in
            try await PhotosClipResolver.imageOverlay(asset: asset)
        }
        _ = signature
    }

    @Test func imageOverlayAcceptsPositionAndAnchor() {
        let signature: (PHAsset, Position, Kadr.Anchor) async throws -> ImageOverlay = { asset, pos, anchor in
            try await PhotosClipResolver.imageOverlay(asset: asset, position: pos, anchor: anchor)
        }
        _ = signature
    }

    @Test func imageOverlayAcceptsSize() {
        let signature: (PHAsset, Size) async throws -> ImageOverlay = { asset, size in
            try await PhotosClipResolver.imageOverlay(asset: asset, size: size)
        }
        _ = signature
    }

    @Test func stickerOverlayHasExpectedSignature() {
        let signature: (PHAsset) async throws -> StickerOverlay = { asset in
            try await PhotosClipResolver.stickerOverlay(asset: asset)
        }
        _ = signature
    }

    @Test func stickerOverlayAcceptsRotationAndShadow() {
        let shadow = StickerOverlay.Shadow(
            color: .init(),
            radius: 4,
            offset: .init(width: 2, height: 2),
            opacity: 0.5
        )
        let signature: (PHAsset, Double, StickerOverlay.Shadow) async throws -> StickerOverlay = { asset, rotation, shadow in
            try await PhotosClipResolver.stickerOverlay(asset: asset, rotation: rotation, shadow: shadow)
        }
        _ = signature
        _ = shadow
    }

    #endif
}
