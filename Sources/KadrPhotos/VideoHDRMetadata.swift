import Foundation
import CoreMedia

#if canImport(Photos)
import AVFoundation
#endif

/// HDR / color-space metadata read from a `PHAsset`'s video track.
/// v0.6.
///
/// **What this is.** A passthrough view of the asset's transfer function +
/// color primaries + matrix, plus Dolby Vision detection by codec FourCC.
/// Surfaces enough information for consumers to *detect-and-route* HDR
/// content — "this is HDR10 / HLG / Dolby Vision" — without doing any
/// color-space conversion themselves. The conversion side lives in
/// [`kadr-pro`](https://github.com/SteliyanH/kadr/blob/main/ROADMAP.md#kadr-pro);
/// `kadr-photos` keeps the resolution surface free.
///
/// **Why detect-only matters.** A free editor wants to *show the badge*
/// ("HDR" pill in the project list, "Dolby Vision" overlay on the clip)
/// without committing to the export pipeline. Detection is a 5ms read of
/// the format description; export is a multi-megabyte color-space transform
/// that only paying customers see.
public struct VideoHDRMetadata: Sendable, Equatable {

    /// Transfer function declared on the asset's video track. `.unknown`
    /// when the format description omits the field (rare on iOS-captured
    /// video, common on third-party ingest).
    public let transferFunction: TransferFunction

    /// Color-primaries declared on the asset's video track.
    public let colorPrimaries: ColorPrimaries

    /// Whether the asset is Dolby Vision. Detected by codec FourCC
    /// (`dvh1`, `dvhe`, `dvav`, `dva1`) — the codec type is a stronger
    /// signal than the transfer function for DV because Dolby Vision
    /// streams may carry a base-layer SDR transfer function and the
    /// DV-specific metadata lives in a sidecar NAL unit.
    public let isDolbyVision: Bool

    /// Convenience: `true` when the transfer function declares HDR
    /// (`.pq` HDR10 or `.hlg`) OR when `isDolbyVision` is true. Most
    /// consumers will reach for this rather than inspecting the
    /// individual fields.
    public var isHDR: Bool {
        if isDolbyVision { return true }
        switch transferFunction {
        case .pq, .hlg: return true
        case .bt709, .sRGB, .unknown: return false
        }
    }

    public init(
        transferFunction: TransferFunction,
        colorPrimaries: ColorPrimaries,
        isDolbyVision: Bool
    ) {
        self.transferFunction = transferFunction
        self.colorPrimaries = colorPrimaries
        self.isDolbyVision = isDolbyVision
    }
}

extension VideoHDRMetadata {

    /// Transfer-function classification. The OS exposes more cases via
    /// `CMFormatDescriptionExtension_TransferFunction`, but real-world
    /// consumer video lands in these five buckets — anything else folds
    /// to `.unknown` so the enum doesn't grow with every spec footnote.
    public enum TransferFunction: String, Sendable, Equatable {
        /// ITU-R BT.709 — the SDR default. Most iPhone video without HDR
        /// recording enabled.
        case bt709
        /// sRGB. Rare on video; sometimes set on screen-recording or
        /// time-lapse output.
        case sRGB
        /// SMPTE ST 2084 PQ — HDR10. iPhone 12+ ProRes / 4K HDR.
        case pq
        /// ITU-R BT.2100 HLG — broadcast HDR. iPhone HDR-on capture.
        case hlg
        /// Anything else. Defensive default; consumers treat as SDR.
        case unknown
    }

    /// Color-primaries classification. Same "five-bucket" philosophy as
    /// `TransferFunction`.
    public enum ColorPrimaries: String, Sendable, Equatable {
        case bt709
        case bt2020
        case p3D65
        case unknown
    }
}

#if canImport(Photos)
import Photos

extension PhotosClipResolver {

    /// Read HDR / color-space metadata from a video `PHAsset` without
    /// pulling the full media. v0.6 Tier 1.
    ///
    /// Routes through the same iCloud-aware `AVAsset` loader as
    /// `videoFrameRate(of:)`. Reads the first video track's format
    /// description; returns an `.unknown` transfer / primaries pair for
    /// tracks that don't carry the extensions (rare on iOS-captured
    /// video, possible on ingested third-party content).
    ///
    /// `isDolbyVision` is detected by codec FourCC (`dvh1` / `dvhe` /
    /// `dvav` / `dva1`) rather than transfer function — Dolby Vision
    /// streams sometimes report SDR transfer with DV metadata in a
    /// sidecar NAL unit, so the codec type is the more reliable signal.
    ///
    /// Throws ``PhotosClipError/mediaTypeMismatch(expected:)`` for
    /// non-video assets and ``PhotosClipError/iCloudDownload(localizedDescription:)``
    /// for unreadable iCloud-only assets.
    public static func videoHDRMetadata(of asset: PHAsset) async throws -> VideoHDRMetadata {
        try ensureAuthorized()
        try ensureMediaType(asset: asset, expected: .video)
        let avAsset = try await loadAVAssetForHDRRead(for: asset)
        let tracks = try await avAsset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            return VideoHDRMetadata(
                transferFunction: .unknown,
                colorPrimaries: .unknown,
                isDolbyVision: false
            )
        }
        let descriptions = try await track.load(.formatDescriptions)
        guard let format = descriptions.first else {
            return VideoHDRMetadata(
                transferFunction: .unknown,
                colorPrimaries: .unknown,
                isDolbyVision: false
            )
        }
        return extractMetadata(from: format)
    }

    /// Pure helper: derive the metadata struct from a `CMFormatDescription`.
    /// Internal so the codec-FourCC + extension-key bridge can be tested
    /// against synthetic descriptions without spinning up the full
    /// PHAsset pipeline.
    internal static func extractMetadata(from format: CMFormatDescription) -> VideoHDRMetadata {
        let transfer = transferFunction(from: format)
        let primaries = colorPrimaries(from: format)
        let dolby = isDolbyVisionCodec(CMFormatDescriptionGetMediaSubType(format))
        return VideoHDRMetadata(
            transferFunction: transfer,
            colorPrimaries: primaries,
            isDolbyVision: dolby
        )
    }

    /// Pure helper: map a `CMFormatDescription` extension to our enum.
    /// Internal — exposed for tests that build descriptions from FourCC.
    internal static func transferFunction(
        from format: CMFormatDescription
    ) -> VideoHDRMetadata.TransferFunction {
        guard let raw = CMFormatDescriptionGetExtension(
            format,
            extensionKey: kCMFormatDescriptionExtension_TransferFunction
        ) else { return .unknown }
        guard let cf = raw as? String as CFString? else { return .unknown }
        if CFEqual(cf, kCMFormatDescriptionTransferFunction_ITU_R_709_2) {
            return .bt709
        }
        if CFEqual(cf, kCMFormatDescriptionTransferFunction_sRGB) {
            return .sRGB
        }
        if CFEqual(cf, kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ) {
            return .pq
        }
        if CFEqual(cf, kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG) {
            return .hlg
        }
        return .unknown
    }

    internal static func colorPrimaries(
        from format: CMFormatDescription
    ) -> VideoHDRMetadata.ColorPrimaries {
        guard let raw = CMFormatDescriptionGetExtension(
            format,
            extensionKey: kCMFormatDescriptionExtension_ColorPrimaries
        ) else { return .unknown }
        guard let cf = raw as? String as CFString? else { return .unknown }
        if CFEqual(cf, kCMFormatDescriptionColorPrimaries_ITU_R_709_2) {
            return .bt709
        }
        if CFEqual(cf, kCMFormatDescriptionColorPrimaries_ITU_R_2020) {
            return .bt2020
        }
        if CFEqual(cf, kCMFormatDescriptionColorPrimaries_P3_D65) {
            return .p3D65
        }
        return .unknown
    }

    /// Pure: Dolby Vision codec detection by FourCC. v0.6.
    ///
    /// Dolby Vision streams ship under one of four codec FourCC values
    /// depending on the base codec (AVC vs HEVC) and the profile shape.
    /// We don't inspect the `dvcC` configuration box itself — the FourCC
    /// is a sufficient signal for the "detect-and-route" use case.
    /// Internal so tests can pin the codec list.
    internal static func isDolbyVisionCodec(_ fourCC: CMVideoCodecType) -> Bool {
        // CoreMedia's `kCMVideoCodecType_DolbyVisionHEVC` is `dov1`, not
        // `dvhe` (Apple's naming misleads — the constant maps to the
        // `dov1` codec registration). We check all five FourCCs explicitly
        // so the detection catches every shape Dolby Vision streams ship
        // under in the wild:
        // - `dov1` — Apple's registered DV codec type (from CoreMedia).
        // - `dvhe` — DV HEVC, profiles 4/5/7/8.
        // - `dvh1` — DV HEVC, different container box layout.
        // - `dvav` / `dva1` — DV AVC (legacy / less common).
        return fourCC == kCMVideoCodecType_DolbyVisionHEVC
            || fourCC == fourCCType("dvhe")
            || fourCC == fourCCType("dvh1")
            || fourCC == fourCCType("dvav")
            || fourCC == fourCCType("dva1")
    }

    /// Pure: build a `CMVideoCodecType` from a 4-character FourCC literal.
    /// Internal — used to gate the `dvh1` / `dvav` / `dva1` detection
    /// since AVFoundation only ships a public constant for one of the
    /// four DV codec types (`kCMVideoCodecType_DolbyVisionHEVC` = `dvhe`).
    internal static func fourCCType(_ ascii: String) -> CMVideoCodecType {
        precondition(ascii.utf8.count == 4, "FourCC must be exactly 4 ASCII bytes")
        var result: UInt32 = 0
        for byte in ascii.utf8 {
            result = (result << 8) | UInt32(byte)
        }
        return CMVideoCodecType(result)
    }

    /// Same iCloud-aware loader pattern as `videoFrameRate(of:)` uses, but
    /// renamed so accidental cross-call refactors don't unify them — the
    /// HDR read can tolerate a lower delivery mode in a future optimization,
    /// while frame-rate must always read the high-quality variant.
    private static func loadAVAssetForHDRRead(for asset: PHAsset) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let carrier: HDRAssetCarrier = try await withCheckedThrowingContinuation { continuation in
            let box = HDRContinuationBox(continuation: continuation)
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, info in
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
                guard let avAsset else {
                    box.resumeOnce(throwing: PhotosClipError.missingMedia)
                    return
                }
                box.resumeOnce(returning: HDRAssetCarrier(asset: avAsset))
            }
        }
        return carrier.asset
    }
}

/// `@unchecked Sendable` carrier for `AVAsset` — mirrors the slow-motion
/// path's pattern. Created inside the PHImageManager handler, consumed
/// once after the continuation resumes.
private struct HDRAssetCarrier: @unchecked Sendable {
    let asset: AVAsset
}

/// Single-shot continuation box so the PHImageManager callback (which can
/// fire twice — degraded then high-quality) doesn't double-resume.
private final class HDRContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<HDRAssetCarrier, Error>?
    private let lock = NSLock()

    init(continuation: CheckedContinuation<HDRAssetCarrier, Error>) {
        self.continuation = continuation
    }

    func resumeOnce(returning value: HDRAssetCarrier) {
        lock.lock(); defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(returning: value)
    }

    func resumeOnce(throwing error: Error) {
        lock.lock(); defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(throwing: error)
    }
}

#endif
