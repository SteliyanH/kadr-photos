import XCTest
import CoreMedia
@testable import KadrPhotos

#if canImport(AVFoundation)
import AVFoundation
#endif

/// v0.6 Tier 1 — tests for HDR metadata extraction. The PHAsset side is
/// covered by manual QA against real Photos library content; this file
/// tests the pure extraction layer against synthesized `CMFormatDescription`
/// instances so the parser can be pinned without a Photos dependency.
final class VideoHDRMetadataTests: XCTestCase {

    // MARK: - Struct shape

    func testIsHDRConvenienceCoversPQAndHLG() {
        XCTAssertTrue(VideoHDRMetadata(
            transferFunction: .pq,
            colorPrimaries: .bt2020,
            isDolbyVision: false
        ).isHDR)
        XCTAssertTrue(VideoHDRMetadata(
            transferFunction: .hlg,
            colorPrimaries: .bt2020,
            isDolbyVision: false
        ).isHDR)
    }

    func testIsHDRFalseForSDRTransferEvenWithBT2020Primaries() {
        // BT.2020 primaries alone don't mean HDR — the transfer function
        // is what gates the classification. A weird-but-legal `bt709`
        // transfer on `bt2020` primaries stays SDR.
        XCTAssertFalse(VideoHDRMetadata(
            transferFunction: .bt709,
            colorPrimaries: .bt2020,
            isDolbyVision: false
        ).isHDR)
    }

    func testIsHDRTrueForDolbyVisionRegardlessOfTransfer() {
        // Dolby Vision sometimes ships a base-layer SDR transfer function
        // with DV metadata in a sidecar. The codec FourCC is the load-
        // bearing signal — isHDR must respect it even when the transfer
        // function reads `.bt709` (SDR).
        XCTAssertTrue(VideoHDRMetadata(
            transferFunction: .bt709,
            colorPrimaries: .bt2020,
            isDolbyVision: true
        ).isHDR)
    }

    func testIsHDRFalseForUnknownTransferAndNotDolbyVision() {
        // Defensive default — when we can't read the format, treat as
        // SDR rather than guess HDR.
        XCTAssertFalse(VideoHDRMetadata(
            transferFunction: .unknown,
            colorPrimaries: .unknown,
            isDolbyVision: false
        ).isHDR)
    }

    // MARK: - FourCC helper

    #if canImport(AVFoundation)

    func testFourCCTypeBuildsExpectedCodecType() {
        // 'dvh1' = 0x64766831 (d=100 v=118 h=104 1=49)
        let expected: CMVideoCodecType = (100 << 24) | (118 << 16) | (104 << 8) | 49
        XCTAssertEqual(PhotosClipResolver.fourCCType("dvh1"), expected)
    }

    func testIsDolbyVisionCodecRecognizesAllFourFourCCs() {
        XCTAssertTrue(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("dvh1")))
        XCTAssertTrue(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("dvhe")))
        XCTAssertTrue(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("dvav")))
        XCTAssertTrue(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("dva1")))
    }

    func testIsDolbyVisionCodecRejectsRegularHEVC() {
        // 'hvc1' — regular HEVC, not Dolby Vision. Must NOT match.
        XCTAssertFalse(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("hvc1")))
        XCTAssertFalse(PhotosClipResolver.isDolbyVisionCodec(PhotosClipResolver.fourCCType("avc1")))
    }

    // MARK: - Format description extraction

    /// Build a `CMVideoFormatDescription` with the requested color extensions
    /// attached. Returns nil if construction fails (shouldn't on iOS/macOS
    /// with these standard keys; defensive for the test harness).
    private func makeFormat(
        codec: CMVideoCodecType,
        transfer: CFString?,
        primaries: CFString?
    ) -> CMFormatDescription? {
        var extensions: [CFString: CFTypeRef] = [:]
        if let transfer {
            extensions[kCMFormatDescriptionExtension_TransferFunction] = transfer
        }
        if let primaries {
            extensions[kCMFormatDescriptionExtension_ColorPrimaries] = primaries
        }
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: codec,
            width: 1920,
            height: 1080,
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &format
        )
        return status == noErr ? format : nil
    }

    func testExtractsPQTransferForHDR10() {
        guard let format = makeFormat(
            codec: kCMVideoCodecType_HEVC,
            transfer: kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ,
            primaries: kCMFormatDescriptionColorPrimaries_ITU_R_2020
        ) else { return XCTFail("Could not synthesize format description") }

        let meta = PhotosClipResolver.extractMetadata(from: format)
        XCTAssertEqual(meta.transferFunction, .pq)
        XCTAssertEqual(meta.colorPrimaries, .bt2020)
        XCTAssertFalse(meta.isDolbyVision, "HEVC alone isn't Dolby Vision")
        XCTAssertTrue(meta.isHDR)
    }

    func testExtractsHLGTransferForBroadcastHDR() {
        guard let format = makeFormat(
            codec: kCMVideoCodecType_HEVC,
            transfer: kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG,
            primaries: kCMFormatDescriptionColorPrimaries_ITU_R_2020
        ) else { return XCTFail("Could not synthesize format description") }

        let meta = PhotosClipResolver.extractMetadata(from: format)
        XCTAssertEqual(meta.transferFunction, .hlg)
        XCTAssertTrue(meta.isHDR)
    }

    func testExtractsBT709ForSDR() {
        guard let format = makeFormat(
            codec: kCMVideoCodecType_H264,
            transfer: kCMFormatDescriptionTransferFunction_ITU_R_709_2,
            primaries: kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        ) else { return XCTFail("Could not synthesize format description") }

        let meta = PhotosClipResolver.extractMetadata(from: format)
        XCTAssertEqual(meta.transferFunction, .bt709)
        XCTAssertEqual(meta.colorPrimaries, .bt709)
        XCTAssertFalse(meta.isHDR)
    }

    func testReturnsUnknownForMissingExtensions() {
        // Format description without color extensions — common on
        // third-party ingest. We tolerate by returning `.unknown` rather
        // than guessing.
        guard let format = makeFormat(
            codec: kCMVideoCodecType_HEVC,
            transfer: nil,
            primaries: nil
        ) else { return XCTFail("Could not synthesize format description") }

        let meta = PhotosClipResolver.extractMetadata(from: format)
        XCTAssertEqual(meta.transferFunction, .unknown)
        XCTAssertEqual(meta.colorPrimaries, .unknown)
        XCTAssertFalse(meta.isHDR)
    }

    func testDetectsDolbyVisionByCodecFourCC() {
        // dvh1 = Dolby Vision HEVC (one of the four DV codec types).
        // Even with SDR transfer + BT.709 primaries (which DV streams
        // can legally carry on the base layer), isDolbyVision MUST fire.
        guard let format = makeFormat(
            codec: PhotosClipResolver.fourCCType("dvh1"),
            transfer: kCMFormatDescriptionTransferFunction_ITU_R_709_2,
            primaries: kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        ) else { return XCTFail("Could not synthesize format description") }

        let meta = PhotosClipResolver.extractMetadata(from: format)
        XCTAssertTrue(meta.isDolbyVision)
        XCTAssertTrue(meta.isHDR, "DV detection must override SDR-transfer classification")
    }

    #endif
}
