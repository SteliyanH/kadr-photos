# ``KadrPhotos``

Photos library integration for Kadr — resolve `PHAsset` videos, stills and Live
Photos into kadr clip types, with iCloud download progress reported as it goes.

## Overview

Kadr core deliberately avoids `Photos` and `PhotosUI`: linking them would force
a photo-library usage description onto every consumer, including those composing
video from files they already hold. KadrPhotos is where that dependency lives.

The work it does is mostly the work you would rather not write twice — an asset
in the user's library may be in iCloud rather than on device, may be a Live
Photo whose motion and still are separate resources, may be a slow-motion
capture whose real frame rate has to be recovered, and may fail in half a dozen
ways that all deserve different messages.

### Resolving an asset into a clip

```swift
import Kadr
import KadrPhotos

let clip = try await PhotosClipResolver.clip(from: asset)
let video = Video { clip }
```

``PhotosClipResolver/clip(from:)`` handles the iCloud round trip and reports
progress, so a picker flow can show something honest while a large asset
downloads instead of appearing to hang.

### Picking

``PhotoPicker`` wraps `PHPickerViewController` for SwiftUI, and
``PhotoPickerResult`` carries the selection back in a form the resolver accepts
directly — including an async-results path for selections large enough that
resolving them serially would be visible to the user.

### Beyond video clips

Assets also become overlays. ``PhotosClipResolver`` produces `ImageOverlay` and
`StickerOverlay` values, extracts depth maps where the capture carried them, and
surfaces ``PhotoAssetMetadata`` and ``VideoHDRMetadata`` so a consumer can make
decisions — HDR handling, slow-motion retiming — before committing to a
composition.

## Topics

### Resolving assets

- ``PhotosClipResolver``
- ``PhotosClipError``
- ``PhotosMediaKind``

### Picking

- ``PhotoPicker``
- ``PhotoPickerResult``

### Options

- ``Options``
- ``Configuration``
- ``TargetSize``
- ``ImageContentMode``
- ``ImageDeliveryMode``
- ``AssetRepresentationMode``

### Metadata

- ``PhotoAssetMetadata``
- ``PhotoAssetSubtypes``
- ``VideoHDRMetadata``
- ``ColorPrimaries``
- ``TransferFunction``
