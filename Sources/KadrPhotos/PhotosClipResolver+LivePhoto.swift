import Foundation
import CoreMedia
import Kadr
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Extract the motion (paired video) half of a Live Photo `PHAsset` as a
    /// `VideoClip`. The asset must satisfy `mediaSubtypes.contains(.photoLive)`;
    /// otherwise throws ``PhotosClipError/notALivePhoto``.
    ///
    /// Iterates `PHAssetResource.assetResources(for:)`, picks the
    /// `.pairedVideo` resource, and writes it to a temp `.mov` URL via
    /// `PHAssetResourceManager.writeData(for:toFile:options:completionHandler:)`.
    /// iCloud download happens automatically when needed.
    ///
    /// - Parameters:
    ///   - asset: A Live Photo `PHAsset`.
    ///   - progress: Optional `@Sendable (Double) -> Void` callback fired during
    ///     iCloud download.
    /// - Returns: A `VideoClip` whose `url` points to a temp `.mov` file.
    public static func livePhotoMotion(
        asset: PHAsset,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending VideoClip {
        try ensureAuthorized()
        try ensureLivePhoto(asset: asset)

        let resources = PHAssetResource.assetResources(for: asset)
        guard let pairedVideo = resources.first(where: { $0.type == .pairedVideo }) else {
            throw PhotosClipError.missingMedia
        }

        let outputURL = makeTempLivePhotoMotionURL()
        // Pre-clear any conflicting file so writeData doesn't fail with EEXIST.
        try? FileManager.default.removeItem(at: outputURL)

        let requestOptions = PHAssetResourceRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        if let progress {
            requestOptions.progressHandler = { fraction in
                progress(fraction)
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = ContinuationBox(continuation: continuation)
            PHAssetResourceManager.default().writeData(
                for: pairedVideo,
                toFile: outputURL,
                options: requestOptions
            ) { error in
                if let error {
                    box.resumeOnce(throwing: PhotosClipError.iCloudDownload(
                        localizedDescription: error.localizedDescription
                    ))
                    return
                }
                box.resumeOnce(returning: ())
            }
        }

        return VideoClip(url: outputURL)
    }

    /// Extract the still (photo) half of a Live Photo `PHAsset` as an `ImageClip`
    /// of the requested duration. Symmetric counterpart to
    /// ``livePhotoMotion(asset:progress:)``.
    ///
    /// Implemented as a guarded wrapper around ``image(asset:duration:options:progress:)``:
    /// throws ``PhotosClipError/notALivePhoto`` if the asset isn't a Live Photo;
    /// otherwise delegates to the regular image resolver.
    public static func livePhotoStill(
        asset: PHAsset,
        duration: CMTime,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip {
        try ensureLivePhoto(asset: asset)
        return try await image(asset: asset, duration: duration, options: options, progress: progress)
    }

    /// Convenience overload accepting `TimeInterval` (seconds) for the still's
    /// timeline contribution.
    public static func livePhotoStill(
        asset: PHAsset,
        duration: TimeInterval,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip {
        try await livePhotoStill(
            asset: asset,
            duration: CMTime(seconds: duration, preferredTimescale: 600),
            options: options,
            progress: progress
        )
    }

    // MARK: - Internal helpers

    /// Throws ``PhotosClipError/notALivePhoto`` if the asset's media subtypes don't
    /// include `.photoLive`. Pure — exposed for testing the guard logic in isolation.
    internal static func ensureLivePhoto(asset: PHAsset) throws {
        guard asset.mediaSubtypes.contains(.photoLive) else {
            throw PhotosClipError.notALivePhoto
        }
    }

    /// Builds a fresh temp-file URL for Live Photo motion extraction. Pure — exposed
    /// for tests. `.mov` extension matches what Photos delivers (the paired video is
    /// always QuickTime).
    internal static func makeTempLivePhotoMotionURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
    }
}

#endif
