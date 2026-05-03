import Foundation
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// List the `PHAsset`s in a given album in the album's natural order
    /// (Photos defaults to creation-date ascending, overridable via the
    /// `sort` argument). Useful in editor apps that want to discover the
    /// contents of a smart album like *Slo-mo* or *Favorites* and resolve
    /// each entry through ``video(asset:options:progress:)``,
    /// ``image(asset:duration:options:progress:)``, or ``clip(from:)``.
    ///
    /// **Why not just scope the picker?** `PHPickerConfiguration` doesn't
    /// expose an album-scope option in any current Apple SDK — the picker
    /// always shows the user's full library. This method is the
    /// programmatic equivalent: list the assets, build your own UI.
    ///
    /// - Parameters:
    ///   - collection: The album / smart album to list.
    ///   - mediaType: Optional filter by ``PhotosMediaKind``. `nil` returns
    ///     every asset in the album regardless of type.
    /// - Returns: The asset list. Empty if the album has no items, or if
    ///   the user-photos authorization status is `.limited` and none of
    ///   the limited subset is in the album.
    public static func assets(
        in collection: PHAssetCollection,
        mediaType: PhotosMediaKind? = nil
    ) async throws -> [PHAsset] {
        try ensureAuthorized()
        let options = PHFetchOptions()
        if let mediaType, let phType = phMediaType(from: mediaType) {
            options.predicate = NSPredicate(format: "mediaType = %d", phType.rawValue)
        }
        return await Task.detached(priority: .userInitiated) {
            var results: [PHAsset] = []
            let fetch = PHAsset.fetchAssets(in: collection, options: options)
            fetch.enumerateObjects { asset, _, _ in
                results.append(asset)
            }
            return results
        }.value
    }

    /// Look up a built-in smart album by its `PHAssetCollectionSubtype`.
    /// Returns `nil` if the album doesn't exist on this device (e.g.
    /// `.smartAlbumSlomoVideos` on a device without slow-motion captures).
    ///
    /// Common smart albums:
    /// - `.smartAlbumSlomoVideos` — iPhone slow-motion captures
    /// - `.smartAlbumTimelapses` — iPhone time-lapses
    /// - `.smartAlbumFavorites` — user-hearted assets
    /// - `.smartAlbumRecentlyAdded`
    /// - `.smartAlbumScreenshots`
    /// - `.smartAlbumPanoramas`
    /// - `.smartAlbumLivePhotos`
    /// - `.smartAlbumVideos` (all videos)
    /// - `.smartAlbumUserLibrary` (Camera Roll)
    public static func smartAlbum(_ subtype: PHAssetCollectionSubtype) -> PHAssetCollection? {
        let result = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: subtype,
            options: nil
        )
        return result.firstObject
    }

    // MARK: - Internal mapping

    private static func phMediaType(from kind: PhotosMediaKind) -> PHAssetMediaType? {
        switch kind {
        case .video:    return .video
        case .image:    return .image
        case .audio:    return .audio
        case .unknown:  return nil
        }
    }
}

#endif
