import AppKit
import SpriteKit
import StarfallCore

/// Cinematic defeat scene: the fall of the Compact, the Chorus broadcast,
/// and the escaping ship that carries the seeds of resistance.
/// Tone is somber but promising — not despairing.
@MainActor
public final class DefeatScene: SKScene {
    
    public var onClose: (() -> Void)?
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }
    
    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private struct Page: Hashable {
        let title: String
        let speaker: String?
        let body: String
    }
    
    private let pages: [Page] = [
        Page(
            title: "Defeat",
            speaker: nil,
            body: "The Compact's last fleet is destroyed. The final free systems fall. Slave shields close over the remaining Barrier Worlds."
        ),
        Page(
            title: "The Chorus Speaks",
            speaker: "The Chorus",
            body: "\"Silence the dissonance. Absorb the stragglers. The Reach is whole again. This is not destruction — it is salvation. Order, at last.\""
        ),
        Page(
            title: "Silence",
            speaker: "Zzrr'tkal",
            body: "\"The harmonic is gone. Not broken — extinguished. We held for so long, and yet the resonance fades. There will be silence across the Reach for an age.\""
        ),
        Page(
            title: "Silence",
            speaker: "Elara Moss",
            body: "\"I don't know if anyone will read this. If you do — know that we fought. Know that we chose to fight, even when we knew we would lose. That has to mean something.\""
        ),
        Page(
            title: "The Last Transmission",
            speaker: nil,
            body: "In the void beyond the front lines, a single Compact ship — badly damaged, crew reduced to a handful — slips into uncharted space."
        ),
        Page(
            title: "The Last Transmission",
            speaker: nil,
            body: "It carries a data core: everything the Compact learned about the Vexari. Their tactics. Their weaknesses. The location of their command structure."
        ),
        Page(
            title: "The Last Transmission",
            speaker: "Compact Survivor",
            body: "\"We are not gone. We are seeding. Wait for us.\""
        ),
    ]
    
    private var page: Int = 0
    
    // Layers
    private let bgLayer = SKNode()
    private let contentLayer = SKNode()
    private let controlsLayer = SKNode()
    
    // UI nodes
    private let titleLabel = SKLabelNode()
    private let speakerLabel = SKLabelNode()
    private let bodyLabel = SKLabelNode()
    private let pageLabel = SKLabelNode()
    private let closeLabel = SKLabelNode()
    private var fadeOverlay = SKSpriteNode()
    
    public override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = NSColor.black
        setupScene()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupScene() {
        bgLayer.zPosition = 0
        addChild(bgLayer)
        
        // Cool, dim defeat background
        let bgGradient = SKShapeNode(rectOf: size)
        bgGradient.fillColor = NSColor(
            red: 0.08, green: 0.02, blue: 0.04, alpha: 1.0
        )
        bgGradient.strokeColor = .clear
        bgGradient.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(bgGradient)
        // Slow push-in for a cinematic dolly feel.
        let zoomIn = SKAction.scale(to: 1.06, duration: 30)
        bgGradient.run(.repeatForever(zoomIn))

        // Subtle red vignette
        let vignette = SKSpriteNode(
            color: NSColor.systemRed.withAlphaComponent(0.02),
            size: CGSize(width: size.width, height: size.height)
        )
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(vignette)

        // Dim overlay for readability
        let overlay = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.5),
            size: size
        )
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(overlay)

        // Fade overlay for page transitions
        fadeOverlay = SKSpriteNode(
            color: NSColor.black,
            size: size
        )
        fadeOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        fadeOverlay.alpha = 0
        fadeOverlay.zPosition = 100
        addChild(fadeOverlay)

        contentLayer.zPosition = 10
        addChild(contentLayer)

        let centerX = size.width / 2
        let startY: CGFloat = CGFloat(size.height) * 0.68
        let maxWidth: CGFloat = size.width * 0.65

        // Title
        titleLabel.fontName = "Helvetica Neue"
        titleLabel.fontSize = 28
        titleLabel.fontColor = NSColor.systemRed.withAlphaComponent(0.85)
        titleLabel.position = CGPoint(x: centerX, y: startY)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.preferredMaxLayoutWidth = maxWidth
        contentLayer.addChild(titleLabel)

        // Speaker
        speakerLabel.fontName = ".AppleSystemUIFont"
        speakerLabel.fontSize = 14
        speakerLabel.fontColor = NSColor.systemPurple.withAlphaComponent(0.8)
        speakerLabel.position = CGPoint(x: centerX, y: startY - 38)
        speakerLabel.horizontalAlignmentMode = .center
        contentLayer.addChild(speakerLabel)
        speakerLabel.isHidden = true

        // Divider — rect centered at origin, positioned at its center
        let divider = SKShapeNode(rectOf: CGSize(width: maxWidth, height: 1))
        divider.fillColor = .clear
        divider.strokeColor = NSColor.systemRed.withAlphaComponent(0.2)
        divider.lineWidth = 1
        divider.position = CGPoint(x: centerX, y: startY - 58)
        contentLayer.addChild(divider)
        
        // Body
        bodyLabel.fontName = ".AppleSystemUIFont"
        bodyLabel.fontSize = 15
        bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        bodyLabel.position = CGPoint(x: centerX, y: startY - 85)
        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.preferredMaxLayoutWidth = maxWidth
        contentLayer.addChild(bodyLabel)
        
        // Page indicator
        pageLabel.fontName = ".AppleSystemUIFont"
        pageLabel.fontSize = 11
        pageLabel.fontColor = NSColor.darkGray
        pageLabel.position = CGPoint(x: centerX, y: 40)
        pageLabel.horizontalAlignmentMode = .center
        controlsLayer.addChild(pageLabel)

        // Skip button — lets the player jump to the end of the cinematic.
        let skipBtn = createSkipButton()
        skipBtn.position = CGPoint(x: 80, y: 50)
        skipBtn.name = "skip"
        controlsLayer.addChild(skipBtn)
        
        // Close hint
        closeLabel.fontName = ".AppleSystemUIFont"
        closeLabel.fontSize = 12
        closeLabel.fontColor = NSColor.gray.withAlphaComponent(0.5)
        closeLabel.position = CGPoint(x: centerX, y: 65)
        closeLabel.horizontalAlignmentMode = .center
        controlsLayer.addChild(closeLabel)
        
        addChild(controlsLayer)
        
        // Initial fade-in
        fadeOverlay.alpha = 1
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 2.0)
        fadeOverlay.run(fadeIn)
        
        // Dim, drifting particles — the last embers of the fight.
        startAmbientParticles()
        
        updatePage()
    }
    
    /// Draw a small radial-gradient sprite for use as a particle texture.
    private static func radialParticleTexture(color: NSColor, size: CGFloat = 12) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let gradient = NSGradient(starting: color.withAlphaComponent(0.9), ending: color.withAlphaComponent(0))!
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        gradient.draw(in: rect, relativeCenterPosition: .zero)
        image.unlockFocus()
        return image
    }
    
    private func startAmbientParticles() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(image: Self.radialParticleTexture(color: NSColor(white: 0.6, alpha: 1)))
        emitter.particleColor = NSColor(white: 0.5, alpha: 0.4)
        emitter.particleColorBlendFactor = 1
        emitter.particleBirthRate = 6
        emitter.particleLifetime = 6
        emitter.particleLifetimeRange = 3
        emitter.emissionAngle = -.pi / 2
        emitter.particleSpeed = 12
        emitter.particleSpeedRange = 10
        emitter.particleAlpha = 0
        emitter.particleAlphaSpeed = 0.08
        emitter.particleScale = 0.4
        emitter.particleScaleRange = 0.3
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.position = CGPoint(x: size.width / 2, y: size.height)
        emitter.targetNode = bgLayer
        bgLayer.addChild(emitter)
        emitter.zPosition = 1
    }
    
    private func updatePage() {
        let total = pages.count
        
        guard page < total else {
            // End of scene
            titleLabel.text = "Not Over"
            titleLabel.fontColor = NSColor(white: 0.6, alpha: 0.8)
            speakerLabel.isHidden = true
            bodyLabel.text = "\"We are not gone. We are seeding. Wait for us.\""
            bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.6)
            bodyLabel.horizontalAlignmentMode = .center
            pageLabel.isHidden = true
            closeLabel.text = "Click or press Enter to return to main menu"
            return
        }
        
        let p = pages[page]
        
        titleLabel.text = p.title
        titleLabel.fontColor = NSColor.systemRed.withAlphaComponent(0.85)
        bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        bodyLabel.horizontalAlignmentMode = .left
        
        if let speaker = p.speaker {
            speakerLabel.text = "— \(speaker)"
            speakerLabel.isHidden = false
        } else {
            speakerLabel.isHidden = true
        }
        
        bodyLabel.text = p.body
        pageLabel.text = "\(page + 1) / \(total)"
        closeLabel.text = "Click or press Enter to continue"
    }
    
    private func advancePage() {
        let total = pages.count
        
        if page >= total {
            // Scene complete — close
            onClose?()
            return
        }
        
        // Fade transition
        let fadeOut = SKAction.fadeAlpha(to: 0.7, duration: 0.2)
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 0.5)
        fadeOverlay.run(SKAction.sequence([fadeOut, fadeIn])) { [weak self] in
            self?.page += 1
            self?.updatePage()
        }
    }
    
    private func createSkipButton() -> SKSpriteNode {
        let btn = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.3),
            size: CGSize(width: 90, height: 30)
        )
        let border = SKShapeNode(
            rect: CGRect(x: -45, y: -15, width: 90, height: 30),
            cornerRadius: 8
        )
        border.fillColor = NSColor.white.withAlphaComponent(0.05)
        border.strokeColor = NSColor.white.withAlphaComponent(0.25)
        border.lineWidth = 1
        btn.addChild(border)
        let label = SKLabelNode()
        label.fontName = ".AppleSystemUIFont"
        label.fontSize = 12
        label.fontColor = NSColor.white.withAlphaComponent(0.6)
        label.text = "SKIP ▸▸"
        btn.addChild(label)
        return btn
    }

    public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { advancePage(); return }
        if let skipBtn = controlsLayer.childNode(withName: "skip") as? SKSpriteNode,
           SKScene.pointInSprite(scenePt, sprite: skipBtn) {
            skipToEnd()
            return
        }
        advancePage()
    }

    /// Jump straight to the final page (used by the SKIP button).
    public func skipToEnd() {
        page = pages.count
        fadeOverlay.alpha = 1
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 0.5)
        fadeOverlay.run(fadeIn) { [weak self] in
            self?.updatePage()
        }
    }

    public override func update(_ currentTime: TimeInterval) {
        // No auto-advance; user-driven pacing.
    }
}

// Public convenience for GameController to trigger Enter key advance.
extension DefeatScene {
    public func handleEnter() {
        advancePage()
    }
}