import Foundation
import CoreMedia
import Kadr
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Resolve a ``PhotoPickerResult`` directly to a kadr `Clip`. Inspects the
    /// underlying `PHAsset.mediaType` and dispatches:
    /// - `.video` → ``video(asset:options:progress:)`` (returns `VideoClip`)
    /// - `.image` → ``image(asset:duration:options:progress:)`` (returns `ImageClip`,
    ///   using `imageDuration` as the timeline contribution)
    /// - other (`.audio` / `.unknown`) → throws
    ///   ``PhotosClipError/wrongMediaType(expected:actual:)``
    ///
    /// For Live Photo motion specifically, call ``livePhotoMotion(asset:progress:)``
    /// directly — `clip(from:)` dispatches on `mediaType` (which is `.image` for
    /// Live Photos) and returns the still half.
    ///
    /// The asset is resolved on `MainActor` because `PHAsset.fetchAssets` accesses
    /// the shared photo library.
    public static func clip(
        from result: PhotoPickerResult,
        imageDuration: CMTime = CMTime(seconds: 3, preferredTimescale: 600),
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending any Clip {
        let carrier = try await resolveAsset(for: result)
        switch carrier.mediaType {
        case .video:
            let clip = try await video(asset: carrier.asset, options: options, progress: progress)
            return clip
        case .image:
            let clip = try await image(
                asset: carrier.asset,
                duration: imageDuration,
                options: options,
                progress: progress
            )
            return clip
        default:
            throw PhotosClipError.wrongMediaType(
                expected: .video,
                actual: PhotosMediaKind.from(carrier.mediaType)
            )
        }
    }

    /// Convenience overload accepting `TimeInterval` for the image fallback duration.
    public static func clip(
        from result: PhotoPickerResult,
        imageDuration: TimeInterval,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending any Clip {
        try await clip(
            from: result,
            imageDuration: CMTime(seconds: imageDuration, preferredTimescale: 600),
            options: options,
            progress: progress
        )
    }

    /// Array convenience for ``clip(from:imageDuration:options:progress:)``.
    /// Resolves serially in declaration order — `PHImageManager` handles concurrency
    /// internally, but serial resolution keeps the per-asset progress callback
    /// coherent. The first failure aborts the batch.
    public static func clips(
        from results: [PhotoPickerResult],
        imageDuration: CMTime = CMTime(seconds: 3, preferredTimescale: 600),
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending [any Clip] {
        var out: [any Clip] = []
        out.reserveCapacity(results.count)
        for result in results {
            let c = try await clip(
                from: result,
                imageDuration: imageDuration,
                options: options,
                progress: progress
            )
            out.append(c)
        }
        return out
    }

    /// Convenience overload accepting `TimeInterval` for the image fallback duration.
    public static func clips(
        from results: [PhotoPickerResult],
        imageDuration: TimeInterval,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending [any Clip] {
        try await clips(
            from: results,
            imageDuration: CMTime(seconds: imageDuration, preferredTimescale: 600),
            options: options,
            progress: progress
        )
    }

    // MARK: - Internal helpers

    /// Resolve a `PhotoPickerResult` to its `PHAsset` plus media-type, on `MainActor`.
    /// Wraps the result in an `@unchecked Sendable` carrier so the caller can switch
    /// off `mediaType` and pass `asset` to non-isolated downstream resolvers.
    private static func resolveAsset(for result: PhotoPickerResult) async throws -> AssetCarrier {
        let carrier: AssetCarrier? = await MainActor.run {
            guard let asset = result.resolveAsset() else { return nil }
            return AssetCarrier(asset: asset, mediaType: asset.mediaType)
        }
        guard let carrier else { throw PhotosClipError.missingMedia }
        return carrier
    }
}

/// `@unchecked Sendable` carrier for `PHAsset` + its `mediaType`. Built on `MainActor`
/// (where `PHAsset.fetchAssets` accesses the shared library), then handed off to a
/// non-isolated resolver. Single-owner transfer; no concurrent access.
private struct AssetCarrier: @unchecked Sendable {
    let asset: PHAsset
    let mediaType: PHAssetMediaType
}

#endif
