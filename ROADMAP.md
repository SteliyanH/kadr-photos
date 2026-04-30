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

## v0.2.0 — Live Photo *(planned)*

Live Photo support. A Live Photo is a still + ~3-second motion pair; the adapter exposes both halves so consumers can pick.

- `PhotosClipResolver.livePhotoMotion(asset:options:progress:)` — extract the motion half as a `VideoClip`.
- `PhotosClipResolver.livePhotoStill(asset:duration:options:progress:)` — extract the still as an `ImageClip` (alias of `image(asset:)` for clarity).

## v0.3.0+ — PhotosUI picker integration *(planned)*

`PHPickerViewController` SwiftUI wrapper that returns directly into kadr clip types — bypasses the `PHAsset` round-trip for the common "user picks N items, build a video" flow.

- `PhotoPicker(selection: Binding<[PHPickerResult]>) -> View`
- Convenience `Video.fromPhotoPicker(_:duration:)` builder

## Compatibility track record

| KadrPhotos | Requires Kadr |
|---|---|
| 0.1.0 | ≥ 0.9.2 |
| 0.2.0+ *(planned)* | ≥ 0.9.2 |

## Contributing

Open an issue for missing PHAsset cases or PHPicker requests.
