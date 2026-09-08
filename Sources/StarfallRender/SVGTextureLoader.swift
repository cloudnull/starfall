import AppKit
import CoreGraphics
import SpriteKit
import StarfallCore
import StarfallData

/// SVG texture loader for Starfall.
///
/// Loads SVG files from Assets/svg/ and provides them as SKTextures.
/// The SVG source is the authoritative art asset; this loader reads
/// those files at runtime and converts them to textures.
///
/// Textures are cached by (name, size) to avoid re-parsing.
@MainActor
public final class SVGTextureLoader {
    public static let shared = SVGTextureLoader()

    private var cache: [String: SKTexture] = [:]

    private init() {}

    /// Loads (or returns cached) texture for a ship shape at the given size.
    public func texture(for shape: ShipShape, size: CGFloat) -> SKTexture? {
        let key = "\(shape.svgName)_\(Int(size))"

        if let cached = cache[key] {
            return cached
        }

        guard let svgURL = findSVGFile(named: shape.svgName, subdirectory: "ships") else {
            return nil
        }

        guard let texture = loadSVGTexture(from: svgURL, size: size) else {
            return nil
        }

        cache[key] = texture
        return texture
    }

    /// Loads a generic SVG texture by filename (for non-ship assets).
    public func texture(named: String, subdirectory: String? = nil, size: CGFloat) -> SKTexture? {
        let key = "\(subdirectory ?? "")_\(named)_\(Int(size))"

        if let cached = cache[key] {
            return cached
        }

        guard let svgURL = findSVGFile(named: named, subdirectory: subdirectory) else {
            return nil
        }

        guard let texture = loadSVGTexture(from: svgURL, size: size) else {
            return nil
        }

        cache[key] = texture
        return texture
    }

    /// Finds an SVG file in the Assets/svg directory structure.
    /// Tries bundle resources first, then filesystem.
    private func findSVGFile(named name: String, subdirectory: String?) -> URL? {
        let bundle = Bundle.module

        // Try with subdirectory
        if let subdir = subdirectory {
            if let url = bundle.url(
                forResource: name,
                withExtension: "svg",
                subdirectory: "svg/\(subdir)"
            ) {
                return url
            }
        }

        // Try direct in svg directory
        if let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "svg") {
            return url
        }

        // Try in svg/ships
        if let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "svg/ships") {
            return url
        }

        // Fallback: look in filesystem (for development)
        let projectRoot = FileManager.default.currentDirectoryPath
        let fsPath: String
        if let subdir = subdirectory {
            fsPath = "\(projectRoot)/Assets/svg/\(subdir)/\(name).svg"
        } else {
            fsPath = "\(projectRoot)/Assets/svg/ships/\(name).svg"
        }

        if FileManager.default.fileExists(atPath: fsPath) {
            return URL(fileURLWithPath: fsPath)
        }

        // Last resort: try all subdirs
        if let url = bundle.url(forResource: name, withExtension: "svg") {
            return url
        }

        return nil
    }

    /// Loads an SVG file as an SKTexture using Core Graphics Image I/O.
    private func loadSVGTexture(from url: URL, size: CGFloat) -> SKTexture? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("SVGTextureLoader: Failed to create image source for \(url.lastPathComponent)")
            return nil
        }

        let scaleFactor: CGFloat = size >= 32 ? 2.0 : 1.0
        let targetSize = CGSize(width: size * scaleFactor, height: size * scaleFactor)

        // Use CGImageSourceCreateImageAtIndex to rasterize the SVG
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: true,
        ]

        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
            return SKTexture(cgImage: cgImage)
        }

        // Fallback: NSImage → bitmap → CGImage
        if let imageRep = NSImage(contentsOf: url) {
            let targetRep = NSImage(size: targetSize)
            targetRep.lockFocus()
            NSGraphicsContext.saveGraphicsState()
            if let context = NSGraphicsContext.current {
                context.cgContext.interpolationQuality = .high
            }
            imageRep.draw(in: CGRect(origin: .zero, size: targetSize),
                          from: .zero,
                          operation: .copy,
                          fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            targetRep.unlockFocus()

            if let tiffData = targetRep.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let cgImg = bitmap.cgImage {
                return SKTexture(cgImage: cgImg)
            }
        }

        print("SVGTextureLoader: Failed to rasterize \(url.lastPathComponent)")
        return nil
    }
}

/// Category-specific texture accessors.
@MainActor
public extension SVGTextureLoader {

    /// Returns texture for a projectile type.
    func projectileTexture(type: WeaponType, size: CGFloat) -> SKTexture? {
        let svgName: String
        switch type {
        case .laser: svgName = "laser"
        case .missile: svgName = "missile"
        case .tracking: svgName = "missile"
        case .spread: svgName = "spread"
        case .cone: svgName = "cone"
        default: svgName = "projectile"
        }
        return texture(named: svgName, subdirectory: "projectiles", size: size)
    }

    /// Returns texture for an explosion effect.
    func explosionTexture(size: CGFloat) -> SKTexture? {
        texture(named: "explosion", subdirectory: "effects", size: size)
    }

    /// Returns texture for a thrust flame effect.
    func thrustFlameTexture(size: CGFloat) -> SKTexture? {
        texture(named: "thrust_flame", subdirectory: "effects", size: size)
    }

    /// Returns texture for an impact flash.
    func impactFlashTexture(size: CGFloat) -> SKTexture? {
        texture(named: "impact_flash", subdirectory: "effects", size: size)
    }

    /// Returns texture for a shield effect.
    func shieldTexture(size: CGFloat) -> SKTexture? {
        texture(named: "shield", subdirectory: "effects", size: size)
    }

    /// Returns texture for a planet.
    func planetTexture(size: CGFloat, variant: Int = 0) -> SKTexture? {
        let svgName: String
        switch variant {
        case 0: svgName = "planet_default"
        case 1: svgName = "planet_desert"
        case 2: svgName = "planet_ice"
        case 3: svgName = "planet_gas"
        default: svgName = "planet_default"
        }
        return texture(named: svgName, subdirectory: "planets", size: size)
    }

    /// Returns texture for the starfield background.
    func starfieldTexture(size: CGSize) -> SKTexture? {
        guard let url = findSVGFile(named: "starfield", subdirectory: "ui") else {
            return nil
        }
        return loadSVGTexture(from: url, size: size.width)
    }
}
