import Testing
import Foundation
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.5 Tier 2 — album asset listing. The PHAsset / PHAssetCollection
/// paths require an actual Photos library (and authorization), so the
/// PHPhotoLibrary-touching paths are integration-tested in the example app.
/// Pure-side surface tests live here.
struct AlbumListingTests {

    #if canImport(Photos)

    // MARK: - smartAlbum lookup returns nil safely without authorization

    /// `PHAssetCollection.fetchAssetCollections` is a synchronous read against
    /// the local index. On a CI machine with no Photos library, every smart
    /// album fetch returns nil. The helper must surface that as `nil` rather
    /// than throwing or trapping.
    @Test func smartAlbumReturnsNilOrCollectionWithoutThrowing() {
        let result = PhotosClipResolver.smartAlbum(.smartAlbumSlomoVideos)
        // Either nil (no library / no slo-mo album) or a real collection.
        // The test passes as long as it doesn't trap. Result-state assertion
        // is meaningless on CI because it depends on the host's library.
        _ = result
    }

    @Test func smartAlbumHandlesVariousSubtypes() {
        // Sanity: every documented subtype lookup compiles + runs.
        _ = PhotosClipResolver.smartAlbum(.smartAlbumFavorites)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumTimelapses)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumRecentlyAdded)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumScreenshots)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumPanoramas)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumLivePhotos)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumVideos)
        _ = PhotosClipResolver.smartAlbum(.smartAlbumUserLibrary)
    }

    #endif
}
