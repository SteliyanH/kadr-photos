import Photos

// The names the README snippets use, so that they compile. Nothing here runs:
// the Examples target is built, never executed, so a placeholder asset is never
// handed to the Photos library and no permission prompt can appear.
//
// Computed rather than stored: a stored global `PHAsset` would be shared
// mutable state as far as Swift 6 is concerned.

var phAsset: PHAsset { PHAsset() }
