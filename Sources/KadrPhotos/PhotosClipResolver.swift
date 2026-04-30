import Foundation
import CoreMedia
import AVFoundation
import Kadr
#if canImport(Photos)
import Photos
#endif

/// Bridges `PHAsset` (the Photos library identifier) into kadr's URL- / data-backed
/// clip types. Async because resolving a `PHAsset` typically involves an iCloud
/// round-trip and (for video) an `AVAssetExportSession` re-encode.
///
/// **Authorization.** The resolver checks `PHPhotoLibrary.authorizationStatus(for:)`
/// before issuing any request. If the status is anything other than `.authorized` or
/// `.limited`, ``PhotosClipError/unauthorized`` is thrown immediately. Prompting the
/// user is the consuming app's responsibility.
///
/// **Temp file lifecycle.** ``video(asset:options:progress:)`` writes to
/// `FileManager.default.temporaryDirectory.appendingPathComponent(<uuid>.mp4)`. The
/// file persists until the system cleans the temp directory; callers wanting durable
/// storage should move it themselves.
public enum PhotosClipResolver {

    #if canImport(Photos)

    /// Resolve a video `PHAsset` to a `VideoClip`. Downloads from iCloud if needed,
    /// then exports to a temp file URL via `AVAssetExportSession`.
    ///
    /// - Parameters:
    ///   - asset: A `PHAsset` whose `mediaType` is `.video`. Mismatched media types
    ///     throw ``PhotosClipError/wrongMediaType(expected:actual:)``.
    ///   - options: Tuning options. Defaults are sensible.
    ///   - progress: Optional callback fired during the iCloud download phase, with a
    ///     fractional progress value in `0...1`.
    ///
    /// - Returns: A `VideoClip` whose `url` points to a temp `.mp4` file.
    public static func video(
        asset: PHAsset,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending VideoClip {
        try ensureAuthorized()
        try ensureMediaType(asset: asset, expected: .video)

        let requestOptions = PHVideoRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .highQualityFormat
        if let progress {
            requestOptions.progressHandler = { fraction, _, _, _ in
                progress(fraction)
            }
        }

        let exportPreset = options.videoExportPreset
        let exportSession = try await requestExportSession(
            for: asset,
            options: requestOptions,
            preset: exportPreset
        )

        let outputURL = makeTempVideoURL()
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return VideoClip(url: outputURL)
        case .cancelled:
            throw PhotosClipError.videoExportFailed(localizedDescription: "export cancelled")
        case .failed:
            let desc = exportSession.error?.localizedDescription ?? "export failed (status \(exportSession.status.rawValue))"
            throw PhotosClipError.videoExportFailed(localizedDescription: desc)
        default:
            throw PhotosClipError.videoExportFailed(
                localizedDescription: "unexpected status \(exportSession.status.rawValue)"
            )
        }
    }

    // MARK: - Internal helpers

    /// Throws ``PhotosClipError/unauthorized`` if the photo library isn't accessible.
    /// `.limited` (iOS 14+ partial access) is treated as authorized — limited assets
    /// the user has shared work fine through `PHImageManager`.
    internal static func ensureAuthorized() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        default:
            throw PhotosClipError.unauthorized
        }
    }

    /// Throws ``PhotosClipError/wrongMediaType(expected:actual:)`` if the asset's
    /// media type doesn't match what was requested.
    internal static func ensureMediaType(asset: PHAsset, expected: PhotosMediaKind) throws {
        let actual = PhotosMediaKind.from(asset.mediaType)
        guard actual == expected else {
            throw PhotosClipError.wrongMediaType(expected: expected, actual: actual)
        }
    }

    /// Wrap `PHImageManager.requestExportSession` in an `async throws` continuation.
    /// Returned through an `@unchecked Sendable` carrier because `AVAssetExportSession`
    /// isn't `Sendable` but we own the lifetime — the result handler fires once and the
    /// session is then used only on the awaiting actor.
    private static func requestExportSession(
        for asset: PHAsset,
        options: PHVideoRequestOptions,
        preset: String
    ) async throws -> AVAssetExportSession {
        let carrier: ExportSessionCarrier = try await withCheckedThrowingContinuation { continuation in
            let box = ContinuationBox(continuation: continuation)
            PHImageManager.default().requestExportSession(
                forVideo: asset,
                options: options,
                exportPreset: preset
            ) { exportSession, info in
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
                guard let exportSession else {
                    box.resumeOnce(throwing: PhotosClipError.missingMedia)
                    return
                }
                box.resumeOnce(returning: ExportSessionCarrier(session: exportSession))
            }
        }
        return carrier.session
    }

    /// Builds a fresh temp-file URL for video export. Pure — exposed for tests.
    internal static func makeTempVideoURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }

    #endif
}

// MARK: - PhotosMediaKind bridge

#if canImport(Photos)
extension PhotosMediaKind {
    /// Map a `PHAssetMediaType` to a kadr-side ``PhotosMediaKind``. Pure — exposed for
    /// tests.
    public static func from(_ type: PHAssetMediaType) -> PhotosMediaKind {
        switch type {
        case .video:    return .video
        case .image:    return .image
        case .audio:    return .audio
        case .unknown:  return .unknown
        @unknown default: return .unknown
        }
    }
}
#endif

/// `@unchecked Sendable` carrier for `AVAssetExportSession`. The session is created
/// inside `requestExportSession`'s result handler and consumed by the caller after
/// the continuation resumes — single-owner transfer, no concurrent access.
private struct ExportSessionCarrier: @unchecked Sendable {
    let session: AVAssetExportSession
}

// MARK: - Continuation safety

/// Wraps a `CheckedContinuation` so callers can resume from the PHImageManager result
/// handler — which Photos may invoke more than once for the opportunistic delivery
/// mode. We only honor the first resume; subsequent calls are dropped.
internal final class ContinuationBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resumeOnce(returning value: sending T) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
    }

    func resumeOnce(throwing error: Error) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(throwing: error)
    }
}
