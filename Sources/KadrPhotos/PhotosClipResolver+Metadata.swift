import Foundation
import CoreGraphics
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Snapshot a `PHAsset`'s metadata. Synchronous — reads PHAsset properties
    /// directly; no `PHImageManager` request, no iCloud round-trip.
    public static func metadata(of asset: PHAsset) -> PhotoAssetMetadata {
        PhotoAssetMetadata(
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            location: asset.location,
            pixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            videoDuration: asset.duration,
            subtypes: PhotoAssetSubtypes.from(asset.mediaSubtypes),
            isFavorite: asset.isFavorite,
            burstIdentifier: asset.burstIdentifier,
            mediaKind: PhotosMediaKind.from(asset.mediaType)
        )
    }
}

#endif
