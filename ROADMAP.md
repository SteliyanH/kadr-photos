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

## Compatibility track record

| KadrPhotos | Requires Kadr |
|---|---|
| 0.1.0 | ≥ 0.9.2 |
| 0.2.0 | ≥ 0.9.2 |
| 0.3.0 | ≥ 0.9.2 |
| 0.4.0 | ≥ 0.9.2 |

## Contributing

Open an issue for missing PHAsset cases or PHPicker requests.
