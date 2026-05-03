import Foundation
import CoreMedia
import AVFoundation
import Kadr
#if canImport(Photos)
import Photos
#endif

extension PhotosClipResolver {

    #if canImport(Photos)

    /// Resolve a high-frame-rate slow-motion `PHAsset` to a `VideoClip`,
    /// **preserving the original capture frame rate** through the export.
    ///
    /// Slow-motion videos on iOS are captured at 60 / 120 / 240 fps but the
    /// engine's default ``video(asset:options:progress:)`` reaches for
    /// `AVAssetExportPresetHighestQuality`, which downsamples to 30 fps and
    /// kills the slow-motion treatment. This entry point swaps in
    /// `AVAssetExportPresetPassthrough` so the source's native frame rate
    /// survives, then surfaces a `VideoClip` the consumer can speed-control
    /// downstream (e.g. `clip.speed(0.25)` to play 240 fps source at 60 fps
    /// for the classic 8× slow effect).
    ///
    /// - Parameters:
    ///   - asset: A `PHAsset` whose `mediaType` is `.video` and whose
    ///     `mediaSubtypes` includes `.videoHighFrameRate`. Mismatched media
    ///     types throw ``PhotosClipError/wrongMediaType(expected:actual:)``;
    ///     non-slow-mo videos throw ``PhotosClipError/notSlowMotion``.
    ///   - options: Tuning options. The `videoExportPreset` is **always
    ///     overridden** to `AVAssetExportPresetPassthrough` regardless of
    ///     what the caller passes — preserving the source frame rate is the
    ///     whole point of this entry point. Other fields pass through.
    ///   - progress: Optional iCloud-download progress callback.
    ///
    /// - Returns: A `VideoClip` whose `url` points to a temp `.mp4` file
    ///   carrying the original 60 / 120 / 240 fps source. Apply `.speed(_:)`
    ///   or `.speed(curve:)` to render the slow-motion playback.
    public static func slowMotion(
        asset: PHAsset,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending VideoClip {
        try ensureAuthorized()
        try ensureMediaType(asset: asset, expected: .video)
        guard asset.mediaSubtypes.contains(.videoHighFrameRate) else {
            throw PhotosClipError.notSlowMotion
        }

        var slowMoOptions = options
        slowMoOptions.videoExportPreset = AVAssetExportPresetPassthrough
        return try await video(asset: asset, options: slowMoOptions, progress: progress)
    }

    /// Read the nominal frame rate of a video `PHAsset`. Useful when deciding
    /// the speed multiplier for a slow-motion clip — e.g. a 240 fps source
    /// played at `clip.speed(60.0 / 240.0)` reproduces the iOS Photos
    /// slow-motion-region playback rate of 60 fps.
    ///
    /// Issues an iCloud-download request for the underlying `AVAsset` if the
    /// asset isn't local. Throws ``PhotosClipError/notSlowMotion`` if
    /// `mediaSubtypes` doesn't contain `.videoHighFrameRate` — to keep callers
    /// from accidentally using this on regular videos when ``video(asset:options:progress:)``
    /// is the right call.
    ///
    /// - Returns: The video track's `nominalFrameRate` as `Double`. Returns
    ///   `0` if the asset has no video track (defensive — Photos shouldn't
    ///   surface that case for `.video` mediaType, but the resolver doesn't
    ///   trust the OS contract).
    public static func videoFrameRate(of asset: PHAsset) async throws -> Double {
        try ensureAuthorized()
        try ensureMediaType(asset: asset, expected: .video)
        guard asset.mediaSubtypes.contains(.videoHighFrameRate) else {
            throw PhotosClipError.notSlowMotion
        }
        let avAsset = try await loadAVAsset(for: asset)
        let tracks = try await avAsset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { return 0 }
        let frameRate = try await track.load(.nominalFrameRate)
        return Double(frameRate)
    }

    /// Pure helper: compute the speed multiplier needed to render an
    /// `originalFrameRate`-fps source at `playbackFrameRate`. `0.25` is the
    /// classic iOS slow-mo treatment (240 fps source → 60 fps playback).
    /// Returns `1.0` for non-positive inputs (defensive).
    public static func slowMotionSpeed(
        originalFrameRate: Double,
        playbackFrameRate: Double = 30.0
    ) -> Double {
        guard originalFrameRate > 0, playbackFrameRate > 0 else { return 1.0 }
        return playbackFrameRate / originalFrameRate
    }

    // MARK: - Internal AVAsset loader

    private static func loadAVAsset(for asset: PHAsset) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let carrier: AVAssetCarrier = try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation: continuation)
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
                if let error = (info?[PHImageErrorKey] as? Error) {
                    box.resumeOnce(throwing: PhotosClipError.iCloudDownload(
                        localizedDescription: error.localizedDescription
                    ))
                    return
                }
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    box.resumeOnce(throwing: PhotosClipError.iCloudDownload(
                        localizedDescription: "request cancelled"
                    ))
                    return
                }
                guard let avAsset else {
                    box.resumeOnce(throwing: PhotosClipError.missingMedia)
                    return
                }
                box.resumeOnce(returning: AVAssetCarrier(asset: avAsset))
            }
        }
        return carrier.asset
    }

    #endif
}

#if canImport(Photos)
/// `@unchecked Sendable` carrier for `AVAsset` (not `Sendable` itself). Same
/// single-owner-transfer pattern as `ExportSessionCarrier` — created inside the
/// PHImageManager handler, consumed once after the continuation resumes.
private struct AVAssetCarrier: @unchecked Sendable {
    let asset: AVAsset
}
#endif
