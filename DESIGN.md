# KadrPhotos — Design Document

## v0.1.0 design — Video + image PHAsset resolution

The first release. Bridges `PHAsset` (the Photos library's identifier type) to kadr's `VideoClip` / `ImageClip`. Live Photo support is staged for v0.2.0; PhotosUI picker integration for v0.3.0+.

### Problem

kadr clips are URL-backed (`VideoClip(url:)`) or in-memory (`ImageClip(_:duration:)`). The Photos library identifies items via `PHAsset` — there's no public URL, and extracting one (or the underlying media) requires the `Photos` / `PhotosUI` frameworks plus an async iCloud round-trip. kadr core deliberately avoids those framework dependencies; this adapter handles the bridging.

### Scope lock

In scope:
- **Video PHAsset → `VideoClip`** — `PhotosClipResolver.video(asset:options:progress:)`. Uses `PHImageManager.requestAVAsset(forVideo:)` to download from iCloud if needed, then exports to a temporary file URL via `AVAssetExportSession` so the returned `VideoClip` is URL-backed (kadr-friendly).
- **Image PHAsset → `ImageClip`** — `PhotosClipResolver.image(asset:duration:options:progress:)`. Uses `PHImageManager.requestImage(for:targetSize:contentMode:options:)` to fetch the still at the requested target size.
- **iCloud progress reporting** — `progress: ((Double) -> Void)?` callback fires during the network download, mapped from `PHImageRequestOptions.progressHandler` and `PHVideoRequestOptions.progressHandler`.
- **`PhotosClipError`** — typed errors for unauthorized library access, missing/invalid asset, iCloud download failure, video export failure.
- **`PhotosClipResolver.Options`** — tuning struct (target size for images, AVAssetExportSession preset for videos, delivery mode).

Out of scope (v0.2.0+ or wishlist):
- **Live Photo** — defer to v0.2.0. Needs `PHLivePhoto` + paired video extraction.
- **`PHPickerViewController` SwiftUI wrapper** — defer to v0.3.0+. Larger surface (selection state, multi-select, filtering).
- **Custom Clip type** (`PHAssetClip` adopting `Clip` directly) — considered, dropped. Kadr's `Clip` requires synchronous `duration: CMTime`, and a `PHAsset` doesn't expose its source media duration synchronously without the `PHImageManager` round-trip. Returning `.zero` until resolved would create silent timing bugs in `Video.duration`. The resolver pattern (async returns a real `VideoClip` / `ImageClip`) is honest about the asynchrony.
- **iCloud-only mode toggling** — `options.isNetworkAccessAllowed = false` to refuse the download. Not v0.1; revisit on demand.
- **HEIC / HEIF special handling** — Photos returns `UIImage`/`NSImage` already decoded; no special path needed in v0.1.

### Captions decision recap (analogous)

This package's split mirrors the kadr-captions decision: kadr core stays AVFoundation-only and url-/data-based, the adapter handles the `Photos`-framework ecosystem. No runtime dependency on the adapter from core.

### API examples

```swift
import Kadr
import KadrPhotos
import Photos

// 1. Video — defaults
let clip = try await PhotosClipResolver.video(asset: videoAsset)

// 2. Video with iCloud progress
let clip = try await PhotosClipResolver.video(asset: videoAsset) { progress in
    iCloudProgressBar.fractionCompleted = progress
}

// 3. Image at custom target size
var opts = PhotosClipResolver.Options.default
opts.imageTargetSize = CGSize(width: 1080, height: 1920)
let image = try await PhotosClipResolver.image(
    asset: stillAsset,
    duration: 3.0,
    options: opts
)

// 4. Compose
let video = Video {
    try await PhotosClipResolver.video(asset: a)
    try await PhotosClipResolver.image(asset: b, duration: 2.0)
}
```

### Public surface sketch

```swift
public enum PhotosClipResolver {

    /// Resolve a video `PHAsset` to a `VideoClip`. Downloads from iCloud if needed.
    /// The returned clip's `url` points to a temporary file in `FileManager.default.temporaryDirectory`;
    /// callers should use it before the next app cleanup of that directory or move it elsewhere.
    public static func video(
        asset: PHAsset,
        options: Options = .default,
        progress: ((Double) -> Void)? = nil
    ) async throws -> VideoClip

    /// Resolve an image `PHAsset` to an `ImageClip` of the given duration.
    public static func image(
        asset: PHAsset,
        duration: CMTime,
        options: Options = .default,
        progress: ((Double) -> Void)? = nil
    ) async throws -> ImageClip

    /// Convenience overload accepting `TimeInterval` for the image clip duration.
    public static func image(
        asset: PHAsset,
        duration: TimeInterval,
        options: Options = .default,
        progress: ((Double) -> Void)? = nil
    ) async throws -> ImageClip

    /// Tuning options. Sensible defaults for the common cases.
    public struct Options: Sendable {
        /// Target rendered size for image asset extraction. Default `PHImageManagerMaximumSize`.
        public var imageTargetSize: CGSize
        /// Image content mode passed through to PHImageManager. Default `.aspectFill`.
        public var imageContentMode: ImageContentMode
        /// Image delivery mode — quality vs. speed. Default `.highQualityFormat`.
        public var imageDeliveryMode: ImageDeliveryMode
        /// AVAssetExportSession preset name for video exports. Default `AVAssetExportPresetHighestQuality`.
        public var videoExportPreset: String

        public static let `default` = Options(
            imageTargetSize: .init(width: -1, height: -1),  // sentinel for PHImageManagerMaximumSize
            imageContentMode: .aspectFill,
            imageDeliveryMode: .highQualityFormat,
            videoExportPreset: AVAssetExportPresetHighestQuality
        )
    }

    /// Re-exported subset of `PHImageContentMode` so consumers don't need to import Photos
    /// just to set this option.
    public enum ImageContentMode: Sendable {
        case aspectFit
        case aspectFill
        case `default`
    }

    /// Re-exported subset of `PHImageRequestOptionsDeliveryMode`.
    public enum ImageDeliveryMode: Sendable {
        case opportunistic
        case highQualityFormat
        case fastFormat
    }
}

public enum PhotosClipError: Error, Equatable {
    /// Caller hasn't been granted read access to the photo library. Prompt the user via
    /// `PHPhotoLibrary.requestAuthorization` first.
    case unauthorized

    /// The PHAsset's `mediaType` doesn't match the requested resolver (e.g. asking
    /// `video(asset:)` for an image asset).
    case wrongMediaType(expected: PhotosMediaKind, actual: PhotosMediaKind)

    /// PHImageManager returned no asset / no image. Asset may have been deleted while in flight.
    case missingMedia

    /// iCloud download failed mid-flight. Underlying NSError available in `.iCloudDownload(_:)`'s payload.
    case iCloudDownload(localizedDescription: String)

    /// AVAssetExportSession failed to produce the video clip's URL.
    case videoExportFailed(localizedDescription: String)
}

public enum PhotosMediaKind: Sendable, Equatable {
    case video
    case image
    case audio
    case unknown
}
```

### Engine notes

- **Video resolution.** `PHImageManager.requestAVAsset(forVideo:options:resultHandler:)` returns an `AVAsset` (not a URL). For kadr's `VideoClip(url:)` we need a URL, so the resolver runs an `AVAssetExportSession.export()` to a temp file (`FileManager.temporaryDirectory.appendingPathComponent(uuid).mp4`). The temp file's lifecycle is the caller's — they get a `VideoClip` whose URL is usable until the system cleans the temp dir.
- **Image resolution.** `PHImageManager.requestImage(for:targetSize:contentMode:options:resultHandler:)` returns a `UIImage` / `NSImage` directly. Wrapped in `ImageClip(_:duration:)`.
- **iCloud progress.** Both video and image request options accept a `progressHandler: ((Double, Error?, ...) -> Void)`. The resolver maps the double to the `progress` callback. Errors from this handler surface as `PhotosClipError.iCloudDownload`.
- **Authorization.** The resolver doesn't request authorization itself — that's the consuming app's job (it owns the UI for the prompt and the entitlement string). On `PHAuthorizationStatus != .authorized && != .limited`, the resolver throws `.unauthorized` early without making the request.

### Tier breakdown

Mirrors the kadr-captions cycle.

- **Tier 0** *(this PR)* — design doc, scaffold (Package.swift, README, ROADMAP, CHANGELOG, .gitignore, LICENSE, CI). No code.
- **Tier 1** — `PhotosClipResolver.video(asset:)` + `PhotosClipError` + `Options`. ~250 LOC + tests.
- **Tier 2** — `PhotosClipResolver.image(asset:duration:)` + image options. ~150 LOC + tests.
- **Tier 3** — Release prep + ship as **v0.1.0**. CHANGELOG, README polish, develop → main.

### Test strategy

Unit testing PHAsset-backed code is fragile — the Photos framework requires a real photo library and authorization prompt, neither available in CI. Strategy:

- **Pure helpers** — `Options` struct equality, `PhotosClipError` cases, `PhotosMediaKind` mapping from `PHAssetMediaType`, ImageContentMode / ImageDeliveryMode → AVFoundation enum bridges. Fully testable without the framework.
- **Authorization gate** — given a fake `PHAuthorizationStatus`, the resolver throws `.unauthorized` for the right cases. (Inject the status check via a test seam.)
- **Live integration** — manual smoke test in the example app (a SwiftUI sample showing a `PHPicker` flow that resolves into kadr). Documented in the README's example app section, not in the test suite.

Target test count for v0.1: ~15 (unit; pure helpers).

### Compatibility

- KadrPhotos 0.1.0 requires kadr ≥ 0.9.2.
- iOS 16+, macOS 13+, visionOS 1+. **tvOS excluded** — `Photos.framework` is unavailable on tvOS.
- Required entitlement (consumer): `NSPhotoLibraryUsageDescription` for read access.

### Open questions (track in PRs, not blocking RFC merge)

- **Temp file lifecycle for video resolution.** The current plan dumps to `temporaryDirectory`; consumers manage the file thereafter. Alternative: provide a `cleanup()` helper that the consumer calls when done with the resulting `VideoClip`. Defer until someone hits a real cleanup pain point.
- **Image format preservation.** PHImageManager always returns a decoded `UIImage`/`NSImage`. Consumers wanting the original HEIC/PNG bytes need a different path — out of v0.1 scope.
- **Burst / Slo-mo / Time-lapse subtypes.** PHAsset's `mediaSubtypes` distinguishes these. v0.1 treats them as plain video assets — `mediaSubtype` info isn't surfaced. Revisit if anyone needs it.
- **Test seam shape.** A protocol-based PHImageManager wrapper would let us unit-test without the framework, but it's a meaningful surface area cost. Decision: defer; rely on integration testing in the example app for v0.1.
