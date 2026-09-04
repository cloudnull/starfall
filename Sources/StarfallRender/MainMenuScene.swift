import AppKit
import SpriteKit
import StarfallCore
import StarfallData

/// Main menu scene with buttons for Melee and Campaign modes.
@MainActor
public final class MainMenuScene: SKScene {
    
    public var onSelectMelee: (() -> Void)?
    public var onSelectCampaign: (() -> Void)?
    public var onNewCampaign: (() -> Void)?
    public var onSettings: (() -> Void)?
    public var onTutorial: (() -> Void)?
    public var onUIAction: (() -> Void)?
    
    /// Set to true when a saved campaign exists (affects button label).
    public var hasSavedCampaign: Bool = false {
        didSet {
            updateCampaignButton()
        }
    }
    
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil

    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }

    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private let buttonLayer = SKNode()
    private let bgLayer = SKNode()

    public override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = NSColor.black
        setupBackground()
        setupUI()
    }

    private func setupBackground() {
        // Deep space gradient
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

        // Star layers
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
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        let centerX = size.width / 2
        
        // Title.
        let title = SKLabelNode()
        title.fontName = "Helvetica Neue"
        title.fontSize = 48
        title.fontColor = NSColor.white
        title.text = "STARFALL"
        title.position = CGPoint(x: centerX, y: size.height * 0.75)
        addChild(title)
        
        // Subtitle.
        let subtitle = SKLabelNode()
        subtitle.fontName = "Helvetica Neue"
        subtitle.fontSize = 16
        subtitle.fontColor = NSColor.gray
        subtitle.text = "The Kaelen Compact vs The Vexari Dominion"
        subtitle.position = CGPoint(x: centerX, y: size.height * 0.68)
        addChild(subtitle)
        
        // Buttons.
        buttonLayer.zPosition = 10
        addChild(buttonLayer)
        
        let buttonW: CGFloat = 240
        let buttonH: CGFloat = 50
        
        // Melee button.
        let meleeBtn = createMenuButton(
            text: "MELEE COMBAT",
            subtitle: "Free-for-all ship battles",
            width: buttonW,
            height: buttonH,
            color: NSColor.systemGreen,
            name: "melee"
        )
        meleeBtn.position = CGPoint(x: centerX, y: size.height * 0.5)
        buttonLayer.addChild(meleeBtn)
        
        // Campaign button — relabels to CONTINUE when a save exists.
        let campaignBtn = createMenuButton(
            text: "CAMPAIGN",
            subtitle: "Start a new campaign",
            width: buttonW,
            height: buttonH,
            color: NSColor.systemBlue,
            name: "campaign"
        )
        campaignBtn.position = CGPoint(x: centerX, y: size.height * 0.37)
        buttonLayer.addChild(campaignBtn)

        // New Campaign button — only meaningful when a save exists.
        let newCampaignBtn = createMenuButton(
            text: "NEW CAMPAIGN",
            subtitle: "Discard save, start fresh",
            width: buttonW,
            height: buttonH,
            color: NSColor.systemTeal,
            name: "new_campaign"
        )
        newCampaignBtn.position = CGPoint(x: centerX, y: size.height * 0.29)
        newCampaignBtn.isHidden = true  // Shown only when a save exists.
        buttonLayer.addChild(newCampaignBtn)

        // Tutorial button.
        let tutorialBtn = createMenuButton(
            text: "TUTORIAL",
            subtitle: "Controls & combat tips",
            width: buttonW,
            height: buttonH,
            color: NSColor.systemPurple,
            name: "tutorial"
        )
        tutorialBtn.position = CGPoint(x: centerX, y: size.height * 0.19)
        buttonLayer.addChild(tutorialBtn)
        
        // Credits.
        let credits = SKLabelNode()
        credits.fontName = "Helvetica Neue"
        credits.fontSize = 10
        credits.fontColor = NSColor.darkGray
        credits.text = "Inspired by Star Control (1990). All names and assets original."
        credits.position = CGPoint(x: centerX, y: 30)
        addChild(credits)
        
        // Settings button — labeled so it's discoverable (a blank corner box
        // was invisible to players).
        let settingsBtn = createIconButton(
            text: "SETTINGS",
            subtitle: "",
            symbol: "gearshape",
            width: 110,
            height: 36,
            name: "settings"
        )
        settingsBtn.position = CGPoint(x: size.width - 90, y: size.height - 40)
        buttonLayer.addChild(settingsBtn)
    }
    
    private func createMenuButton(
        text: String,
        subtitle: String,
        width: CGFloat,
        height: CGFloat,
        color: NSColor,
        name: String
    ) -> SKSpriteNode {
        let btn = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.3),
            size: CGSize(width: width, height: height)
        )
        btn.name = name

        // Main border
        let border = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerRadius: 14
        )
        border.fillColor = color.withAlphaComponent(0.15)
        border.strokeColor = color.withAlphaComponent(0.5)
        border.lineWidth = 2
        btn.addChild(border)

        // Outer glow
        let glowRect = CGRect(
            x: -width / 2 - 3, y: -height / 2 - 3,
            width: width + 6, height: height + 6
        )
        let glow = SKShapeNode(rect: glowRect, cornerRadius: 16)
        glow.fillColor = .clear
        glow.strokeColor = color.withAlphaComponent(0.15)
        glow.lineWidth = 8
        btn.addChild(glow)

        let label = SKLabelNode()
        label.fontName = "Helvetica Neue"
        label.fontSize = 18
        label.fontColor = NSColor.white.withAlphaComponent(0.9)
        label.text = text
        label.position = CGPoint(x: 0, y: 8)
        btn.addChild(label)

        let sub = SKLabelNode()
        sub.fontName = ".AppleSystemUIFont"
        sub.fontSize = 11
        sub.fontColor = color.withAlphaComponent(0.7)
        sub.text = subtitle
        sub.position = CGPoint(x: 0, y: -14)
        btn.addChild(sub)

        // Subtle hover pulse
        btn.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.scale(to: 1.02, duration: 2.5),
                SKAction.scale(to: 1.0, duration: 2.5)
            ])
        ))

        return btn
    }
    
    private func createIconButton(
        text: String = "",
        subtitle: String = "",
        symbol: String,
        width: CGFloat,
        height: CGFloat,
        name: String
    ) -> SKSpriteNode {
        let btn = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.3),
            size: CGSize(width: width, height: height)
        )
        btn.name = name
        
        let border = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerRadius: 10
        )
        border.fillColor = NSColor.white.withAlphaComponent(0.05)
        border.strokeColor = NSColor.white.withAlphaComponent(0.2)
        border.lineWidth = 1
        btn.addChild(border)
        
        let label = SKLabelNode()
        label.fontName = ".AppleSystemUIFont"
        label.fontSize = 16
        label.fontColor = NSColor.white.withAlphaComponent(0.7)
        label.text = text
        label.position = CGPoint(x: 0, y: 2)
        btn.addChild(label)
        
        return btn
    }
    
    private func updateCampaignButton() {
        guard let campaignBtn = buttonLayer.childNode(withName: "campaign") as? SKSpriteNode,
              let label = campaignBtn.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode else { return }
        if hasSavedCampaign {
            label.text = "CONTINUE"
            if campaignBtn.children.count > 1, let sub = campaignBtn.children[1] as? SKLabelNode {
                sub.text = "Resume saved campaign"
            }
        } else {
            label.text = "CAMPAIGN"
            if campaignBtn.children.count > 1, let sub = campaignBtn.children[1] as? SKLabelNode {
                sub.text = "Start a new campaign"
            }
        }
        // Show/hide the "New Campaign" (discard-save) button accordingly.
        if let newBtn = buttonLayer.childNode(withName: "new_campaign") as? SKSpriteNode {
            newBtn.isHidden = !hasSavedCampaign
        }
    }
    
    private func highlightButton(_ btn: SKSpriteNode) {
        // Change border color to white on hover
        if let border = btn.children.first(where: { $0 is SKShapeNode }) as? SKShapeNode {
            border.strokeColor = NSColor.white.withAlphaComponent(0.7)
        }
    }
    
    private func unhighlightButton(_ btn: SKSpriteNode) {
        if let border = btn.children.first(where: { $0 is SKShapeNode }) as? SKShapeNode {
            // Restore based on which button it is
            let name = btn.name ?? ""
            let color: NSColor
            switch name {
            case "melee": color = NSColor.systemGreen
            case "campaign": color = NSColor.systemBlue
            case "new_campaign": color = NSColor.systemTeal
            case "tutorial": color = NSColor.systemPurple
            case "settings": color = NSColor.systemOrange
            default: color = NSColor.white
            }
            border.strokeColor = color.withAlphaComponent(0.5)
        }
    }
    
    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        guard let scenePt = self.convertMouseLocation(event) else { return }
        
        let buttonNames = ["melee", "campaign", "new_campaign", "tutorial", "settings"]
        for name in buttonNames {
            if let btn = buttonLayer.childNode(withName: name) as? SKSpriteNode {
                if SKScene.pointInSprite(scenePt, sprite: btn) {
                    highlightButton(btn)
                } else {
                    unhighlightButton(btn)
                }
            }
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }
        
        let meleeBtn = buttonLayer.childNode(withName: "melee") as? SKSpriteNode
        let campBtn = buttonLayer.childNode(withName: "campaign") as? SKSpriteNode
        let newCampaignBtn = buttonLayer.childNode(withName: "new_campaign") as? SKSpriteNode
        let tutorialBtn = buttonLayer.childNode(withName: "tutorial") as? SKSpriteNode
        let settingsBtn = buttonLayer.childNode(withName: "settings") as? SKSpriteNode
        
        if let btn = settingsBtn, SKScene.pointInSprite(scenePt, sprite: btn) {
            onSettings?()
            onUIAction?()
            return
        }
        
        if let btn = tutorialBtn, SKScene.pointInSprite(scenePt, sprite: btn) {
            onTutorial?()
            onUIAction?()
            return
        }
        
        if let btn = newCampaignBtn, SKScene.pointInSprite(scenePt, sprite: btn) {
            onNewCampaign?()
            onUIAction?()
            return
        }
        
        if let btn = meleeBtn, SKScene.pointInSprite(scenePt, sprite: btn) {
            onSelectMelee?()
            onUIAction?()
            return
        }
        
        if let btn = campBtn, SKScene.pointInSprite(scenePt, sprite: btn) {
            onSelectCampaign?()
            onUIAction?()
            return
        }
    }
}