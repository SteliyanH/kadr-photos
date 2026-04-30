import Foundation
import CoreGraphics
import AVFoundation
#if canImport(Photos)
import Photos
#endif

extension PhotosClipResolver {

    /// Tuning options for the resolver. Sensible defaults for the common cases —
    /// most callers can use ``Options/default`` unchanged.
    public struct Options: Sendable, Equatable {

        /// Target rendered size for image asset extraction. `.maximumSize` (the default)
        /// fetches at the asset's full resolution.
        public var imageTargetSize: TargetSize

        /// Image content mode passed through to `PHImageManager`. Default `.aspectFill`.
        public var imageContentMode: ImageContentMode

        /// Image delivery mode — quality vs. speed. Default `.highQualityFormat`.
        public var imageDeliveryMode: ImageDeliveryMode

        /// `AVAssetExportSession` preset name for video exports. Default
        /// `AVAssetExportPresetHighestQuality`.
        public var videoExportPreset: String

        public init(
            imageTargetSize: TargetSize = .maximumSize,
            imageContentMode: ImageContentMode = .aspectFill,
            imageDeliveryMode: ImageDeliveryMode = .highQualityFormat,
            videoExportPreset: String = AVAssetExportPresetHighestQuality
        ) {
            self.imageTargetSize = imageTargetSize
            self.imageContentMode = imageContentMode
            self.imageDeliveryMode = imageDeliveryMode
            self.videoExportPreset = videoExportPreset
        }

        public static let `default` = Options()
    }

    /// Either an explicit pixel size or the asset's full resolution.
    public enum TargetSize: Sendable, Equatable {

        /// `PHImageManagerMaximumSize` — the asset's natural pixel size.
        case maximumSize

        /// Explicit pixel target. Width / height in pixels.
        case pixels(width: CGFloat, height: CGFloat)

        /// Resolve to the underlying `CGSize` AVFoundation / Photos expects. Internal —
        /// used by the resolver when building a `PHImageRequestOptions` request.
        internal var cgSize: CGSize {
            switch self {
            case .maximumSize:
                #if canImport(Photos)
                return PHImageManagerMaximumSize
                #else
                return CGSize(width: -1, height: -1)
                #endif
            case .pixels(let w, let h):
                return CGSize(width: w, height: h)
            }
        }
    }

    /// Re-exported subset of `PHImageContentMode`.
    public enum ImageContentMode: Sendable, Equatable {
        case aspectFit
        case aspectFill
        case `default`

        #if canImport(Photos)
        internal var phContentMode: PHImageContentMode {
            switch self {
            case .aspectFit:  return .aspectFit
            case .aspectFill: return .aspectFill
            case .default:    return .default
            }
        }
        #endif
    }

    /// Re-exported subset of `PHImageRequestOptionsDeliveryMode`.
    public enum ImageDeliveryMode: Sendable, Equatable {
        case opportunistic
        case highQualityFormat
        case fastFormat

        #if canImport(Photos)
        internal var phDeliveryMode: PHImageRequestOptionsDeliveryMode {
            switch self {
            case .opportunistic:     return .opportunistic
            case .highQualityFormat: return .highQualityFormat
            case .fastFormat:        return .fastFormat
            }
        }
        #endif
    }
}
