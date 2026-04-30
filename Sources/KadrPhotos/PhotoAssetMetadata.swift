import Foundation
import CoreGraphics
import CoreLocation
#if canImport(Photos)
import Photos
#endif

/// Snapshot of a `PHAsset`'s metadata. Read via
/// ``PhotosClipResolver/metadata(of:)`` — synchronous (no iCloud round-trip; reads
/// PHAsset properties only).
///
/// **Sendability.** Marked `@unchecked Sendable` because `CLLocation` is thread-safe
/// (immutable after construction) but not `Swift.Sendable`. All other fields are
/// genuinely `Sendable`. Future Apple SDK updates may make `CLLocation` `Sendable`;
/// when they do, the unchecked annotation can drop.
public struct PhotoAssetMetadata: Equatable, @unchecked Sendable {

    /// When the user / device captured the asset.
    public let creationDate: Date?

    /// Last-edit timestamp, distinct from `creationDate` for items the user has
    /// modified in Photos (crops, filters, etc.).
    public let modificationDate: Date?

    /// GPS / coarse-grained location at capture time. Absent for assets without
    /// location services or for indoor captures.
    public let location: CLLocation?

    /// Native pixel size of the asset (`pixelWidth` × `pixelHeight`).
    public let pixelSize: CGSize

    /// Source-asset duration in seconds. `0` for stills.
    public let videoDuration: TimeInterval

    /// Subtype flags — Live Photo, panorama, screenshot, etc.
    public let subtypes: PhotoAssetSubtypes

    /// `true` if the user has hearted the asset in Photos.
    public let isFavorite: Bool

    /// Stable string identifier for the asset's burst, when it's part of one.
    /// `nil` for stand-alone assets.
    public let burstIdentifier: String?

    /// High-level media kind, mirroring ``PhotosMediaKind``.
    public let mediaKind: PhotosMediaKind

    public init(
        creationDate: Date?,
        modificationDate: Date?,
        location: CLLocation?,
        pixelSize: CGSize,
        videoDuration: TimeInterval,
        subtypes: PhotoAssetSubtypes,
        isFavorite: Bool,
        burstIdentifier: String?,
        mediaKind: PhotosMediaKind
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.location = location
        self.pixelSize = pixelSize
        self.videoDuration = videoDuration
        self.subtypes = subtypes
        self.isFavorite = isFavorite
        self.burstIdentifier = burstIdentifier
        self.mediaKind = mediaKind
    }

    public static func == (lhs: PhotoAssetMetadata, rhs: PhotoAssetMetadata) -> Bool {
        lhs.creationDate == rhs.creationDate
            && lhs.modificationDate == rhs.modificationDate
            && lhs.location?.coordinate.latitude == rhs.location?.coordinate.latitude
            && lhs.location?.coordinate.longitude == rhs.location?.coordinate.longitude
            && lhs.pixelSize == rhs.pixelSize
            && lhs.videoDuration == rhs.videoDuration
            && lhs.subtypes == rhs.subtypes
            && lhs.isFavorite == rhs.isFavorite
            && lhs.burstIdentifier == rhs.burstIdentifier
            && lhs.mediaKind == rhs.mediaKind
    }
}

/// Re-exported subset of `PHAssetMediaSubtype` so consumers don't have to import
/// `Photos` to read subtype flags. `OptionSet`-shaped: assets can carry several
/// flags simultaneously (e.g. a Live Photo HDR panorama).
public struct PhotoAssetSubtypes: OptionSet, Sendable, Equatable {

    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let livePhoto      = PhotoAssetSubtypes(rawValue: 1 << 0)
    public static let highFrameRate  = PhotoAssetSubtypes(rawValue: 1 << 1)
    public static let timelapse      = PhotoAssetSubtypes(rawValue: 1 << 2)
    public static let panorama       = PhotoAssetSubtypes(rawValue: 1 << 3)
    public static let hdr            = PhotoAssetSubtypes(rawValue: 1 << 4)
    public static let screenshot     = PhotoAssetSubtypes(rawValue: 1 << 5)
    public static let depthEffect    = PhotoAssetSubtypes(rawValue: 1 << 6)
    public static let cinematic      = PhotoAssetSubtypes(rawValue: 1 << 7)
    public static let spatial        = PhotoAssetSubtypes(rawValue: 1 << 8)
    public static let streamed       = PhotoAssetSubtypes(rawValue: 1 << 9)

    #if canImport(Photos)
    /// Bridge a `PHAssetMediaSubtype` value to a kadr-side ``PhotoAssetSubtypes``
    /// option set. Pure — exposed for testing the mapping in isolation.
    public static func from(_ phSubtypes: PHAssetMediaSubtype) -> PhotoAssetSubtypes {
        var out: PhotoAssetSubtypes = []
        if phSubtypes.contains(.photoLive)            { out.insert(.livePhoto) }
        if phSubtypes.contains(.videoHighFrameRate)   { out.insert(.highFrameRate) }
        if phSubtypes.contains(.videoTimelapse)       { out.insert(.timelapse) }
        if phSubtypes.contains(.photoPanorama)        { out.insert(.panorama) }
        if phSubtypes.contains(.photoHDR)             { out.insert(.hdr) }
        if phSubtypes.contains(.photoScreenshot)      { out.insert(.screenshot) }
        if phSubtypes.contains(.photoDepthEffect)     { out.insert(.depthEffect) }
        if #available(iOS 15, macOS 12, *) {
            if phSubtypes.contains(.videoCinematic)   { out.insert(.cinematic) }
        }
        if phSubtypes.contains(.videoStreamed)        { out.insert(.streamed) }
        // .spatial is reserved in our OptionSet for forward compatibility — Apple's
        // PHAssetMediaSubtype.spatialMedia ships in iOS 18+ / visionOS 2+. We don't
        // bridge it yet to keep the iOS-16 deployment floor clean.
        return out
    }
    #endif
}
