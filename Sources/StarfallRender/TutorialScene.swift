import AppKit
import SpriteKit
import StarfallCore

/// Tutorial/help scene showing campaign and melee controls.
@MainActor
public final class TutorialScene: SKScene {
    
    public var onBack: (() -> Void)?
    public var onUIAction: (() -> Void)?
    
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }
    
    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private let bgLayer = SKNode()
    private let contentLayer = SKNode()
    private let controlsLayer = SKNode()
    
    private let pageLabel = SKLabelNode()
    private let backBtn = SKSpriteNode(
        color: NSColor.black.withAlphaComponent(0.3),
        size: CGSize(width: 120, height: 36)
    )
    
    private var currentPage: Int = 0
    private var currentSection: Int = 0
    
    // Sections: 0 = Campaign, 1 = Melee, 2 = Combat Tips
    private let sections: [(title: String, lines: [String])]
    
    public override init(size: CGSize) {
        // Campaign controls
        let campaignLines = [
            "CAMPAIGN CONTROLS",
            "",
            "  Left-click system   Move your selected fleet there",
            "  Left-click fleet     Select a fleet for movement",
            "  Right-click        Pan the star map",
            "  Mouse wheel        Zoom in and out",
            "",
            "  When you select a system with your fleet,",
            "  an actions menu appears. Choose to:",
            "  • Colonize life worlds",
            "  • Build mines on mineral worlds",
            "  • Fortify dead worlds",
            "  • Recruit crew at colonies",
            "  • Build ships at starbases",
            "",
            "  Each turn you get 3 actions.",
            "  Capturing enemy systems and building",
            "  infrastructure expands your economy.",
            "",
            "  Destroy the enemy starbase to win."
        ]
        
        // Melee controls
        let meleeLines = [
            "MELEE CONTROLS",
            "",
            "  PLAYER 1:",
            "    W                  Thrust",
            "    A / D              Turn left / right",
            "    Space              Fire primary weapon",
            "    Shift              Fire special ability",
            "",
            "  PLAYER 2 (two-player only):",
            "    Up Arrow           Thrust",
            "    Left / Right       Turn left / right",
            "    /                  Fire primary weapon",
            "    .                  Fire special ability",
            "",
            "  General:",
            "    ESC              Pause / open menu",
            "",
            "  In campaign combat, you control",
            "  your fleet's lead ship in 1v1",
            "  melee. Surviving ships take",
            "  proportional damage."
        ]
        
        // Combat tips
        let tipsLines = [
            "COMBAT TIPS",
            "",
            "  • Shields regenerate when not hit",
            "  • Weapons generate heat — overheat disables them",
            "  • Manage energy between weapons and specials",
            "  • Heavier ships turn slower but hit harder",
            "",
            "  • Tracking weapons adjust aim over time",
            "  • Cone weapons cover wide arcs",
            "  • Missiles can be outrun by fast ships",
            "",
            "  • Use terrain for cover in some arenas",
            "  • Asteroids block shots but can be destroyed",
            "",
            "  • Different ships suit different playstyles:",
            "    - Dart: Fast, fragile, high burst",
            "    - Runner: Balanced, good energy economy",
            "    - Veil: Cloak, strikes from safety",
            "    - Spark: High speed, ramming attacks",
            "",
            "  Press ESC in melee to access the pause menu,",
            "  including graphics and audio settings."
        ]
        
        sections = [(campaignLines[0], campaignLines), (meleeLines[0], meleeLines), (tipsLines[0], tipsLines)]
        
        super.init(size: size)
        backgroundColor = NSColor.black
        setupBackground()
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupBackground() {
        let gradientImage = createGradientImage(
            colors: [
                NSColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1.0).cgColor,
                NSColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1.0).cgColor,
            ],
            size: size
        )
        let bg = SKSpriteNode(texture: SKTexture(image: gradientImage))
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.size = size
        bg.zPosition = -1
        addChild(bg)
        
        for layer in 0..<3 {
            let starCount = [120, 60, 30][layer]
            let layerNode = SKNode()
            for _ in 0..<starCount {
                let star = SKShapeNode(circleOfRadius: CGFloat(layer == 0 ? 0.5 : (layer == 1 ? 0.8 : 1.3)))
                star.fillColor = .white
                star.strokeColor = .clear
                let baseAlpha: CGFloat = CGFloat(layer == 0 ? 0.2 : (layer == 1 ? 0.3 : 0.4))
                let jitter = CGFloat.random(in: -baseAlpha * 0.2...baseAlpha * 0.2)
                star.alpha = baseAlpha + jitter
                star.position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
                let twinkle = Double.random(in: 1.5...4.5)
                star.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: max(0.1, star.alpha + 0.2), duration: twinkle),
                        SKAction.fadeAlpha(to: star.alpha, duration: twinkle)
                    ])
                ))
                layerNode.addChild(star)
            }
            addChild(layerNode)
        }
    }
    
    private func createGradientImage(colors: [CGColor], size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient,
            start: CGPoint(x: size.width / 2, y: 0),
            end: CGPoint(x: size.width / 2, y: size.height),
            options: [])
        image.unlockFocus()
        return image
    }
    
    private func setupUI() {
        contentLayer.zPosition = 10
        addChild(contentLayer)
        
        controlsLayer.zPosition = 100
        addChild(controlsLayer)
        
        let centerX = size.width / 2
        
        // Section title
        let titleLabel = SKLabelNode()
        titleLabel.name = "title_label"
        titleLabel.fontName = "Helvetica Neue"
        titleLabel.fontSize = 28
        titleLabel.fontColor = NSColor.white
        titleLabel.position = CGPoint(x: centerX, y: size.height * 0.75)
        titleLabel.horizontalAlignmentMode = .center
        contentLayer.addChild(titleLabel)
        
        // Content lines
        let contentLabel = SKLabelNode()
        contentLabel.name = "content_label"
        contentLabel.fontName = ".AppleSystemUIFont"
        contentLabel.fontSize = 13
        contentLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        contentLabel.position = CGPoint(x: centerX, y: size.height * 0.55)
        contentLabel.horizontalAlignmentMode = .center
        contentLabel.numberOfLines = 0
        contentLayer.addChild(contentLabel)
        
        // Page indicator
        pageLabel.fontName = "Helvetica Neue"
        pageLabel.fontSize = 11
        pageLabel.fontColor = NSColor.gray
        pageLabel.horizontalAlignmentMode = .center
        pageLabel.position = CGPoint(x: centerX, y: 50)
        contentLayer.addChild(pageLabel)
        
        // Back button
        let border = SKShapeNode(
            rect: CGRect(x: -60, y: -18, width: 120, height: 36),
            cornerRadius: 8
        )
        border.fillColor = NSColor.systemGray.withAlphaComponent(0.15)
        border.strokeColor = NSColor.systemGray.withAlphaComponent(0.5)
        border.lineWidth = 1
        backBtn.addChild(border)
        
        let backLabel = SKLabelNode()
        backLabel.fontName = "Helvetica Neue"
        backLabel.fontSize = 14
        backLabel.fontColor = NSColor.white.withAlphaComponent(0.8)
        backLabel.text = "BACK"
        backLabel.position = CGPoint(x: 0, y: 0)
        backBtn.addChild(backLabel)
        
        backBtn.position = CGPoint(x: centerX, y: size.height * 0.15)
        backBtn.name = "back"
        controlsLayer.addChild(backBtn)
        
        // Navigation hint
        let navLabel = SKLabelNode()
        navLabel.fontName = "Helvetica Neue"
        navLabel.fontSize = 11
        navLabel.fontColor = NSColor.gray.withAlphaComponent(0.5)
        navLabel.text = "Click anywhere to advance"
        navLabel.position = CGPoint(x: centerX, y: 90)
        navLabel.horizontalAlignmentMode = .center
        contentLayer.addChild(navLabel)
        
        updateDisplay()
    }
    
    private func updateDisplay() {
        let section = sections[currentSection]
        let lines = section.lines
        
        if let titleLabel = contentLayer.childNode(withName: "title_label") as? SKLabelNode {
            titleLabel.text = section.title
        }
        
        if let contentLabel = contentLayer.childNode(withName: "content_label") as? SKLabelNode {
            let lineIndex = min(currentPage, lines.count - 1)
            contentLabel.text = lines[lineIndex]
        }
        
        pageLabel.text = "Section \(currentSection + 1) / \(sections.count)  •  Page \(currentPage + 1)"
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }
        
        // Check back button
        if SKScene.pointInSprite(scenePt, sprite: backBtn) {
            onUIAction?()
            onBack?()
            return
        }
        
        onUIAction?()
        
        // Advance page
        let lines = sections[currentSection].lines
        if currentPage + 1 < lines.count {
            currentPage += 1
        } else {
            // Next section
            currentPage = 0
            currentSection = (currentSection + 1) % sections.count
        }
        updateDisplay()
    }
}
