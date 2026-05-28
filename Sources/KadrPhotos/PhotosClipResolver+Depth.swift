import Foundation
import AVFoundation
import CoreVideo
import ImageIO
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)

extension PhotosClipResolver {

    /// Extract the depth map carried alongside a Live Photo's still image. iPhone 12+
    /// Live Photos taken in Portrait mode (or with the LiDAR-equipped models) embed a
    /// disparity / depth auxiliary image inside the HEIC still; this surface reads it
    /// out as a `CVPixelBuffer` so callers can feed it into chroma-key-style filtering
    /// (free) or kadr-pro's Vision-based cutout pipeline.
    ///
    /// Detection-only — no Vision processing happens here, and no color-space or
    /// normalization is applied. Returns `nil` for any non-depth asset (non-Live-Photo,
    /// Live Photo without depth, iCloud unreachable, decoding failure). Free per the
    /// v0.6 scope; the *transform* side (segmentation, smart cutout) lives in kadr-pro.
    ///
    /// Aux-type preference order: disparity → depth → portrait-effects matte. The first
    /// usable channel wins; the helper [``selectDepthAuxiliaryType(from:)``] picks it.
    ///
    /// - Parameter asset: A `PHAsset` — expected to be a Live Photo, but any asset is
    ///   accepted (and yields `nil` if it isn't depth-bearing).
    /// - Returns: The depth `CVPixelBuffer`, or `nil` if the asset doesn't expose one.
    public static func depthMap(from asset: PHAsset) async -> CVPixelBuffer? {
        guard asset.mediaSubtypes.contains(.photoLive) else { return nil }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let photoResource = resources.first(where: { $0.type == .photo })
            ?? resources.first(where: { $0.type == .fullSizePhoto })
        else { return nil }

        let data = await readResourceData(photoResource)
        guard let data else { return nil }

        return depthPixelBuffer(fromImageData: data)
    }

    // MARK: - Pure helpers

    /// Aux-type preference order — disparity first (16-bit float, normalized 1/distance
    /// in meters), then depth (raw distance), then portrait-effects matte (alpha-style
    /// matte rather than true depth). Pure — exposed for tests.
    internal static let depthAuxiliaryTypePreference: [String] = [
        kCGImageAuxiliaryDataTypeDisparity as String,
        kCGImageAuxiliaryDataTypeDepth as String,
        kCGImageAuxiliaryDataTypePortraitEffectsMatte as String,
    ]

    /// Pick the highest-priority aux-data type that appears in `available`. Returns
    /// `nil` if the asset exposes no usable depth-style auxiliary. Pure — exposed for
    /// tests so the priority logic is verifiable without a real image source.
    internal static func selectDepthAuxiliaryType(from available: [String]) -> String? {
        depthAuxiliaryTypePreference.first(where: available.contains)
    }

    /// Decode a depth `CVPixelBuffer` from raw HEIC / JPEG bytes. Iterates the aux-type
    /// preference list and returns the first match. Internal — exercised end-to-end via
    /// ``depthMap(from:)``; surfaced separately so tests can feed deterministic bytes.
    internal static func depthPixelBuffer(fromImageData data: Data) -> CVPixelBuffer? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        for auxType in depthAuxiliaryTypePreference {
            guard let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(
                source,
                0,
                auxType as CFString
            ) as? [AnyHashable: Any] else { continue }
            guard let depthData = try? AVDepthData(fromDictionaryRepresentation: info) else {
                continue
            }
            return depthData.depthDataMap
        }
        return nil
    }

    /// Read a `PHAssetResource` into memory via `PHAssetResourceManager.requestData`.
    /// Network access is allowed (matches ``livePhotoMotion(asset:progress:)``). Returns
    /// `nil` on any failure — depth extraction stays best-effort.
    private static func readResourceData(_ resource: PHAssetResource) async -> Data? {
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            let box = DepthDataBox(continuation: continuation)
            var collected = Data()
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in
                    collected.append(chunk)
                },
                completionHandler: { error in
                    if error != nil {
                        box.resumeOnce(returning: nil)
                    } else {
                        box.resumeOnce(returning: collected)
                    }
                }
            )
        }
    }
}

// MARK: - Continuation safety

/// Mirror of ``ContinuationBox`` for the non-throwing `Data?` continuation used by
/// depth extraction. `PHAssetResourceManager.requestData` may invoke the completion
/// handler once; the box guards against double-resume just in case.
private final class DepthDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data?, Never>?

    init(continuation: CheckedContinuation<Data?, Never>) {
        self.continuation = continuation
    }

    func resumeOnce(returning value: Data?) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
    }
}

#endif
