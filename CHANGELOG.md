# Changelog

All notable changes to KadrPhotos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

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
