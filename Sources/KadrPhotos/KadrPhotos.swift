import Kadr

/// KadrPhotos — Photos library integration for kadr.
///
/// See [DESIGN.md](https://github.com/SteliyanH/kadr-photos/blob/main/DESIGN.md) for
/// the v0.1 RFC. Public API lands in subsequent tier PRs (video resolver → image
/// resolver → release).
///
/// **Platform support.** iOS 16+, macOS 13+, visionOS 1+. **tvOS excluded** —
/// `Photos.framework` is unavailable on tvOS.
public enum KadrPhotos {
    /// SemVer-style version string. Bumped on each release.
    public static let version = "0.1.0-dev"
}
