import AppKit
import SpriteKit
import StarfallCore
import StarfallInput

/// Key remapping scene.
///
/// Allows the player to change keyboard bindings for both Player 1 and Player 2.
/// Saves to UserDefaults so changes persist across sessions.
@MainActor
public final class KeyBindingsScene: SKScene {
    
    public var onBack: (() -> Void)?
    public var onUIAction: (() -> Void)?
    
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    private let bgLayer = SKNode()
    private let uiLayer = SKNode()
    
    private var bindings: MeleeKeyBindings
    private var waitingForKey: (player: Int, action: String)? = nil
    private var waitingLabel: SKLabelNode?
    
    // Key label nodes for each binding
    private var keyLabels: [String: SKLabelNode] = [:]
    
    public override init(size: CGSize) {
        self.bindings = MeleeKeyBindings()
        super.init(size: size)
        // Load saved bindings after super.init
        self.bindings = loadSavedBindings()
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
        
        // Star twinkle layers
        for layer in 0..<2 {
            let starCount = 80
            let layerNode = SKNode()
            for _ in 0..<starCount {
                let star = SKShapeNode(circleOfRadius: CGFloat(layer == 0 ? 0.5 : 1.0))
                star.fillColor = .white
                star.strokeColor = .clear
                star.alpha = CGFloat(layer == 0 ? 0.2 : 0.35)
                star.position = CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                )
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
        let centerX = size.width / 2
        
        // Title
        let title = SKLabelNode()
        title.fontName = "Helvetica Neue"
        title.fontSize = 36
        title.fontColor = NSColor.white
        title.text = "KEY BINDINGS"
        title.position = CGPoint(x: centerX, y: size.height - 70)
        addChild(title)
        
        let subtitle = SKLabelNode()
        subtitle.fontName = ".AppleSystemUIFont"
        subtitle.fontSize = 14
        subtitle.fontColor = NSColor.gray
        subtitle.text = "Click a key to reassign it. Press ESC to cancel."
        subtitle.position = CGPoint(x: centerX, y: size.height - 110)
        addChild(subtitle)
        
        // P1 Section
        let p1Title = SKLabelNode()
        p1Title.fontName = "Helvetica Neue"
        p1Title.fontSize = 18
        p1Title.fontColor = NSColor.systemGreen
        p1Title.text = "PLAYER 1"
        p1Title.horizontalAlignmentMode = .left
        p1Title.position = CGPoint(x: centerX - 250, y: size.height - 170)
        addChild(p1Title)
        
        // P2 Section
        let p2Title = SKLabelNode()
        p2Title.fontName = "Helvetica Neue"
        p2Title.fontSize = 18
        p2Title.fontColor = NSColor.systemRed
        p2Title.horizontalAlignmentMode = .left
        p2Title.text = "PLAYER 2"
        p2Title.position = CGPoint(x: centerX + 50, y: size.height - 170)
        addChild(p2Title)
        
        // Binding rows
        let p1Bindings: [(key: String, label: String)] = [
            ("thrust", "Thrust"),
            ("rotateLeft", "Turn Left"),
            ("rotateRight", "Turn Right"),
            ("firePrimary", "Fire Primary"),
            ("fireSpecial", "Fire Special"),
        ]
        
        let p2Bindings: [(key: String, label: String)] = [
            ("p2Thrust", "Thrust"),
            ("p2RotateLeft", "Turn Left"),
            ("p2RotateRight", "Turn Right"),
            ("p2FirePrimary", "Fire Primary"),
            ("p2FireSpecial", "Fire Special"),
        ]
        
        let startY: CGFloat = size.height - 210
        let rowSpacing: CGFloat = 38
        
        // P1 bindings
        for (i, binding) in p1Bindings.enumerated() {
            let rowY = startY - CGFloat(i) * rowSpacing
            
            let actionLabel = SKLabelNode()
            actionLabel.fontName = ".AppleSystemUIFont"
            actionLabel.fontSize = 13
            actionLabel.fontColor = NSColor.white.withAlphaComponent(0.8)
            actionLabel.text = binding.label
            actionLabel.horizontalAlignmentMode = .left
            actionLabel.position = CGPoint(x: centerX - 250, y: rowY)
            actionLabel.name = "label_p1_\(binding.key)"
            addChild(actionLabel)
            
            let currentKey = keyCodeLabel(bindings[keyPath: keyPathForKey(binding.key)])
            let keyLabel = SKLabelNode()
            keyLabel.fontName = ".AppleSystemUIFont"
            keyLabel.fontSize = 12
            keyLabel.fontColor = NSColor.systemGreen.withAlphaComponent(0.7)
            keyLabel.text = "[ \(currentKey) ]"
            keyLabel.horizontalAlignmentMode = .left
            keyLabel.position = CGPoint(x: centerX - 250 + 120, y: rowY)
            keyLabel.name = "key_p1_\(binding.key)"
            keyLabels["p1_\(binding.key)"] = keyLabel
            addChild(keyLabel)
        }
        
        // P2 bindings
        for (i, binding) in p2Bindings.enumerated() {
            let rowY = startY - CGFloat(i) * rowSpacing
            
            let actionLabel = SKLabelNode()
            actionLabel.fontName = ".AppleSystemUIFont"
            actionLabel.fontSize = 13
            actionLabel.fontColor = NSColor.white.withAlphaComponent(0.8)
            actionLabel.text = binding.label
            actionLabel.horizontalAlignmentMode = .left
            actionLabel.position = CGPoint(x: centerX + 50, y: rowY)
            actionLabel.name = "label_p2_\(binding.key)"
            addChild(actionLabel)
            
            let currentKey = keyCodeLabel(bindings[keyPath: keyPathForKey(binding.key)])
            let keyLabel = SKLabelNode()
            keyLabel.fontName = ".AppleSystemUIFont"
            keyLabel.fontSize = 12
            keyLabel.fontColor = NSColor.systemRed.withAlphaComponent(0.7)
            keyLabel.text = "[ \(currentKey) ]"
            keyLabel.horizontalAlignmentMode = .left
            keyLabel.position = CGPoint(x: centerX + 50 + 120, y: rowY)
            keyLabel.name = "key_p2_\(binding.key)"
            keyLabels["p2_\(binding.key)"] = keyLabel
            addChild(keyLabel)
        }
        
        // Back button
        let backBtn = createButton(text: "BACK", color: NSColor.systemGray, name: "back")
        backBtn.position = CGPoint(x: 90, y: 60)
        uiLayer.addChild(backBtn)
        
        // Reset button
        let resetBtn = createButton(text: "RESET TO DEFAULTS", color: NSColor.systemOrange, name: "reset")
        resetBtn.position = CGPoint(x: centerX, y: 60)
        uiLayer.addChild(resetBtn)
        
        // Save button
        let saveBtn = createButton(text: "APPLY", color: NSColor.systemGreen, name: "save")
        saveBtn.position = CGPoint(x: size.width - 90, y: 60)
        uiLayer.addChild(saveBtn)
        
        addChild(uiLayer)
    }
    
    /// Maps binding key name to WritableKeyPath on MeleeKeyBindings.
    private func keyPathForKey(_ key: String) -> WritableKeyPath<MeleeKeyBindings, KeyBinding> {
        switch key {
        case "thrust": return \.thrust
        case "rotateLeft": return \.rotateLeft
        case "rotateRight": return \.rotateRight
        case "firePrimary": return \.firePrimary
        case "fireSpecial": return \.fireSpecial
        case "p2Thrust": return \.p2Thrust
        case "p2RotateLeft": return \.p2RotateLeft
        case "p2RotateRight": return \.p2RotateRight
        case "p2FirePrimary": return \.p2FirePrimary
        case "p2FireSpecial": return \.p2FireSpecial
        default: return \.thrust
        }
    }
    
    /// Converts a key code to a human-readable label.
    private func keyCodeLabel(_ key: KeyBinding) -> String {
        switch key {
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .w: return "W"
        case .space: return "Space"
        case .shift: return "Shift"
        case .control: return "Ctrl"
        case .option: return "Opt"
        case .command: return "Cmd"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .period: return "."
        case .slash: return "/"
        case .unknown: return "???"
        }
    }
    
    private func createButton(text: String, color: NSColor, name: String) -> SKSpriteNode {
        let btn = SKSpriteNode(color: NSColor.black.withAlphaComponent(0.3), size: CGSize(width: 140, height: 36))
        btn.name = name
        
        let border = SKShapeNode(
            rect: CGRect(x: -70, y: -18, width: 140, height: 36),
            cornerRadius: 10
        )
        border.fillColor = color.withAlphaComponent(0.15)
        border.strokeColor = color.withAlphaComponent(0.5)
        border.lineWidth = 2
        btn.addChild(border)
        
        let label = SKLabelNode()
        label.fontName = "Helvetica Neue"
        label.fontSize = 13
        label.fontColor = NSColor.white.withAlphaComponent(0.9)
        label.text = text
        btn.addChild(label)
        
        return btn
    }
    
    /// Save bindings to UserDefaults.
    private func saveBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: "starfall_key_bindings")
        }
    }
    
    /// Load bindings from UserDefaults, falling back to defaults.
    private func loadSavedBindings() -> MeleeKeyBindings {
        if let data = UserDefaults.standard.data(forKey: "starfall_key_bindings"),
           let saved = try? JSONDecoder().decode(MeleeKeyBindings.self, from: data) {
            return saved
        }
        return MeleeKeyBindings()
    }
    
    /// Show a "Press a key" overlay.
    private func showWaitingOverlay(forPlayer: Int, action: String) {
        waitingForKey = (forPlayer, action)
        
        let overlay = SKSpriteNode(color: NSColor.black.withAlphaComponent(0.8), size: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 200
        overlay.name = "waiting_overlay"
        addChild(overlay)
        
        waitingLabel = SKLabelNode()
        waitingLabel?.fontName = "Helvetica Neue"
        waitingLabel?.fontSize = 20
        waitingLabel?.fontColor = NSColor.white
        waitingLabel?.text = "Press any key for \(action)"
        waitingLabel?.position = CGPoint(x: 0, y: 20)
        overlay.addChild(waitingLabel!)
        
        let cancelLabel = SKLabelNode()
        cancelLabel.fontName = ".AppleSystemUIFont"
        cancelLabel.fontSize = 13
        cancelLabel.fontColor = NSColor.gray
        cancelLabel.text = "ESC to cancel"
        cancelLabel.position = CGPoint(x: 0, y: -20)
        overlay.addChild(cancelLabel)
    }
    
    /// Hide the waiting overlay.
    private func hideWaitingOverlay() {
        waitingForKey = nil
        let overlay = childNode(withName: "waiting_overlay")
        overlay?.removeFromParent()
        waitingLabel = nil
    }
    
    // MARK: - Input Handling
    
    public override func keyDown(with event: NSEvent) {
        if waitingForKey != nil {
            // Assign the pressed key to the binding
            let keyCode = event.keyCode
            if let key = KeyBinding(rawValue: keyCode) {
                let bindingKey = "p\(waitingForKey!.player)_\(waitingForKey!.action)"
                bindings[keyPath: keyPathForKey(waitingForKey!.action)] = key
                
                // Update the UI label
                keyLabels[bindingKey]?.text = "[ \(keyCodeLabel(key)) ]"
            }
            hideWaitingOverlay()
            return
        }
        
        onKeyEvent?(event.keyCode, true)
    }
    
    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }
        
        // Check if waiting for key — ESC cancels
        if waitingForKey != nil {
            hideWaitingOverlay()
            return
        }
        
        // Check button clicks
        if let backBtn = uiLayer.childNode(withName: "back") as? SKSpriteNode {
            if SKScene.pointInSprite(scenePt, sprite: backBtn) {
                saveBindings()
                onUIAction?()
                onBack?()
                return
            }
        }
        
        if let resetBtn = uiLayer.childNode(withName: "reset") as? SKSpriteNode {
            if SKScene.pointInSprite(scenePt, sprite: resetBtn) {
                onUIAction?()
                showResetConfirm()
                return
            }
        }
        
        if let saveBtn = uiLayer.childNode(withName: "save") as? SKSpriteNode {
            if SKScene.pointInSprite(scenePt, sprite: saveBtn) {
                saveBindings()
                onUIAction?()
                // Brief confirmation
                let hint = SKLabelNode()
                hint.fontName = ".AppleSystemUIFont"
                hint.fontSize = 12
                hint.fontColor = NSColor.systemGreen
                hint.text = "Saved!"
                hint.position = CGPoint(x: size.width - 90, y: 30)
                hint.zPosition = 100
                hint.run(.sequence([
                    .wait(forDuration: 1.0),
                    .removeFromParent()
                ]))
                addChild(hint)
                return
            }
        }
        
        // Check for key label clicks
        for (_, label) in keyLabels {
            // Reconstruct the label node from the scene tree
            if let name = label.name,
               let node = childNode(withName: name) ?? uiLayer.childNode(withName: name) {
                // Check if clicked on this key label
                let labelFrame = CGRect(
                    x: node.position.x - 60,
                    y: node.position.y - 10,
                    width: 120,
                    height: 20
                )
                if labelFrame.contains(scenePt) {
                    onUIAction?()
                    // Parse player and action from the node name
                    let parts = name.split(separator: "_")
                    if parts.count >= 3 {
                        let player = Int(parts[0].dropFirst(3)) ?? 1  // "key_p1_thrust"
                        let action = String(parts[2])
                        showWaitingOverlay(forPlayer: player, action: action)
                    }
                    return
                }
            }
        }
    }
    
    private func showResetConfirm() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults?"
        alert.informativeText = "This will restore the default key bindings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        DispatchQueue.main.async {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.bindings = MeleeKeyBindings()
                self.refreshKeyLabels()
            }
        }
    }
    
    private func refreshKeyLabels() {
        // P1 bindings
        refreshLabel("p1_thrust", forKey: \.thrust)
        refreshLabel("p1_rotateLeft", forKey: \.rotateLeft)
        refreshLabel("p1_rotateRight", forKey: \.rotateRight)
        refreshLabel("p1_firePrimary", forKey: \.firePrimary)
        refreshLabel("p1_fireSpecial", forKey: \.fireSpecial)
        
        // P2 bindings
        refreshLabel("p2_thrust", forKey: \.p2Thrust)
        refreshLabel("p2_rotateLeft", forKey: \.p2RotateLeft)
        refreshLabel("p2_rotateRight", forKey: \.p2RotateRight)
        refreshLabel("p2_firePrimary", forKey: \.p2FirePrimary)
        refreshLabel("p2_fireSpecial", forKey: \.p2FireSpecial)
    }
    
    private func refreshLabel(_ key: String, forKey path: KeyPath<MeleeKeyBindings, KeyBinding>) {
        keyLabels[key]?.text = "[ \(keyCodeLabel(bindings[keyPath: path])) ]"
    }
}
