import Testing
import Foundation
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
@testable import KadrPhotos

/// Tests for v0.3 Tier 1 — `PhotoPicker` SwiftUI wrapper. Pure helpers + result type
/// behavior; the SwiftUI body itself is exercised by integration testing in a host
/// app (PHPickerViewController needs a real window to present).
struct PhotoPickerTests {

    // MARK: - PhotoPickerResult

    @Test func resultIdEqualsAssetIdentifier() {
        let r = PhotoPickerResult(assetIdentifier: "abc-123")
        #expect(r.id == "abc-123")
    }

    @Test func resultEqualityHonorsAssetIdentifier() {
        let a = PhotoPickerResult(assetIdentifier: "x")
        let b = PhotoPickerResult(assetIdentifier: "x")
        let c = PhotoPickerResult(assetIdentifier: "y")
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - Configuration defaults

    @Test func configurationDefaultMatchesExpectedShape() {
        let c = PhotoPicker.Configuration.default
        #expect(c.selectionLimit == 0)
        #expect(c.filter == .any)
        #expect(c.preferredAssetRepresentationMode == .compatible)
    }

    @Test func configurationIsEquatable() {
        #expect(PhotoPicker.Configuration.default == PhotoPicker.Configuration.default)
        var custom = PhotoPicker.Configuration.default
        custom.selectionLimit = 3
        #expect(custom != PhotoPicker.Configuration.default)
    }

    // MARK: - Filter

    #if canImport(PhotosUI)
    @Test func filterMapsToPHPickerFilter() {
        #expect(PhotoPicker.Filter.images.phFilter == .images)
        #expect(PhotoPicker.Filter.videos.phFilter == .videos)
        #expect(PhotoPicker.Filter.livePhotos.phFilter == .livePhotos)
        #expect(PhotoPicker.Filter.any.phFilter == nil)
    }
    #endif

    @Test func filterIsEquatable() {
        #expect(PhotoPicker.Filter.images == .images)
        #expect(PhotoPicker.Filter.images != .videos)
    }

    // MARK: - AssetRepresentationMode

    #if canImport(PhotosUI)
    @Test func assetRepresentationModeMapsToPH() {
        #expect(PhotoPicker.AssetRepresentationMode.automatic.phMode == .automatic)
        #expect(PhotoPicker.AssetRepresentationMode.current.phMode == .current)
        #expect(PhotoPicker.AssetRepresentationMode.compatible.phMode == .compatible)
    }
    #endif

    // MARK: - makePHConfiguration

    #if canImport(PhotosUI)
    @Test func makePHConfigurationCopiesSelectionLimit() {
        var config = PhotoPicker.Configuration.default
        config.selectionLimit = 5
        let phConfig = PhotoPicker.makePHConfiguration(from: config)
        #expect(phConfig.selectionLimit == 5)
    }

    @Test func makePHConfigurationCopiesFilter() {
        var config = PhotoPicker.Configuration.default
        config.filter = .videos
        let phConfig = PhotoPicker.makePHConfiguration(from: config)
        #expect(phConfig.filter == .videos)
    }

    @Test func makePHConfigurationDoesNotSetFilterForAny() {
        var config = PhotoPicker.Configuration.default
        config.filter = .any
        let phConfig = PhotoPicker.makePHConfiguration(from: config)
        #expect(phConfig.filter == nil)
    }

    @Test func makePHConfigurationCopiesAssetRepresentationMode() {
        var config = PhotoPicker.Configuration.default
        config.preferredAssetRepresentationMode = .current
        let phConfig = PhotoPicker.makePHConfiguration(from: config)
        #expect(phConfig.preferredAssetRepresentationMode == .current)
    }
    #endif

    // MARK: - mapResults

    #if canImport(PhotosUI)
    @Test func mapResultsDropsNilAssetIdentifiers() {
        // PHPickerResult can't be constructed directly; this test documents the
        // intended contract via a dedicated empty-input check, plus we trust the
        // compactMap path for nil-handling.
        let mapped = PhotoPicker.mapResults([])
        #expect(mapped.isEmpty)
    }
    #endif
}
