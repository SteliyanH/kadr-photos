import Kadr

/// KadrPhotos — Photos library integration for kadr.
///
/// See [DESIGN.md](https://github.com/SteliyanH/kadr-photos/blob/main/DESIGN.md) for
/// the design.
///
/// **Platform support.** iOS 17+, macOS 14+, visionOS 1+. **tvOS excluded** —
/// `Photos.framework` is unavailable on tvOS.
public enum KadrPhotos {
    /// The package's semantic version: the newest release in the CHANGELOG, which a
    /// test enforces.
    public static let version = "0.11.0"
}
