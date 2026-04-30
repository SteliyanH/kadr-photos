import Testing
import Foundation
import CoreGraphics
import CoreLocation
#if canImport(Photos)
import Photos
#endif
@testable import KadrPhotos

/// Tests for v0.4 Tier 1 — `PhotoAssetMetadata` value type, `PhotoAssetSubtypes`
/// OptionSet, and the bridge from `PHAssetMediaSubtype`. The PHAsset-reading path
/// (`metadata(of:)`) requires a real photo library and is covered by manual
/// integration testing.
struct MetadataTests {

    // MARK: - PhotoAssetSubtypes shape

    @Test func subtypesEmptySetByDefault() {
        let s: PhotoAssetSubtypes = []
        #expect(!s.contains(.livePhoto))
        #expect(!s.contains(.panorama))
    }

    @Test func subtypesUnionContainsAllInsertedFlags() {
        let s: PhotoAssetSubtypes = [.livePhoto, .hdr, .panorama]
        #expect(s.contains(.livePhoto))
        #expect(s.contains(.hdr))
        #expect(s.contains(.panorama))
        #expect(!s.contains(.screenshot))
    }

    @Test func subtypesIsEquatable() {
        let a: PhotoAssetSubtypes = [.livePhoto, .hdr]
        let b: PhotoAssetSubtypes = [.hdr, .livePhoto]
        let c: PhotoAssetSubtypes = [.livePhoto]
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - PHAssetMediaSubtype bridge

    #if canImport(Photos)

    @Test func bridgesEmptyPHSubtypeToEmpty() {
        let bridged = PhotoAssetSubtypes.from([])
        #expect(bridged == [])
    }

    @Test func bridgesLivePhoto() {
        let bridged = PhotoAssetSubtypes.from(.photoLive)
        #expect(bridged.contains(.livePhoto))
    }

    @Test func bridgesPanorama() {
        let bridged = PhotoAssetSubtypes.from(.photoPanorama)
        #expect(bridged.contains(.panorama))
    }

    @Test func bridgesHDR() {
        let bridged = PhotoAssetSubtypes.from(.photoHDR)
        #expect(bridged.contains(.hdr))
    }

    @Test func bridgesScreenshot() {
        let bridged = PhotoAssetSubtypes.from(.photoScreenshot)
        #expect(bridged.contains(.screenshot))
    }

    @Test func bridgesDepthEffect() {
        let bridged = PhotoAssetSubtypes.from(.photoDepthEffect)
        #expect(bridged.contains(.depthEffect))
    }

    @Test func bridgesHighFrameRate() {
        let bridged = PhotoAssetSubtypes.from(.videoHighFrameRate)
        #expect(bridged.contains(.highFrameRate))
    }

    @Test func bridgesTimelapse() {
        let bridged = PhotoAssetSubtypes.from(.videoTimelapse)
        #expect(bridged.contains(.timelapse))
    }

    @Test func bridgesStreamed() {
        let bridged = PhotoAssetSubtypes.from(.videoStreamed)
        #expect(bridged.contains(.streamed))
    }

    @Test func bridgesMultipleFlagsAtOnce() {
        let phSubtypes: PHAssetMediaSubtype = [.photoLive, .photoHDR, .photoPanorama]
        let bridged = PhotoAssetSubtypes.from(phSubtypes)
        #expect(bridged.contains(.livePhoto))
        #expect(bridged.contains(.hdr))
        #expect(bridged.contains(.panorama))
    }

    #endif

    // MARK: - PhotoAssetMetadata equality

    private func makeMetadata(
        creation: Date? = nil,
        location: CLLocation? = nil,
        favorite: Bool = false
    ) -> PhotoAssetMetadata {
        PhotoAssetMetadata(
            creationDate: creation,
            modificationDate: nil,
            location: location,
            pixelSize: CGSize(width: 1920, height: 1080),
            videoDuration: 0,
            subtypes: [],
            isFavorite: favorite,
            burstIdentifier: nil,
            mediaKind: .image
        )
    }

    @Test func metadataEqualityHonorsCreationDate() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let a = makeMetadata(creation: date)
        let b = makeMetadata(creation: date)
        let c = makeMetadata(creation: nil)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func metadataEqualityCompareLocationCoordinates() {
        let loc1 = CLLocation(latitude: 52.5, longitude: 13.4)
        let loc2 = CLLocation(latitude: 52.5, longitude: 13.4)
        let loc3 = CLLocation(latitude: 40.7, longitude: -74.0)
        let a = makeMetadata(location: loc1)
        let b = makeMetadata(location: loc2)
        let c = makeMetadata(location: loc3)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func metadataEqualityHonorsFavorite() {
        let a = makeMetadata(favorite: true)
        let b = makeMetadata(favorite: false)
        #expect(a != b)
    }
}
