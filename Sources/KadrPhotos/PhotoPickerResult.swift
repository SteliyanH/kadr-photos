import Foundation
#if canImport(Photos)
import Photos
#endif

/// A single item returned by ``PhotoPicker``. Wraps the `assetIdentifier` from the
/// underlying `PHPickerResult`; the asset is resolved on demand via
/// ``resolveAsset()``.
public struct PhotoPickerResult: Sendable, Equatable, Identifiable {

    /// Local identifier of the picked `PHAsset`. Stable across app launches and safe
    /// to persist (e.g. in user defaults or a database). Equivalent to
    /// `PHPickerResult.assetIdentifier`.
    public let assetIdentifier: String

    /// Identity for SwiftUI lists and bindings. Equal to ``assetIdentifier``.
    public var id: String { assetIdentifier }

    public init(assetIdentifier: String) {
        self.assetIdentifier = assetIdentifier
    }

    #if canImport(Photos)
    /// Resolve the underlying `PHAsset` from the photo library. Must be called on
    /// `MainActor` because `PHAsset.fetchAssets` accesses the shared library.
    /// Returns `nil` if the asset has been deleted between picker dismiss and now.
    @MainActor
    public func resolveAsset() -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        return result.firstObject
    }
    #endif
}
