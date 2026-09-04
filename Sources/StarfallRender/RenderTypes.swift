import AppKit

/// The Render module handles all visual presentation.
///
/// Uses SpriteKit to render the game. Rendering is strictly a
/// presentation concern and never modifies simulation state.

// MARK: - Typography

/// Font helpers used by every scene.
///
/// The scenes originally requested the names ".SF Pro Display" / ".SF Pro
/// Text", which CoreText does NOT recognize as PostScript font names on macOS.
/// Those requests silently fall back to Times New Roman (confirmed via the
/// CoreText "it will get TimesNewRomanPSMT" log), making the entire UI render
/// in a serif font. The correct addressable names are the system UI font
/// (".AppleSystemUIFont") for body text and "Helvetica Neue" for the display
/// titles. These constants centralize the choice so the whole app uses one
/// coherent, correctly-resolving typeface.
public enum GameFont {
    /// Large titles and headings (display cut).
    public static let display = "Helvetica Neue"
    /// Body / HUD / menu text (system UI cut).
    public static let text = ".AppleSystemUIFont"

    /// A display font, falling back safely if the name is unavailable.
    public static func display(size: CGFloat) -> NSFont {
        NSFont(name: display, size: size) ?? NSFont.boldSystemFont(ofSize: size)
    }

    /// A body font, falling back safely if the name is unavailable.
    public static func text(size: CGFloat) -> NSFont {
        NSFont(name: text, size: size) ?? NSFont.systemFont(ofSize: size)
    }
}
