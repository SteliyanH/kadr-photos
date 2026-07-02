# KadrPhotos Roadmap

This document outlines the planned feature releases for KadrPhotos. Each release is gated on the matching [kadr](https://github.com/SteliyanH/kadr) public surface.

For kadr's roadmap see [kadr/ROADMAP.md](https://github.com/SteliyanH/kadr/blob/main/ROADMAP.md).

## v0.1.0 — Video + image PHAsset resolution ✓ shipped

The first release. Resolves `PHAsset` videos and stills into kadr clip types, with iCloud download progress reporting.

- `PhotosClipResolver.video(asset:options:progress:)` — async, returns `VideoClip`. Downloads from iCloud if `asset.sourceType` is in the cloud.
- `PhotosClipResolver.image(asset:duration:options:progress:)` — async, returns `ImageClip` at the requested target size.
- `PhotosClipError` — typed errors for unauthorized access, missing media, iCloud failure, format unsupported.
- `PhotosClipResolver.Options` — request-tuning struct (target size for images, video preset for export, deliveryMode for image quality vs. speed).

Depends on **kadr v0.9.2** (uses `VideoClip` + `ImageClip`).

Platforms: iOS 16+, macOS 13+, visionOS 1+. **tvOS excluded** — Photos framework is not available on tvOS.

## v0.2.0 — Live Photo ✓ shipped

Live Photo support. Both halves of a Live Photo `PHAsset` surface as kadr clip types.

- `PhotosClipResolver.livePhotoMotion(asset:progress:)` — extract the paired video as `VideoClip` via `PHAssetResource` + `PHAssetResourceManager.writeData`.
- `PhotosClipResolver.livePhotoStill(asset:duration:options:progress:)` — Live-Photo-guarded wrapper around the existing `image()` resolver. CMTime + TimeInterval overloads.
- New `PhotosClipError.notALivePhoto` for assets where `mediaSubtypes.contains(.photoLive)` is false.

## v0.3.0 — PhotoPicker SwiftUI wrapper ✓ shipped

Cross-platform SwiftUI wrapper around `PHPickerViewController`. Returns directly into kadr clip types, bypassing the manual `PHAsset` round-trip for the common "user picks N items, build a video" flow.

- `PhotoPicker(selection:configuration:)` SwiftUI view (UIKit + AppKit branches)
- `PhotoPickerResult` value type with `@MainActor resolveAsset() -> PHAsset?`
- `PhotoPicker.Configuration` + `Filter` + `AssetRepresentationMode`
- `PhotosClipResolver.clip(from:)` + `clips(from:)` — dispatch on `mediaType`, return `any Clip`

## v0.4.0 — Metadata + overlay helpers ✓ shipped

PHAsset metadata snapshot + thin helpers that bridge a PHAsset directly to kadr's overlay types. Closes the v0.x cycle — kadr-photos is now feature-complete for the originally-scoped surface.

- `PhotoAssetMetadata` value type + `PhotoAssetSubtypes` OptionSet (kadr-side mirror of `PHAssetMediaSubtype`)
- `PhotosClipResolver.metadata(of:)` — synchronous PHAsset property read
- `PhotosClipResolver.imageOverlay(asset:)` + `stickerOverlay(asset:)` — bridges to `Kadr.ImageOverlay` / `StickerOverlay`

## v0.5.0 — Slow-motion + album asset listing ✓ shipped

Two additions from a final value-vs-complexity audit. Pure additive — every v0.4 call site compiles unchanged.

- **`PhotosClipResolver.slowMotion(asset:options:progress:)`** — always overrides `videoExportPreset` to `AVAssetExportPresetPassthrough` so the original 60 / 120 / 240 fps source survives. Throws `PhotosClipError.notSlowMotion` for non-slo-mo assets.
- **`PhotosClipResolver.videoFrameRate(of:)`** + **`slowMotionSpeed(originalFrameRate:playbackFrameRate:)`** — async frame-rate read + pure speed-multiplier helper for choosing the playback ramp.
- **`PhotosClipResolver.assets(in: PHAssetCollection, mediaType:)`** + **`smartAlbum(_:)`** — programmatic album listing. (Originally planned as a `PhotoPicker(...assetCollection:)` overload, but `PHPickerConfiguration` doesn't expose album scoping; the listing path is more flexible.)

Cycle considered feature-complete pending kadr v1.0.

## v0.7.0 — iOS 17 platform floor ✓ shipped

Mechanical floor bump to **iOS 17 / macOS 14 / visionOS 1** (`Package.swift` platforms + Kadr dependency floor → ≥ 0.15.0). Required because a package with an iOS 16 floor can't depend on Kadr 0.15 (iOS 17). Dropped 8 redundant `@available(iOS 16…)` annotations and refreshed stale docstrings (Kadr's removed `speed(_:)` / `speed(curve:)` → `Speed` enum form; picker floor note). No code or behavior change. Part of the coordinated ecosystem iOS 17 move (kadr v0.15 / kadr-ui v0.12 / kadr-captions v0.8 / kadr-photos v0.7 / reels-studio `@Observable`). Consumers needing iOS 16 stay on `0.6.x`. 80 tests unchanged.

## v0.6.0 — HDR-aware resolution + iOS 17 picker async sequence ✓ shipped

Reopened cycle. v0.5 covered every common PHAsset resolution path (video / image / Live Photo / slow-motion / album listing). v0.6 adds the surfaces that have come up downstream now that real users hit them. All additive — every v0.5 call site compiles unchanged. Three additions:

- **HDR / Dolby Vision asset passthrough.** New `PhotosClipResolver.videoHDRMetadata(of:)` async surfaces the asset's transfer function + color primaries + color matrix without pulling the full media. Pairs with **kadr-pro** (kadr's HDR pipeline is premium); the resolution side stays free so consumers can detect-and-route — "this is HDR" without "this exports HDR." The resolution path itself doesn't perform color-space conversion; that's kadr-pro's job.
- **iOS 17 `PHPickerViewController` async sequence.** `PhotoPicker` today uses the SwiftUI 16-style closure callback. iOS 17 added `PHPicker.results` as an `AsyncSequence`; expose via a new `PhotoPicker(...iOS17AsyncResults:)` overload that fires when iOS 17 is the deployment floor. The iOS 16 closure path stays for the floor.
- **Live Photos depth-channel extraction.** iPhone 12+ Live Photos carry a depth map alongside the still + video. New `PhotosClipResolver.depthMap(from:)` async returns a `CVPixelBuffer` (or nil for non-depth assets); consumers can feed it into Vision-side cutout pipelines (kadr-pro), or simpler chroma-key-style filtering (free).

Three tiers + release prep. Pairs with **kadr-reels-studio v0.8.x** (HDR badge in the project list — detect-and-display, no conversion) and **kadr-pro v0.1** (HDR export + Vision-based depth cutout consume these surfaces). Pure resolution expansion — nothing changes for consumers who only need the v0.5 happy path.

## Compatibility track record

| KadrPhotos | Requires Kadr |
|---|---|
| 0.1.0 | ≥ 0.9.2 |
| 0.2.0 | ≥ 0.9.2 |
| 0.3.0 | ≥ 0.9.2 |
| 0.4.0 | ≥ 0.9.2 |
| 0.5.0 | ≥ 0.9.2 |
| 0.6.0 | ≥ 0.9.2 |

## Contributing

Open an issue for missing PHAsset cases or PHPicker requests.
