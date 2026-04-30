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

## v0.2.0 design — Live Photo

A Live Photo is a `PHAsset` of `mediaType == .image` with `mediaSubtypes.contains(.photoLive)`. It packages a still image + a paired ~3-second motion video. v0.2 surfaces both halves as kadr clip types so consumers can pick: drop the motion as a `VideoClip`, drop the still as an `ImageClip`, or use both.

### Problem

v0.1's `PhotosClipResolver.image(asset:)` works on Live Photos already (they're `mediaType == .image`), but it only returns the still half — the motion is silently dropped. Apps that want to show the motion ("animated photo card", "story-style reel of recent Live Photos") have to drop down to `PHAssetResource` directly. This adapter should hide that.

### Scope lock

In scope:
- **`PhotosClipResolver.livePhotoMotion(asset:progress:)`** — async, returns `VideoClip`. Iterates `PHAssetResource.assetResources(for:)`, finds the `.pairedVideo` resource, writes it via `PHAssetResourceManager.writeData(for:toFile:options:completionHandler:)` to a temp `.mov` URL, wraps in `VideoClip`.
- **`PhotosClipResolver.livePhotoStill(asset:duration:options:progress:)`** — async, returns `ImageClip`. Thin wrapper over `image(asset:duration:options:progress:)` that enforces the Live-Photo guard. Symmetric with `livePhotoMotion`.
- **Live Photo guard** — both functions check `asset.mediaSubtypes.contains(.photoLive)` and throw a new `PhotosClipError.notALivePhoto` if absent.
- **iCloud progress reporting** — `PHAssetResourceRequestOptions.progressHandler` for motion; existing `PHImageRequestOptions.progressHandler` for still.

Out of scope (v0.3+ or wishlist):
- **Combined `livePhoto(asset:)` returning both halves** — possible (`(motion: VideoClip, still: ImageClip)` tuple) but rarely useful in practice; consumers either want the motion (animated card) or the still (regular photo). Skip for now.
- **`PHLivePhoto` SwiftUI view bridge** — that's a UI concern, belongs in `kadr-ui` not here.
- **Trimming the motion** — Live Photo motion clips are always ~3 seconds. Consumers can `.trimmed(to:)` the resulting `VideoClip` themselves.

### API examples

```swift
import Kadr
import KadrPhotos
import Photos

// Motion half — animated story card
let clip = try await PhotosClipResolver.livePhotoMotion(asset: livePhotoAsset)
let video = Video {
    clip
    clip.reversed()  // boomerang effect
}

// Still half — explicit Live-Photo guard
let still = try await PhotosClipResolver.livePhotoStill(asset: livePhotoAsset, duration: 3.0)
```

### Public surface sketch

```swift
extension PhotosClipResolver {
    public static func livePhotoMotion(
        asset: PHAsset,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending VideoClip

    public static func livePhotoStill(
        asset: PHAsset,
        duration: CMTime,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip

    // TimeInterval overload
    public static func livePhotoStill(
        asset: PHAsset,
        duration: TimeInterval,
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending ImageClip
}

extension PhotosClipError {
    /// The asset isn't a Live Photo (`mediaSubtypes.contains(.photoLive)` is false).
    /// Added in v0.2.
    case notALivePhoto
}
```

### Engine notes

- **Resource selection.** `PHAssetResource.assetResources(for: asset)` returns multiple resources for a Live Photo. We pick the one with `type == .pairedVideo`. If absent, throw `.missingMedia` (the asset claims to be a Live Photo but the motion resource is gone — likely an iCloud / sync edge case).
- **Network access.** `PHAssetResourceRequestOptions().isNetworkAccessAllowed = true` so iCloud-only Live Photos download on demand. Mirrors v0.1's video / image resolver behavior.
- **Output location.** `FileManager.temporaryDirectory + UUID + .mov`. Caller manages the temp file lifecycle thereafter (same contract as v0.1's video resolver).
- **Sendable.** Reuses the v0.1 `ContinuationBox` and `ExportSessionCarrier` patterns. The `PHAssetResource` and result `URL` cross actor boundaries; we wrap in a small `URLCarrier` for clarity.

### Tier breakdown

- **Tier 1** — `livePhotoMotion(asset:)` + `livePhotoStill(asset:duration:)` + `PhotosClipError.notALivePhoto`. ~150 LOC + tests.
- **Tier 2** — Release prep + ship as **v0.2.0**. CHANGELOG, README polish, develop → main.

### Test strategy

PHAsset-backed paths still can't be unit-tested without a real photo library; the bulk lives in pure helpers and integration testing.

- **Pure helpers** — `notALivePhoto` error equality / payload, the `PhotosMediaSubtype` re-export bridge if added, temp `.mov` URL generation (uniqueness / extension / location).
- **Live-Photo guard** — synthesize a minimal mock-PHAsset stand-in only if a clean test seam emerges; otherwise document the guard via integration testing.

Target test count for v0.2: ~5 net new (mostly pure-helper additions).

### Compatibility

- KadrPhotos 0.2.0 still requires kadr ≥ 0.9.2.
- Pure additive — every v0.1 call site compiles unchanged.

### Open questions (track in PRs, not blocking RFC merge)

- **Motion duration cap.** Live Photo motion is nominally 3 seconds but iOS sometimes captures up to ~6 seconds. We surface the full resource duration; consumers trim if they want a fixed length.
- **Audio in Live Photo motion.** The paired video does have audio. v0.2 returns it as-is — consumers can `.muted()` if desired.

## v0.3.0 design — PHPickerViewController SwiftUI wrapper

The PhotosUI bridge. Wraps `PHPickerViewController` in a SwiftUI `View` that returns directly into kadr clip types — bypasses the manual `PHAsset` → `PhotosClipResolver` round-trip for the common "user picks N items, build a video" flow.

### Problem

`PHPickerViewController` has been the recommended Photos picker since iOS 14 (replacing the deprecated `UIImagePickerController` / `PHImagePickerViewController`). It's UIKit / AppKit-based; SwiftUI consumers need a `UIViewControllerRepresentable` / `NSViewControllerRepresentable` to use it. Most apps doing kadr work re-implement this wrapper plus the `PHPickerResult` → `PHAsset` resolution dance. v0.3 ships it.

### Scope lock

In scope:
- **`PhotoPicker` SwiftUI view** — `UIViewControllerRepresentable` on iOS / visionOS, `NSViewControllerRepresentable` on macOS, branched via `#if canImport(UIKit)` / `canImport(AppKit)`.
- **Selection binding** — `selection: Binding<[PhotoPickerResult]>` is set when the user dismisses the picker. Multiple-selection respects `Configuration.selectionLimit`.
- **`PhotoPickerResult`** value type — wraps the `assetIdentifier` returned by `PHPickerResult`. Exposes `@MainActor func resolveAsset() -> PHAsset?` so consumers can hand the result to `PhotosClipResolver.video / image / livePhotoMotion`.
- **`PhotoPicker.Configuration`** — `selectionLimit` (default `0` = unlimited), `filter` (.images / .videos / .livePhotos / .any), `preferredAssetRepresentationMode` defaulting to `.compatible`.
- **`PhotosClipResolver.clip(from:imageDuration:options:progress:)`** — convenience that resolves a `PhotoPickerResult` into a kadr `Clip`. Inspects the underlying `PHAsset.mediaType` and dispatches to `video()` for video assets or `image()` for image assets. Returns `any Clip` (sending).
- **`PhotosClipResolver.clips(from:imageDuration:options:progress:)`** — array overload of the above. Resolves sequentially (PHImageManager handles concurrency internally; serializing keeps progress reporting coherent).

Out of scope (v0.4+ or wishlist):
- **Multi-asset progress aggregation** — `clips(from:)` reports per-asset progress via the `progress` callback on each asset. A merged "67% across all 5" callback would need an additional API; defer until consumers ask.
- **Filtering by asset ID at picker dismiss** — could allow consumers to drop already-selected items. Skip; consumers can filter the binding themselves.
- **In-app / sandboxed UI customization** — `PHPickerViewController.preferredContentSize`, custom navigation. Out of scope.
- **Media playback / preview inside the picker** — handled by `PHPickerViewController` itself; nothing to add.

### API examples

```swift
import SwiftUI
import Kadr
import KadrPhotos

struct ContentView: View {
    @State private var pickedItems: [PhotoPickerResult] = []
    @State private var showPicker = false
    @State private var clips: [any Clip] = []

    var body: some View {
        VStack {
            Button("Pick from Photos") { showPicker = true }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(
                selection: $pickedItems,
                configuration: .init(selectionLimit: 5, filter: .any)
            )
        }
        .task(id: pickedItems.map(\.assetIdentifier)) {
            clips = (try? await PhotosClipResolver.clips(from: pickedItems)) ?? []
        }
    }
}
```

### Public surface sketch

```swift
@available(iOS 16, macOS 13, visionOS 1, *)
public struct PhotoPicker: View {
    public init(
        selection: Binding<[PhotoPickerResult]>,
        configuration: Configuration = .default
    )
}

public struct PhotoPickerResult: Sendable, Equatable, Identifiable {
    /// `PHPickerResult.assetIdentifier` — the local identifier of the picked PHAsset.
    /// Stable across app launches; can be persisted.
    public let assetIdentifier: String
    public var id: String { assetIdentifier }

    /// Resolve the underlying `PHAsset`. Must be called on `MainActor` because
    /// `PHAsset.fetchAssets` accesses the shared photo library.
    @MainActor
    public func resolveAsset() -> PHAsset?
}

extension PhotoPicker {
    public struct Configuration: Sendable, Equatable {
        /// Maximum number of items the user can pick. `0` = unlimited (default).
        public var selectionLimit: Int

        /// Media-type filter. Default `.any`.
        public var filter: Filter

        /// Default `.compatible` — picker may transcode to a more universally-readable
        /// format. `.current` skips the transcode at the cost of receiving the
        /// asset in its original format (may be HEIF / HEVC).
        public var preferredAssetRepresentationMode: AssetRepresentationMode

        public static let `default` = Configuration()
    }

    public enum Filter: Sendable, Equatable {
        case images
        case videos
        case livePhotos
        case any
        // Future: .any(of: [...]) for finer control. v0.3 stays small.
    }

    public enum AssetRepresentationMode: Sendable, Equatable {
        case automatic, current, compatible
    }
}

extension PhotosClipResolver {
    /// Resolve a `PhotoPickerResult` to a kadr `Clip`. Inspects the underlying
    /// `PHAsset.mediaType` and dispatches to `video()` (for video assets) or
    /// `image()` (for image assets). Returns the result as `any Clip`.
    public static func clip(
        from result: PhotoPickerResult,
        imageDuration: CMTime = CMTime(seconds: 3, preferredTimescale: 600),
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending any Clip

    /// Array convenience. Resolves serially in declaration order.
    public static func clips(
        from results: [PhotoPickerResult],
        imageDuration: CMTime = CMTime(seconds: 3, preferredTimescale: 600),
        options: Options = .default,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> sending [any Clip]
}
```

### Engine notes

- **Backing controller construction.** `PHPickerConfiguration(photoLibrary: .shared())` — passing the shared library is required so `PHPickerResult.assetIdentifier` returns a non-nil string. Without it the picker hands back item providers only and `PHAsset.fetchAssets` can't resolve.
- **Filter mapping.** `PhotoPicker.Filter.images` → `PHPickerFilter.images`; `.videos` → `.videos`; `.livePhotos` → `.livePhotos`; `.any` → `nil` (no filter, default Photos picker UX).
- **Selection delivery.** `PHPickerViewController` calls its delegate on the main thread. The coordinator iterates `[PHPickerResult]`, filters out nil `assetIdentifier`s (rare — happens for items the picker doesn't expose by reference, e.g. some shared albums), wraps in `PhotoPickerResult`, and sets the binding.
- **Dismissal.** The picker dismisses itself on selection finish or cancel. The wrapper relies on the consumer's `.sheet(isPresented:)` (or fullScreenCover, etc.) to actually drive the show/hide.
- **`clip(from:)` dispatch.** `result.resolveAsset()?.mediaType` decides:
  - `.video` → `PhotosClipResolver.video(asset:options:progress:)`
  - `.image` → `PhotosClipResolver.image(asset:duration:options:progress:)`
  - other (`.audio` / `.unknown`) → throw `PhotosClipError.wrongMediaType(expected: .video, actual: ...)` (audio assets aren't kadr clips; the v0.1 mismatch error is recycled).
- **Authorization.** The picker doesn't require library authorization to display — but `PHAsset.fetchAssets(withLocalIdentifiers:)` *does*. Consumers calling `clip(from:)` need read access (same v0.1 contract). `PhotoPicker` itself works without authorization.

### Tier breakdown

- **Tier 1** — `PhotoPicker` SwiftUI view (UIKit + AppKit bridges) + `PhotoPickerResult` + `Configuration` / `Filter` / `AssetRepresentationMode` enums. ~250 LOC + tests.
- **Tier 2** — `PhotosClipResolver.clip(from:)` + `clips(from:)`. ~80 LOC + tests.
- **Tier 3** — Release prep + ship as **v0.3.0**.

### Test strategy

- **Pure helpers** — `Configuration.default` shape, `Filter` / `AssetRepresentationMode` enum equality + AVFoundation enum bridge mappings.
- **`PhotoPickerResult`** — Identifiable / Equatable behavior; `id == assetIdentifier`.
- **Filter → PHPickerFilter mapping** — pure helper exposed for test.
- **`PhotoPicker` body smoke test** — `@MainActor`; just exercises `makeUIViewController` / `makeNSViewController` to confirm no crash.
- **Live picker UX** — manual integration testing in a host app; cannot be unit-tested.

Target test count for v0.3: ~10 new tests.

### Compatibility

- KadrPhotos 0.3.0 still requires kadr ≥ 0.9.2.
- Pure additive — every v0.2 call site compiles unchanged.
- Platform support unchanged (iOS 16+ / macOS 13+ / visionOS 1+; tvOS still excluded).
- Required entitlement (consumer): `NSPhotoLibraryUsageDescription`. The picker itself doesn't require library authorization, but `clip(from:)`'s underlying `PHAsset.fetchAssets` does.

### Open questions (track in PRs, not blocking RFC merge)

- **Unified progress reporting.** `clips(from:)` calls the per-asset `progress` callback once per asset; an aggregate "X of N done" callback would need a wrapper. Skip in v0.3.
- **Cancellation.** No way to cancel an in-flight `clips(from:)` resolution beyond Task cancellation. The downstream `PhotosClipResolver` calls don't yet check `Task.isCancelled` at intermediate points; v0.3 inherits whatever cancellation behavior the v0.1 / v0.2 resolvers have.
- **Live Photo dispatch.** `clip(from:)` dispatches on `PHAsset.mediaType` (which is `.image` for Live Photos). Consumers wanting the motion half should call `livePhotoMotion(asset:)` directly. Or — open question — should `clip(from:)` grow a `preferLivePhotoMotion: Bool = false` flag? Defer until demand.
