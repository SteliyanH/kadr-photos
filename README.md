# KadrPhotos

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016+%20|%20macOS%2013+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

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
| `PhotosClipError` | Typed errors for permissions, missing media, iCloud failures, non-Live-Photo asset |

## Roadmap

See [ROADMAP.md](ROADMAP.md). v0.1.0: video + image PHAsset resolution. v0.2.0: Live Photo support (still + motion as a unit). Later: PhotosUI picker integration.

## Installation

```swift
.package(url: "https://github.com/SteliyanH/kadr-photos.git", from: "0.1.0"),
```

Add `KadrPhotos` to your target's dependencies. `Kadr` is pulled in transitively (≥ `0.9.2`).

**Required entitlement:** `NSPhotoLibraryUsageDescription` in your app's Info.plist for read access to the user's photo library. Apps using `PHPhotoLibrary.requestAuthorization` to write to the library also need `NSPhotoLibraryAddUsageDescription`.

## Platform support

`Photos.framework` is available on iOS 16+, macOS 13+, and visionOS 1+. **tvOS is excluded** — Apple does not ship the Photos framework on tvOS.

## License

Apache-2.0. See [LICENSE](LICENSE).
