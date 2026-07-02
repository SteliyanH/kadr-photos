# Changelog

All notable changes to KadrPhotos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.0] - 2026-07-02

Platform floor raised to **iOS 17 / macOS 14 / visionOS 1** (tvOS still excluded — `Photos.framework` is unavailable there) as part of the coordinated ecosystem move to the iOS 17 baseline. Required because a package with an iOS 16 floor can't depend on Kadr 0.15 (iOS 17). No behavior change.

### Changed

- **`Package.swift` platforms** → `.iOS(.v17)` / `.macOS(.v14)` / `.visionOS(.v1)` (was iOS 16 / macOS 13); **Kadr dependency floor → ≥ 0.15.0** (was 0.9.2).

### Removed

- 8 now-redundant `@available(iOS 16 / macOS 13, …)` annotations across the sources — the package floor already exceeds them.

### Fixed

- Updated stale docstrings referencing Kadr's removed `speed(_:)` / `speed(curve:)` overloads (removed in Kadr 0.14) to the `Speed` enum form (`.speed(.flat(_:))` / `.speed(.curved(_:))`), and corrected the "iOS 16 closure path" picker note now that iOS 17 is the floor. No code change — the references were documentation only.

### Compatibility

Requires **Kadr ≥ 0.15.0**. Consumers needing the iOS 16 floor stay on the **0.6.x** line. Suite unchanged (80 tests, 0 failures).

## [0.6.0] - 2026-05-28

Reopened cycle — three resolution-side surfaces driven by downstream consumers: HDR / Dolby Vision metadata read, an iOS 17 async-results overload on `PhotoPicker`, and Live Photos depth-channel extraction. Pure additive — every v0.5 call site compiles unchanged. Kadr floor stays at **0.9.2**.

### Added

- **`PhotosClipResolver.videoHDRMetadata(of:)`** — async; reads the asset's transfer function + color primaries + color matrix and detects Dolby Vision via codec FourCC, without pulling the full media. Pairs with **kadr-pro** for the export side; the resolution side stays free so consumers can detect-and-route ("this is HDR" without "this exports HDR"). `VideoHDRMetadata` value type carries the result.
- **`PhotoPicker(configuration:iOS17AsyncResults:)`** — iOS 17 / macOS 14 / visionOS 1 initializer that delivers picked items as an `AsyncStream<PhotoPickerResult>`; caller iterates with `for await`. The iOS 16 closure / binding path stays for the deployment floor. Internally `PhotoPicker` now stores a `Delivery` enum (binding vs. asyncStream) and dispatches through `PhotoPicker.deliver(_:via:)`.
- **`PhotosClipResolver.depthMap(from:)`** — async; returns `CVPixelBuffer?` for iPhone 12+ Live Photos carrying disparity / depth / portrait-effects-matte auxiliary data. Detection-only — returns `nil` for any asset that isn't depth-bearing (non-Live-Photo, missing aux, iCloud unreachable, decode failure). Aux-type preference: disparity → depth → matte. Vision-side cutout / segmentation stays in kadr-pro.

### Tests

- 24 new tests across `VideoHDRMetadataTests` (12), `PhotoPickerAsyncResultsTests` (4), `DepthExtractionTests` (8). Suite total: 80.

### Notes

- The "iOS 17 PHPicker.results AsyncSequence" framing in the planning doc was aspirational — `PHPickerViewController` still uses its delegate. The new overload wraps the delegate in an `AsyncStream` so callers get the `for await` ergonomics; behavior matches a single batched delivery on dismiss.
- Depth extraction is best-effort: any failure path (auth, iCloud, decode) collapses to `nil`. Callers branch on presence; no thrown errors. The free-vs-premium line stays clean — we *expose* the depth buffer, kadr-pro *uses* it.
- HDR detection covers HDR10 / HLG transfer functions plus Dolby Vision profiles via codec FourCC. Color-space conversion is explicitly out of scope (kadr-pro).

## [0.5.0] - 2026-05-03

Slow-motion video preservation + programmatic album asset listing. Pure additive — every v0.4 call site compiles unchanged. Kadr floor stays at **0.9.2**.

### Added

- **`PhotosClipResolver.slowMotion(asset:options:progress:)`** — async resolver for high-frame-rate slow-motion videos. Always overrides `videoExportPreset` to `AVAssetExportPresetPassthrough` so the original 60 / 120 / 240 fps source frame rate survives the export. Throws ``PhotosClipError/notSlowMotion`` for assets without `videoHighFrameRate` subtype.
- **`PhotosClipResolver.videoFrameRate(of:)`** — async; loads the underlying `AVAsset` and reads the video track's `nominalFrameRate`. Useful for choosing a slow-mo speed multiplier programmatically.
- **`PhotosClipResolver.slowMotionSpeed(originalFrameRate:playbackFrameRate:)`** — pure helper for the speed-multiplier divide. Defaults playback to 30 fps; defensive against zero / negative inputs.
- **`PhotosClipError.notSlowMotion`** — new error case thrown by both slow-mo entry points when the asset lacks the high-frame-rate subtype.
- **`PhotosClipResolver.assets(in: PHAssetCollection, mediaType:)`** — async lister returning `[PHAsset]` from a specified album in its natural order. Optional `PhotosMediaKind` filter.
- **`PhotosClipResolver.smartAlbum(_:)`** — synchronous lookup for built-in smart albums by `PHAssetCollectionSubtype` (Slo-mo, Favorites, Recents, Time-lapse, Screenshots, Panoramas, Live Photos, all-Videos, Camera Roll).

### Tests

- 11 new tests across `SlowMotionTests` (9) and `AlbumListingTests` (2). Suite: 57 → 68. PHAsset-dependent paths remain integration-tested in the example app, same pattern as the existing `video(asset:)` resolver.

### Notes

- **Pivot from the original Tier 2 plan**: I'd scoped `PhotoPicker(...assetCollection:)` to filter the picker UI to a specific album, but `PHPickerConfiguration` doesn't expose album scoping in any current Apple SDK. The programmatic listing path is more flexible — consumers can render their own album UI and resolve selected entries through `video()` / `image()` / `clip(from:)`.
- **iOS slow-motion regions** (the user-defined slow-mo ramp inside Photos.app) aren't honored — the export carries the source's full frame rate; consumers apply their own `clip.speed(curve:)` ramp downstream. Honoring the `PHAssetResource` adjustment metadata is a much bigger surface and isn't on the roadmap.
- Cycle considered feature-complete pending kadr v1.0.

## [0.4.0] - 2026-04-30

PHAsset metadata + direct overlay helpers. Closes the v0.x cycle. Pure additive — every v0.3 call site compiles unchanged.

### Added

- **`PhotoAssetMetadata`** value type — snapshot of PHAsset properties: `creationDate`, `modificationDate`, `location` (CLLocation), `pixelSize`, `videoDuration`, `subtypes`, `isFavorite`, `burstIdentifier`, `mediaKind`. `Equatable` + `@unchecked Sendable` (CLLocation is thread-safe but not Swift-Sendable).
- **`PhotoAssetSubtypes`** OptionSet — kadr-side mirror of `PHAssetMediaSubtype`. Cases: `.livePhoto`, `.highFrameRate`, `.timelapse`, `.panorama`, `.hdr`, `.screenshot`, `.depthEffect`, `.cinematic`, `.streamed`. `.spatial` reserved for forward compat.
- **`PhotosClipResolver.metadata(of:)`** — synchronous PHAsset property read; no iCloud round-trip.
- **`PhotosClipResolver.imageOverlay(asset:position:size:anchor:opacity:options:progress:)`** — async, resolves a PHAsset's still half and produces a `Kadr.ImageOverlay` ready for `Video.overlay(_:)`.
- **`PhotosClipResolver.stickerOverlay(asset:position:size:anchor:opacity:rotation:shadow:options:progress:)`** — same shape but produces a `StickerOverlay` (adds rotation + shadow modifiers).

### Behavior

- `metadata(of:)` is synchronous — no `PHImageManager` request. PHAsset read-only properties only.
- `PhotoAssetSubtypes.from(PHAssetMediaSubtype)` exposed for the bridge mapping.
- The overlay helpers reuse the existing `image()` resolver path — they just chain kadr's overlay modifiers on top of the resulting `PlatformImage`.
- Live Photo asset → still half on the overlay path. Live Photo motion as overlay isn't a kadr surface (overlays are static).

### Tests

- 21 new tests covering `PhotoAssetSubtypes` shape (empty / union / equality / 9 individual flag bridges from `PHAssetMediaSubtype` / multi-flag bridge), `PhotoAssetMetadata` equality semantics (creationDate / location coordinates / favorite), and overlay helper signatures (5 compile-time presence checks). Suite: 36 → 57.

### Notes

- EXIF preservation (`f-stop`, `exposureTime`, etc.), HEIC depth maps, and AVMetadata video exposure are explicit non-goals for v0.4. The CGImageSource plumbing for EXIF would justify ~150 LOC for a niche surface; defer until a real consumer asks.
- `.spatial` (Apple's `PHAssetMediaSubtype.spatialMedia`) ships in iOS 18+ / visionOS 2+; we keep the iOS 16 deployment floor and don't bridge it yet. The `.spatial` flag exists in `PhotoAssetSubtypes` for forward compat.

## [0.3.0] - 2026-04-30

`PHPickerViewController` SwiftUI wrapper. The PhotosUI bridge — wraps the system picker as a cross-platform SwiftUI `View` that returns directly into kadr clip types, bypassing the manual `PHAsset` round-trip.

### Added

- **`PhotoPicker(selection:configuration:)`** SwiftUI view. `UIViewControllerRepresentable` on iOS / visionOS, `NSViewControllerRepresentable` on macOS.
- **`PhotoPickerResult`** value type — `Sendable` + `Equatable` + `Identifiable`. Wraps the `assetIdentifier` returned by `PHPickerResult`; `@MainActor resolveAsset() -> PHAsset?` resolves on demand.
- **`PhotoPicker.Configuration`** — `selectionLimit` (`0` = unlimited), `filter`, `preferredAssetRepresentationMode`. Sensible defaults.
- **`PhotoPicker.Filter`** (`.images` / `.videos` / `.livePhotos` / `.any`) with `phFilter` bridge to `PHPickerFilter`.
- **`PhotoPicker.AssetRepresentationMode`** (`.automatic` / `.current` / `.compatible`) with `phMode` bridge to `PHPickerConfiguration.AssetRepresentationMode`.
- **`PhotosClipResolver.clip(from:imageDuration:options:progress:)`** — convenience that resolves a `PhotoPickerResult` to `any Clip` by inspecting `PHAsset.mediaType`. `CMTime` and `TimeInterval` overloads.
- **`PhotosClipResolver.clips(from:imageDuration:options:progress:)`** — array overload; resolves serially in declaration order. `CMTime` and `TimeInterval` overloads.

### Behavior

- `PHPickerConfiguration` is built with `photoLibrary: .shared()` so `assetIdentifier` round-trips correctly through `PHAsset.fetchAssets`.
- The picker doesn't require library authorization to display — but `PhotoPickerResult.resolveAsset()` and the downstream `clip(from:)` do (same v0.1 contract). Calling `PHPhotoLibrary.requestAuthorization` remains the consuming app's responsibility.
- `clip(from:)` dispatches on `PHAsset.mediaType`: `.video` → `video()`, `.image` → `image()`, other (`.audio` / `.unknown`) throws `PhotosClipError.wrongMediaType`.
- For Live Photo motion, call `livePhotoMotion(asset:)` directly — `clip(from:)` dispatches on `mediaType` (which is `.image` for Live Photos) and returns the still half.
- Asset resolution happens on `MainActor` (where `PHAsset.fetchAssets` is safe); the result is wrapped in an internal `@unchecked Sendable` carrier and handed to the non-isolated downstream resolvers.

### Tests

- 15 new tests covering `PhotoPickerResult` identity / equality, `Configuration` defaults / equality, `Filter` / `AssetRepresentationMode` enum bridges, `makePHConfiguration` mapping, `mapResults` empty input, and `clip(from:)` / `clips(from:)` overload signatures + empty-array fast path. Suite: 21 → 36.

### Notes

- Live picker UX is not unit-testable (PHPickerViewController needs a real window). Manual integration testing in a host app remains the source of truth for the picker's runtime behavior.
- `clips(from:)` reports per-asset progress via the `progress` callback on each asset. A merged "67% across all 5" callback would need an additional API; deferred until consumers ask.

## [0.2.0] - 2026-04-30

Live Photo support. Surfaces both halves of a Live Photo `PHAsset` as kadr clip types — drop the motion as a `VideoClip` (animated story card / boomerang), drop the still as an `ImageClip`, or use both. Pure additive — every v0.1 call site compiles unchanged.

### Added

- **`PhotosClipResolver.livePhotoMotion(asset:progress:)`** — async, returns `VideoClip`. Iterates `PHAssetResource.assetResources(for:)`, picks the `.pairedVideo` resource, writes to a temp `.mov` URL via `PHAssetResourceManager.writeData(for:toFile:options:completionHandler:)`. iCloud download progress reported via `@Sendable (Double) -> Void` callback.
- **`PhotosClipResolver.livePhotoStill(asset:duration:options:progress:)`** — async, returns `ImageClip`. Symmetric Live-Photo-guarded wrapper around the existing `image()` resolver. `CMTime` and `TimeInterval` overloads.
- **`PhotosClipError.notALivePhoto`** — new error case thrown by both Live Photo resolvers when `asset.mediaSubtypes.contains(.photoLive)` is false.

### Behavior

- Motion output written to `FileManager.temporaryDirectory + UUID + .mov`. Caller manages the temp file lifecycle thereafter (same contract as v0.1's `video()`).
- `livePhotoStill` is a thin wrapper — once the guard passes it delegates to `image(asset:duration:options:progress:)` unchanged. Existing `Options` struct (target size, content mode, delivery mode) applies.
- Live Photos with no `.pairedVideo` resource (rare iCloud / sync edge case) throw `PhotosClipError.missingMedia`.

### Tests

- 6 new tests covering `notALivePhoto` equality, temp URL generation (uniqueness / extension / location), and the Live Photo resolver overload signatures. Suite: 15 → 21.

### Notes

- Combined `livePhoto(asset:)` returning both halves was considered and dropped — consumers want one or the other in practice; if both, two calls.
- Live Photo motion clips are nominally ~3 seconds; iOS sometimes captures up to ~6 seconds. v0.2 surfaces the full resource duration. Consumers can `.trimmed(to:)` the resulting `VideoClip` if they want a fixed length.
- The paired video has audio. v0.2 returns it as-is; consumers can `.muted()` if desired.

## [0.1.0] - 2026-04-30

The first release. Resolves video and image `PHAsset`s into kadr's `VideoClip` / `ImageClip` types, with iCloud download progress reporting and typed errors. Adapter package consuming kadr v0.9.2 — kadr core deliberately avoids the `Photos` / `PhotosUI` frameworks; this package handles the bridging.

### Added

- **`PhotosClipResolver.video(asset:options:progress:)`** — async, returns `VideoClip`. Downloads from iCloud if needed, then exports to a temp `.mp4` URL via `AVAssetExportSession`.
- **`PhotosClipResolver.image(asset:duration:options:progress:)`** — async, returns `ImageClip` at the requested target size. `CMTime` and `TimeInterval` overloads.
- **`PhotosClipResolver.Options`** — tuning struct: image target size, content mode, delivery mode, video export preset.
- **`PhotosClipResolver.TargetSize`** — `.maximumSize` (default) or `.pixels(width:height:)`.
- **`PhotosClipResolver.ImageContentMode`** / **`ImageDeliveryMode`** — re-exported subsets of `PHImageContentMode` / `PHImageRequestOptionsDeliveryMode` so consumers don't have to import `Photos` just to set options.
- **`PhotosClipError`** — typed errors: `unauthorized`, `wrongMediaType`, `missingMedia`, `iCloudDownload`, `videoExportFailed`. `Equatable`.
- **`PhotosMediaKind`** — re-exported `PHAssetMediaType` subset (`video` / `image` / `audio` / `unknown`). `Sendable` + `Equatable`.

### Behavior

- Authorization checked via `PHPhotoLibrary.authorizationStatus(for: .readWrite)` before any request. `.authorized` and `.limited` (iOS 14+ partial access) both pass; everything else throws `PhotosClipError.unauthorized` immediately.
- Media-type guard rejects mismatch with `PhotosClipError.wrongMediaType(expected:actual:)`.
- iCloud download progress reported via `@Sendable (Double) -> Void` callback.
- Video output written to `FileManager.temporaryDirectory + UUID + .mp4`. Caller manages the temp file lifecycle thereafter.
- Image-resolver opportunistic-delivery first emission (degraded preview) is filtered out — we only resolve on the high-quality image. With the default `.highQualityFormat` delivery mode, the result handler typically fires once anyway.
- `ContinuationBox` guards against `PHImageManager` invoking the result handler more than once.

### Compatibility

- Requires kadr ≥ 0.9.2 (uses `VideoClip` + `ImageClip`).
- iOS 16+, macOS 13+, visionOS 1+. **tvOS deliberately excluded** — `Photos.framework` unavailable on tvOS.
- Required entitlement (consumer): `NSPhotoLibraryUsageDescription` for read access. Apps using `PHPhotoLibrary.requestAuthorization` to write to the library also need `NSPhotoLibraryAddUsageDescription`.
- No third-party dependencies. Pure Swift + Foundation + AVFoundation + Photos.

### Tests

- 15 unit tests covering `PhotosMediaKind` mapping, `Options` defaults / equality, `TargetSize.cgSize`, `ImageContentMode` / `ImageDeliveryMode` → AVFoundation enum bridges, temp-URL generation (uniqueness / extension / location), `PhotosClipError` equality, and image-resolver overload signatures.
- PHAsset-backed paths require a real photo library + authorization and are covered by manual integration testing in consuming apps, not the unit suite — per RFC test strategy.

### Notes

- Live Photo support is deferred to v0.2.0.
- `PHPickerViewController` SwiftUI wrapper is deferred to v0.3.0+.
- Burst / Slo-mo / Time-lapse subtypes are treated as plain video assets in v0.1; `mediaSubtype` info isn't surfaced.
