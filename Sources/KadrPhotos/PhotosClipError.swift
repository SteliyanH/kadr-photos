import Foundation

/// Errors thrown by ``PhotosClipResolver`` when bridging a `PHAsset` to a kadr clip.
public enum PhotosClipError: Error, Equatable {

    /// Caller hasn't been granted read access to the photo library. The resolver checks
    /// `PHPhotoLibrary.authorizationStatus(for:)` before issuing any request and throws
    /// this immediately if the status is anything other than `.authorized` or `.limited`.
    /// Prompt the user via `PHPhotoLibrary.requestAuthorization` first; that's the
    /// consuming app's responsibility (it owns the UI and the entitlement string).
    case unauthorized

    /// The `PHAsset`'s `mediaType` doesn't match the requested resolver — e.g. asking
    /// `video(asset:)` for an image asset. Carries the expected and actual kinds so
    /// callers can route or surface a useful message.
    case wrongMediaType(expected: PhotosMediaKind, actual: PhotosMediaKind)

    /// The asset disappeared between request and result, or `PHImageManager` returned
    /// no usable resource. Asset deletion mid-flight is the most likely cause.
    case missingMedia

    /// iCloud download failed. Underlying error description carried so callers can
    /// surface it without having to import `Photos`.
    case iCloudDownload(localizedDescription: String)

    /// `AVAssetExportSession` failed to produce the video clip's URL. Typically a
    /// preset-incompatibility or disk-space issue.
    case videoExportFailed(localizedDescription: String)
}

/// High-level kind of a `PHAsset` — re-exported so consumers don't have to import
/// `Photos` just to read this off an error.
public enum PhotosMediaKind: Sendable, Equatable {
    case video
    case image
    case audio
    case unknown
}
