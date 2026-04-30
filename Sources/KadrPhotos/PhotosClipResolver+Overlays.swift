import Foundation
import Kadr
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Resolve an image `PHAsset` directly to a `Kadr.ImageOverlay`. Useful for
    /// "logo from Photos" / "watermark from Photos" workflows — saves the
    /// `image()` → `ImageClip` → `clip.image` → `ImageOverlay(_:)` round-trip.
    ///
    /// On a Live Photo asset (`mediaType == .image` + `mediaSubtypes.contains(.photoLive)`)
    /// this returns the still half. Live Photo motion as overlay isn't a kadr
    /// surface — overlays are static images.
    public static func imageOverlay(
        asset: PHAsset,
        position: Position = .center,
        size: Size? = nil,
        anchor: Kadr.Anchor = .center,
        opacity: Double = 1.0,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageOverlay {
        let clip = try await image(
            asset: asset,
            duration: .indefinite,
            options: options,
            progress: progress
        )
        var overlay = ImageOverlay(clip.image)
            .position(position)
            .anchor(anchor)
            .opacity(opacity)
        if let size {
            overlay = overlay.size(size)
        }
        return overlay
    }

    /// Resolve an image `PHAsset` directly to a `Kadr.StickerOverlay`. Same shape
    /// as ``imageOverlay(asset:position:size:anchor:opacity:options:progress:)``
    /// but produces a `StickerOverlay` — supports rotation and shadow.
    public static func stickerOverlay(
        asset: PHAsset,
        position: Position = .center,
        size: Size? = nil,
        anchor: Kadr.Anchor = .center,
        opacity: Double = 1.0,
        rotation: Double = 0.0,
        shadow: StickerOverlay.Shadow? = nil,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending StickerOverlay {
        let clip = try await image(
            asset: asset,
            duration: .indefinite,
            options: options,
            progress: progress
        )
        var overlay = StickerOverlay(clip.image)
            .position(position)
            .anchor(anchor)
            .opacity(opacity)
            .rotation(rotation)
        if let size {
            overlay = overlay.size(size)
        }
        if let shadow {
            overlay = overlay.shadow(shadow)
        }
        return overlay
    }
}

#endif
