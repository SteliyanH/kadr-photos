# KadrPhotos

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/steliyanh)

**Photos library integration for [Kadr](https://github.com/SteliyanH/kadr) — resolve `PHAsset` videos and stills into kadr clip types, with iCloud download progress reporting.**

KadrPhotos consumes kadr's `VideoClip` / `ImageClip` types and bridges them to the `Photos` / `PhotosUI` frameworks. Lives in its own package because kadr core deliberately avoids those frameworks.

## Quick Start

```swift
import Kadr
import KadrPhotos
import Photos

// Resolve a video PHAsset to a VideoClip
let videoClip = try await PhotosClipResolver.video(asset: phAsset) { progress in
    print("iCloud download: \(progress)")
}

// Resolve a still-image PHAsset to an ImageClip
let imageClip = try await PhotosClipResolver.image(asset: phAsset, duration: 3.0)

let video = Video {
    videoClip
    imageClip
}
```

## Components

| API | Purpose |
|---|---|
| `PhotosClipResolver.video(asset:options:progress:)` | Resolve a video `PHAsset` to a `VideoClip` (downloads from iCloud if needed) |
| `PhotosClipResolver.image(asset:duration:options:progress:)` | Resolve an image `PHAsset` to an `ImageClip` |
| `PhotosClipResolver.livePhotoMotion(asset:progress:)` | Extract the paired-video half of a Live Photo as a `VideoClip` |
| `PhotosClipResolver.livePhotoStill(asset:duration:options:progress:)` | Extract the still half of a Live Photo as an `ImageClip` (Live-Photo-guarded wrapper around `image()`) |
| `PhotoPicker(selection:configuration:)` *(v0.3)* | SwiftUI wrapper around `PHPickerViewController` |
| `PhotoPickerResult` *(v0.3)* | Wraps an `assetIdentifier`; `@MainActor resolveAsset()` returns the `PHAsset` |
| `PhotosClipResolver.clip(from:imageDuration:options:progress:)` *(v0.3)* | Resolve a `PhotoPickerResult` to `any Clip` (dispatches on `mediaType`) |
| `PhotosClipResolver.clips(from:imageDuration:options:progress:)` *(v0.3)* | Array convenience for batch resolution |
| `PhotosClipResolver.metadata(of:)` *(v0.4)* | Synchronous PHAsset property snapshot — `PhotoAssetMetadata` |
| `PhotoAssetMetadata` *(v0.4)* | creationDate / location / pixelSize / subtypes / etc. |
| `PhotoAssetSubtypes` *(v0.4)* | OptionSet — `.livePhoto` / `.panorama` / `.hdr` / `.screenshot` / etc. |
| `PhotosClipResolver.imageOverlay(asset:position:size:...)` *(v0.4)* | PHAsset → `Kadr.ImageOverlay` |
| `PhotosClipResolver.stickerOverlay(asset:position:size:rotation:shadow:...)` *(v0.4)* | PHAsset → `Kadr.StickerOverlay` |
| `PhotosClipResolver.slowMotion(asset:options:progress:)` *(v0.5)* | High-frame-rate-preserving slow-motion video export |
| `PhotosClipResolver.assets(in:mediaType:)` + `smartAlbum(_:)` *(v0.5)* | Programmatic album asset listing |
| `PhotosClipResolver.videoHDRMetadata(of:)` *(v0.6)* | Async HDR / Dolby Vision metadata read (`VideoHDRMetadata`) — detect-only, no conversion |
| `PhotoPicker(configuration:iOS17AsyncResults:)` *(v0.6)* | iOS 17+ overload delivering picks as an `AsyncStream<PhotoPickerResult>` |
| `PhotosClipResolver.depthMap(from:)` *(v0.6)* | Async depth `CVPixelBuffer?` for iPhone 12+ Live Photos (disparity / depth / matte aux) |
| `PhotosClipError` | Typed errors for permissions, missing media, iCloud failures, non-Live-Photo asset |

## Roadmap

See [ROADMAP.md](ROADMAP.md). Shipped: video + image resolution (v0.1), Live Photo (v0.2), PhotosUI `PhotoPicker` (v0.3), metadata + overlay helpers (v0.4), slow-motion preservation + album asset listing (v0.5), HDR-aware resolution + iOS 17 picker async results + Live Photos depth extraction (v0.6), iOS 17 platform floor (v0.7.0), DocC catalogue + `.upToNextMinor` pinning (v0.7.1), `LocalizedError` conformance (v0.8.0), kadr 0.17 adoption (v0.9.0). Resolution surface is feature-complete; v1.0 tracks kadr v1.0.

## Installation

```swift
.package(url: "https://github.com/SteliyanH/kadr-photos.git", .upToNextMinor(from: "0.9.0")),
```

Add `KadrPhotos` to your target's dependencies. `Kadr` is pulled in transitively — 0.9.x resolves `>=0.17.0, <0.18.0`.

> **Use `.upToNextMinor`, not `from:`.** `from:` means `.upToNextMajor`, and SwiftPM does not special-case `0.x` — so `from: "0.9.0"` would accept every future 0.x release including breaking ones. This package's own kadr dependency is pinned the same way, because kadr's minors do break: 0.15.0 raised the platform floor.

**Required entitlement:** `NSPhotoLibraryUsageDescription` in your app's Info.plist for read access to the user's photo library. Apps using `PHPhotoLibrary.requestAuthorization` to write to the library also need `NSPhotoLibraryAddUsageDescription`.

## Platform support

`Photos.framework` is available on iOS 16+, macOS 13+, and visionOS 1+. **tvOS is excluded** — Apple does not ship the Photos framework on tvOS.

## License

Apache-2.0. See [LICENSE](LICENSE).

Contributions are accepted under the [Contributor License Agreement](CLA.md), which is signed once and covers all future contributions. It does not transfer ownership — you keep the copyright in your work.
