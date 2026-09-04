import AppKit
import SpriteKit
import StarfallCore

/// Cinematic victory scene with species-specific freedom messages,
/// Chorus broadcast, and closing lines from Elara Moss and Jorin Vael.
/// Text auto-advances with a gentle fade between pages.
@MainActor
public final class VictoryScene: SKScene {
    
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
            title: "Victory",
            speaker: nil,
            body: "The command nexus burns. Slave shields over Barrier Worlds collapse. Across the Reach, Bonded species rise up against their captors."
        ),
        Page(
            title: "Freedom",
            speaker: "The Chorus",
            body: "The Chorus — the Vexari Overmind's voice — issues one final broadcast. Not of anger. Something almost like relief."
        ),
        Page(
            title: "The War Is Over",
            speaker: "Ossari Zzrr'tkal",
            body: "\"The resonance shifts. For the first time in millennia, the harmonic of the Reach is not one of subjugation, but of choice. We shall remember.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Vaelen",
            body: "\"The code is fulfilled. Not by the sword alone, but by those who stood when the sky darkened. Honor to the fallen. Honor to you.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Krr-tk",
            body: "\"Click-click-hiss. The form is whole again. No more fracture. The ones we were before are back. The ones we become now are ours to choose.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Paelin",
            body: "\"We blink forward. We never look back. Tell nobody where we came from. Tell nobody where we are going. We will find out on our own.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Sireth",
            body: "\"Our song changes. The old harmonies — the ones that broke enemy minds — are replaced. A new chorus. A chorus of our own making.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Terrani",
            body: "Elara Moss writes: \"We made it home. I keep saying that, and it still doesn't feel real. I think I'll write it again tomorrow, just to be sure.\""
        ),
        Page(
            title: "Freedom",
            speaker: "Xhofi",
            body: "\"Those who ran the Glory Run — we light the way, then we go out. That was always the bargain. But tonight the lights stay on. Tonight we burn for ourselves.\""
        ),
        Page(
            title: "Aftermath",
            speaker: "Jorin Vael",
            body: "Jorin Vael stands at the ruined command nexus. The fires reflect in his eyes. He says, simply: \"Tell them it was worth it.\""
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
        
        // Warm victory glow background
        let bgGradient = SKShapeNode(rectOf: size)
        bgGradient.fillColor = NSColor(
            red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0
        )
        bgGradient.strokeColor = .clear
        bgGradient.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(bgGradient)
        
        // Subtle radial glow at center
        let glow = SKSpriteNode(
            color: NSColor.systemYellow.withAlphaComponent(0.03),
            size: CGSize(width: size.width, height: size.height)
        )
        glow.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(glow)
        
        // Dim overlay for readability
        let overlay = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.4),
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
        titleLabel.fontColor = NSColor.systemYellow.withAlphaComponent(0.95)
        titleLabel.position = CGPoint(x: centerX, y: startY)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.preferredMaxLayoutWidth = maxWidth
        contentLayer.addChild(titleLabel)
        
        // Speaker
        speakerLabel.fontName = ".AppleSystemUIFont"
        speakerLabel.fontSize = 14
        speakerLabel.fontColor = NSColor.systemBlue.withAlphaComponent(0.9)
        speakerLabel.position = CGPoint(x: centerX, y: startY - 38)
        speakerLabel.horizontalAlignmentMode = .center
        contentLayer.addChild(speakerLabel)
        speakerLabel.isHidden = true
        
        // Divider — rect centered at origin, positioned at its center
        let divider = SKShapeNode(rectOf: CGSize(width: maxWidth, height: 1))
        divider.fillColor = .clear
        divider.strokeColor = NSColor.systemYellow.withAlphaComponent(0.3)
        divider.lineWidth = 1
        divider.position = CGPoint(x: centerX, y: startY - 58)
        contentLayer.addChild(divider)
        
        // Body
        bodyLabel.fontName = ".AppleSystemUIFont"
        bodyLabel.fontSize = 15
        bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.92)
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
        
        // Close hint
        closeLabel.fontName = ".AppleSystemUIFont"
        closeLabel.fontSize = 12
        closeLabel.fontColor = NSColor.gray.withAlphaComponent(0.5)
        closeLabel.position = CGPoint(x: centerX, y: 65)
        closeLabel.horizontalAlignmentMode = .center
        controlsLayer.addChild(closeLabel)

        // Skip button — bottom-left, lets the player jump to the end without
        // clicking through every page of the cinematic.
        let skipBtn = createSkipButton()
        skipBtn.position = CGPoint(x: 80, y: 50)
        skipBtn.name = "skip"
        controlsLayer.addChild(skipBtn)

        addChild(controlsLayer)
        
        // Initial fade-in
        fadeOverlay.alpha = 1
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 1.5)
        fadeOverlay.run(fadeIn)
        
        updatePage()
    }
    
    private func updatePage() {
        let total = pages.count
        
        guard page < total else {
            // End of scene
            titleLabel.text = "Victory"
            speakerLabel.isHidden = true
            bodyLabel.text = "The Kaelen Reach is free."
            bodyLabel.fontColor = NSColor.systemYellow.withAlphaComponent(0.9)
            bodyLabel.horizontalAlignmentMode = .center
            pageLabel.isHidden = true
            closeLabel.text = "Click or press Enter to return to main menu"
            return
        }
        
        let p = pages[page]
        
        titleLabel.text = p.title
        titleLabel.fontColor = NSColor.systemYellow.withAlphaComponent(0.95)
        bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.92)
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
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 0.4)
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

    /// Jump straight to the final page (used by the SKIP button and ESC).
    public func skipToEnd() {
        page = pages.count
        fadeOverlay.alpha = 1
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: 0.5)
        fadeOverlay.run(fadeIn) { [weak self] in
            self?.updatePage()
        }
    }

    public override func update(_ currentTime: TimeInterval) {
        // No auto-advance; user-driven pacing for this cinematic.
    }
}

// Public convenience for GameController to trigger Enter key advance.
extension VictoryScene {
    public func handleEnter() {
        advancePage()
    }
}