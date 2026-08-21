import Foundation

/// Human-readable text for every ``PhotosClipError`` case.
///
/// These are the failures most likely to reach a person unchanged, because they
/// happen while someone is picking media and watching for a result. Without
/// `LocalizedError` they bridged to an NSError code.
///
/// Two of them are worth wording carefully rather than mechanically:
///
/// **`unauthorized`** is not a failure the app can retry — it is a decision the
/// person made, and the only route back is Settings. Saying so is more useful
/// than reporting that access was denied.
///
/// **`iCloudDownload`** usually means the asset is in iCloud and the network
/// gave out, not that anything is wrong with the media. A message that implies
/// a corrupt file would send someone hunting for a problem that isn't there.
extension PhotosClipError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "This app doesn't have permission to open your photo library."
        case let .wrongMediaType(expected, actual):
            return "Expected \(expected.describedForPeople) but that item is \(actual.describedForPeople)."
        case .missingMedia:
            return "That item's media couldn't be found."
        case let .iCloudDownload(detail):
            return "Couldn't download that item from iCloud. \(detail)"
        case let .videoExportFailed(detail):
            return "Couldn't prepare that video for editing. \(detail)"
        case .notALivePhoto:
            return "That item isn't a Live Photo."
        case .notSlowMotion:
            return "That item isn't a slow-motion video."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Grant photo access in Settings, then try again."
        case .iCloudDownload:
            return "Check your connection, or open the item in Photos first to download it."
        case .missingMedia:
            return "The item may have been deleted or removed from this device."
        case .wrongMediaType, .notALivePhoto, .notSlowMotion:
            return "Pick a different item."
        case .videoExportFailed:
            // The wrapped detail already carries whatever is knowable.
            return nil
        }
    }
}

extension PhotosMediaKind {
    /// How this kind reads inside a sentence a person will see.
    var describedForPeople: String {
        switch self {
        case .video: return "a video"
        case .image: return "a photo"
        case .audio: return "audio"
        case .unknown: return "an unsupported kind of item"
        }
    }
}
