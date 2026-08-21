import Testing
import Foundation
@testable import KadrPhotos

/// What a person sees when picking media fails.
///
/// These reach people more often than most errors in the family, because they
/// happen while someone is actively waiting for a picker to produce something.
struct PhotosClipErrorLocalizedTests {

    private static let allCases: [PhotosClipError] = [
        .unauthorized,
        .wrongMediaType(expected: .video, actual: .image),
        .missingMedia,
        .iCloudDownload(localizedDescription: "The network connection was lost."),
        .videoExportFailed(localizedDescription: "The operation could not be completed."),
        .notALivePhoto,
        .notSlowMotion
    ]

    @Test(arguments: allCases)
    func everyCaseSaysSomethingAndIsNotAnNSErrorCode(error: PhotosClipError) {
        #expect(error.errorDescription?.isEmpty == false)
        #expect(!error.localizedDescription.contains("PhotosClipError error"))
    }

    @Test func aPermissionRefusalPointsAtSettingsRatherThanRetrying() {
        // Nothing the app can retry — the only route back is Settings.
        let e = PhotosClipError.unauthorized
        #expect(e.recoverySuggestion?.contains("Settings") == true)
    }

    @Test func aFailedICloudDownloadDoesNotImplyABrokenFile() {
        // Usually the network, not the media. Implying corruption would send
        // someone hunting for a problem that isn't there.
        let e = PhotosClipError.iCloudDownload(localizedDescription: "The network connection was lost.")
        let text = (e.errorDescription ?? "") + " " + (e.recoverySuggestion ?? "")
        #expect(text.contains("iCloud"))
        #expect(text.lowercased().contains("connection"))
        #expect(!text.lowercased().contains("corrupt"))
    }

    @Test func mediaKindsReadAsEnglishInsideASentence() {
        let e = PhotosClipError.wrongMediaType(expected: .video, actual: .image)
        let text = e.errorDescription ?? ""
        #expect(text.contains("a video"))
        #expect(text.contains("a photo"))
        // Not the raw case names.
        #expect(!text.contains("image)"))
    }

    @Test func theUnknownKindStillReadsAsASentence() {
        #expect(PhotosMediaKind.unknown.describedForPeople.isEmpty == false)
        let e = PhotosClipError.wrongMediaType(expected: .audio, actual: .unknown)
        #expect(e.errorDescription?.contains("unsupported") == true)
    }

    @Test func aWrappedDetailIsNotDuplicatedByASuggestion() {
        // The wrapped text already carries whatever is knowable.
        #expect(PhotosClipError.videoExportFailed(localizedDescription: "x").recoverySuggestion == nil)
    }
}
