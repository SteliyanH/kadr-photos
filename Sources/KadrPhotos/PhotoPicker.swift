import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(PhotosUI)

/// SwiftUI wrapper around `PHPickerViewController`. Cross-platform via
/// `UIViewControllerRepresentable` (iOS / visionOS) and `NSViewControllerRepresentable`
/// (macOS). On selection finish, sets `selection` to `[PhotoPickerResult]`; pair with
/// `.sheet(isPresented:)` (or `fullScreenCover`, etc.) for show/hide control.
///
/// ```swift
/// @State private var picked: [PhotoPickerResult] = []
/// @State private var showPicker = false
///
/// var body: some View {
///     Button("Pick") { showPicker = true }
///         .sheet(isPresented: $showPicker) {
///             PhotoPicker(selection: $picked,
///                         configuration: .init(selectionLimit: 5, filter: .videos))
///         }
/// }
/// ```
@available(iOS 16, macOS 13, visionOS 1, *)
public struct PhotoPicker: View {

    private let selection: Binding<[PhotoPickerResult]>
    private let configuration: Configuration

    public init(
        selection: Binding<[PhotoPickerResult]>,
        configuration: Configuration = .default
    ) {
        self.selection = selection
        self.configuration = configuration
    }

    public var body: some View {
        Bridge(selection: selection, configuration: configuration)
    }
}

// MARK: - Configuration

@available(iOS 16, macOS 13, visionOS 1, *)
extension PhotoPicker {

    /// Tuning options for ``PhotoPicker``.
    public struct Configuration: Sendable, Equatable {

        /// Maximum number of items the user can pick. `0` (default) means unlimited.
        public var selectionLimit: Int

        /// Media-type filter. Default ``Filter/any``.
        public var filter: Filter

        /// How the picker delivers asset data to the system. Default ``AssetRepresentationMode/compatible``.
        public var preferredAssetRepresentationMode: AssetRepresentationMode

        public init(
            selectionLimit: Int = 0,
            filter: Filter = .any,
            preferredAssetRepresentationMode: AssetRepresentationMode = .compatible
        ) {
            self.selectionLimit = selectionLimit
            self.filter = filter
            self.preferredAssetRepresentationMode = preferredAssetRepresentationMode
        }

        public static let `default` = Configuration()
    }

    /// Media-type filter for the picker. Mirrors `PHPickerFilter`'s common cases.
    public enum Filter: Sendable, Equatable {
        case images
        case videos
        case livePhotos
        case any

        /// Map to the underlying `PHPickerFilter`. Internal — the picker uses it when
        /// constructing the configuration. `nil` means "no filter applied" (the
        /// default Photos picker UX).
        internal var phFilter: PHPickerFilter? {
            switch self {
            case .images:     return .images
            case .videos:     return .videos
            case .livePhotos: return .livePhotos
            case .any:        return nil
            }
        }
    }

    /// How the picker prepares the picked asset's data. Mirrors
    /// `PHPickerConfiguration.AssetRepresentationMode`.
    public enum AssetRepresentationMode: Sendable, Equatable {
        case automatic
        case current
        case compatible

        internal var phMode: PHPickerConfiguration.AssetRepresentationMode {
            switch self {
            case .automatic:  return .automatic
            case .current:    return .current
            case .compatible: return .compatible
            }
        }
    }
}

// MARK: - Pure helpers

@available(iOS 16, macOS 13, visionOS 1, *)
extension PhotoPicker {

    /// Build the underlying `PHPickerConfiguration` from a kadr-side ``Configuration``.
    /// Pure — exposed for tests so the configuration mapping is verifiable without
    /// instantiating the picker.
    nonisolated internal static func makePHConfiguration(
        from config: Configuration
    ) -> PHPickerConfiguration {
        var phConfig = PHPickerConfiguration(photoLibrary: .shared())
        phConfig.selectionLimit = config.selectionLimit
        phConfig.preferredAssetRepresentationMode = config.preferredAssetRepresentationMode.phMode
        if let filter = config.filter.phFilter {
            phConfig.filter = filter
        }
        return phConfig
    }

    /// Map `[PHPickerResult]` to `[PhotoPickerResult]`, dropping items with no
    /// `assetIdentifier` (rare; happens when the picker can't expose a stable
    /// reference, e.g. some shared albums). Pure — exposed for tests.
    nonisolated internal static func mapResults(_ results: [PHPickerResult]) -> [PhotoPickerResult] {
        results.compactMap { result in
            guard let id = result.assetIdentifier else { return nil }
            return PhotoPickerResult(assetIdentifier: id)
        }
    }
}

// MARK: - Platform bridge

#if canImport(UIKit)

@available(iOS 16, visionOS 1, *)
private struct Bridge: UIViewControllerRepresentable {
    let selection: Binding<[PhotoPickerResult]>
    let configuration: PhotoPicker.Configuration

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let phConfig = PhotoPicker.makePHConfiguration(from: configuration)
        let controller = PHPickerViewController(configuration: phConfig)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // PHPickerViewController doesn't reconfigure post-init; nothing to do.
    }
}

@available(iOS 16, visionOS 1, *)
@MainActor
private final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    private let selection: Binding<[PhotoPickerResult]>

    init(selection: Binding<[PhotoPickerResult]>) {
        self.selection = selection
    }

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let mapped = PhotoPicker.mapResults(results)
        let binding = selection
        Task { @MainActor in
            binding.wrappedValue = mapped
            picker.dismiss(animated: true)
        }
    }
}

#elseif canImport(AppKit)

@available(macOS 13, *)
private struct Bridge: NSViewControllerRepresentable {
    let selection: Binding<[PhotoPickerResult]>
    let configuration: PhotoPicker.Configuration

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: selection)
    }

    func makeNSViewController(context: Context) -> PHPickerViewController {
        let phConfig = PhotoPicker.makePHConfiguration(from: configuration)
        let controller = PHPickerViewController(configuration: phConfig)
        controller.delegate = context.coordinator
        return controller
    }

    func updateNSViewController(_ nsViewController: PHPickerViewController, context: Context) {
        // PHPickerViewController doesn't reconfigure post-init; nothing to do.
    }
}

@available(macOS 13, *)
@MainActor
private final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    private let selection: Binding<[PhotoPickerResult]>

    init(selection: Binding<[PhotoPickerResult]>) {
        self.selection = selection
    }

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let mapped = PhotoPicker.mapResults(results)
        let binding = selection
        Task { @MainActor in
            binding.wrappedValue = mapped
            picker.dismiss(true)
        }
    }
}

#endif

#endif
