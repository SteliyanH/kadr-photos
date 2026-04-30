import Foundation
import CoreMedia
import CoreGraphics
import Kadr
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Resolve an image `PHAsset` to an `ImageClip` of the given duration. Downloads
    /// from iCloud if needed.
    ///
    /// - Parameters:
    ///   - asset: A `PHAsset` whose `mediaType` is `.image`. Mismatched media types
    ///     throw ``PhotosClipError/wrongMediaType(expected:actual:)``.
    ///   - duration: Timeline contribution of the resulting `ImageClip`.
    ///   - options: Tuning options. ``Options/imageTargetSize``,
    ///     ``Options/imageContentMode``, and ``Options/imageDeliveryMode`` apply here.
    ///   - progress: Optional callback fired during the iCloud download phase.
    ///
    /// - Returns: An `ImageClip` whose `image` is the decoded asset at the requested
    ///   target size.
    public static func image(
        asset: PHAsset,
        duration: CMTime,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip {
        try ensureAuthorized()
        try ensureMediaType(asset: asset, expected: .image)

        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = options.imageDeliveryMode.phDeliveryMode
        // Always wait for the high-quality result rather than firing the handler twice
        // for opportunistic delivery — async semantics expect a single resolution.
        requestOptions.isSynchronous = false
        if let progress {
            requestOptions.progressHandler = { fraction, _, _, _ in
                progress(fraction)
            }
        }

        let carrier: ImageCarrier = try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation: continuation)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: options.imageTargetSize.cgSize,
                contentMode: options.imageContentMode.phContentMode,
                options: requestOptions
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
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
                // Skip the degraded preview that opportunistic delivery may emit first;
                // wait for the final high-quality image. With deliveryMode set to
                // .highQualityFormat (the default), this typically fires only once.
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                    return
                }
                guard let image else {
                    box.resumeOnce(throwing: PhotosClipError.missingMedia)
                    return
                }
                box.resumeOnce(returning: ImageCarrier(image: image))
            }
        }
        return ImageClip(carrier.image, duration: duration)
    }

    /// Convenience overload accepting `TimeInterval` (seconds) for the clip duration.
    public static func image(
        asset: PHAsset,
        duration: TimeInterval,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip {
        try await image(
            asset: asset,
            duration: CMTime(seconds: duration, preferredTimescale: 600),
            options: options,
            progress: progress
        )
    }
}

/// `@unchecked Sendable` carrier for `PlatformImage` (`UIImage` / `NSImage`). Both are
/// thread-safe for read after construction; the continuation transfers ownership from
/// the result handler to the awaiting actor without further mutation.
private struct ImageCarrier: @unchecked Sendable {
    let image: PlatformImage
}

#endif
