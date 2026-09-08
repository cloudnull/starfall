import AppKit
import SpriteKit
import StarfallCore
import StarfallAudio

/// Settings scene with volume sliders, mute toggle, and fullscreen button.
@MainActor
public final class SettingsScene: SKScene {
    
    public var onBack: (() -> Void)?
    public var onUIAction: (() -> Void)?
    public var onClearSave: (() -> Void)?
    public var onKeyBindings: (() -> Void)?
    public var audio: AudioEngine?
    
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }
    
    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private let bgLayer = SKNode()
    private let uiLayer = SKNode()
    
    private var sfxSlider: SliderControl?
    private var musicSlider: SliderControl?
    private var muteButton: MenuButton?
    private var fullscreenButton: MenuButton?
    
    private var currentSfxVolume: Float = 0.5
    private var currentMusicVolume: Float = 0.3
    private var currentMuted: Bool = false
    /// Armed state for the destructive "Clear Campaign Save" button.
    private var clearSaveArmed: Bool = false
    private var clearSaveButton: MenuButton?
    
    public override init(size: CGSize) {
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
        let centerX = size.width / 2
        
        let title = SKLabelNode()
        title.fontName = "Helvetica Neue"
        title.fontSize = 42
        title.fontColor = NSColor.white
        title.text = "SETTINGS"
        title.position = CGPoint(x: centerX, y: size.height * 0.78)
        addChild(title)
        
        uiLayer.zPosition = 10
        addChild(uiLayer)
        
        // SFX Volume
        let sfxLabel = SKLabelNode()
        sfxLabel.fontName = ".AppleSystemUIFont"
        sfxLabel.fontSize = 14
        sfxLabel.fontColor = NSColor.white.withAlphaComponent(0.8)
        sfxLabel.horizontalAlignmentMode = .left
        sfxLabel.text = "SOUND EFFECTS"
        sfxLabel.position = CGPoint(x: centerX - 160, y: size.height * 0.62)
        uiLayer.addChild(sfxLabel)
        
        sfxSlider = SliderControl(
            position: CGPoint(x: centerX + 20, y: size.height * 0.62),
            width: 220,
            height: 20,
            value: currentSfxVolume,
            label: { [weak self] val in
                self?.sliderChanged(.sfx, value: val)
            }
        )
        uiLayer.addChild(sfxSlider!)
        
        // Music Volume
        let musicLabel = SKLabelNode()
        musicLabel.fontName = ".AppleSystemUIFont"
        musicLabel.fontSize = 14
        musicLabel.fontColor = NSColor.white.withAlphaComponent(0.8)
        musicLabel.horizontalAlignmentMode = .left
        musicLabel.text = "MUSIC"
        musicLabel.position = CGPoint(x: centerX - 160, y: size.height * 0.50)
        uiLayer.addChild(musicLabel)
        
        musicSlider = SliderControl(
            position: CGPoint(x: centerX + 20, y: size.height * 0.50),
            width: 220,
            height: 20,
            value: currentMusicVolume,
            label: { [weak self] val in
                self?.sliderChanged(.music, value: val)
            }
        )
        uiLayer.addChild(musicSlider!)
        
        // Mute toggle
        muteButton = MenuButton(
            text: "Mute Audio",
            width: 160,
            height: 42,
            color: NSColor.systemOrange
        )
        muteButton?.position = CGPoint(x: centerX - 120, y: size.height * 0.35)
        muteButton?.name = "mute"
        uiLayer.addChild(muteButton!)
        
        // Fullscreen toggle
        fullscreenButton = MenuButton(
            text: "Toggle Fullscreen",
            width: 160,
            height: 42,
            color: NSColor.systemBlue
        )
        fullscreenButton?.position = CGPoint(x: centerX + 120, y: size.height * 0.35)
        fullscreenButton?.name = "fullscreen"
        uiLayer.addChild(fullscreenButton!)
        
        // Reset campaign save button (two-step confirm to avoid accidental wipe).
        let resetBtn = MenuButton(
            text: "Clear Campaign Save",
            width: 180,
            height: 42,
            color: NSColor.systemRed
        )
        resetBtn.position = CGPoint(x: centerX - 120, y: size.height * 0.20)
        resetBtn.name = "reset_save"
        clearSaveButton = resetBtn
        uiLayer.addChild(resetBtn)
        
        // Key Bindings button
        let keyBindingsBtn = MenuButton(
            text: "Key Bindings",
            width: 180,
            height: 42,
            color: NSColor.systemTeal
        )
        keyBindingsBtn.position = CGPoint(x: centerX + 120, y: size.height * 0.20)
        keyBindingsBtn.name = "key_bindings"
        uiLayer.addChild(keyBindingsBtn)
        
        // Control reference labels
        let controlsTitle = SKLabelNode()
        controlsTitle.fontName = "Helvetica Neue"
        controlsTitle.fontSize = 20
        controlsTitle.fontColor = NSColor.white.withAlphaComponent(0.8)
        controlsTitle.text = "CONTROLS"
        controlsTitle.position = CGPoint(x: centerX, y: size.height * 0.23)
        controlsTitle.horizontalAlignmentMode = .center
        uiLayer.addChild(controlsTitle)
        
        let controlsText = SKLabelNode()
        controlsText.fontName = ".AppleSystemUIFont"
        controlsText.fontSize = 12
        controlsText.fontColor = NSColor.gray.withAlphaComponent(0.7)
        controlsText.text = "P1: WASD Move  |  Space Fire  |  Shift Special\nP2: Arrow Keys Move  |  / Fire  |  . Special\nESC: Pause/Menu  |  Enter: End Turn"
        controlsText.position = CGPoint(x: centerX, y: size.height * 0.10)
        controlsText.horizontalAlignmentMode = .center
        controlsText.numberOfLines = 0
        uiLayer.addChild(controlsText)
        
        // Back button — anchored to the left, clear of the sliders and
        // toggle buttons, so it never overlaps another control.
        let backBtn = MenuButton(
            text: "BACK",
            width: 140,
            height: 42,
            color: NSColor.systemGray
        )
        backBtn.position = CGPoint(x: 90, y: 70)
        backBtn.name = "back"
        uiLayer.addChild(backBtn)

        updateMuteButton()
        updateClearSaveButton()
    }
    
    enum SliderType { case sfx, music }
    
    private func sliderChanged(_ type: SliderType, value: Float) {
        switch type {
        case .sfx:
            currentSfxVolume = value
            audio?.sfxVolume = value
        case .music:
            currentMusicVolume = value
            audio?.musicVolume = value
        }
    }
    
    private func updateMuteButton() {
        currentMuted = audio?.isMuted ?? false
        let title = currentMuted ? "Unmute Audio" : "Mute Audio"
        if let lbl = muteButton?.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
            lbl.text = title
        }
    }

    private func updateClearSaveButton() {
        guard let btn = clearSaveButton else { return }
        let title = clearSaveArmed ? "CONFIRM DELETE?" : "Clear Campaign Save"
        if let lbl = btn.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
            lbl.text = title
        }
    }
    
    public func applySettings(to audio: AudioEngine) {
        self.audio = audio
        self.currentSfxVolume = audio.sfxVolume
        self.currentMusicVolume = audio.musicVolume
        sfxSlider?.setValue(audio.sfxVolume)
        musicSlider?.setValue(audio.musicVolume)
        updateMuteButton()
    }
    
    public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }
        
        // Check slider clicks
        if let slider = sfxSlider, slider.hitTest(scenePt) {
            return
        }
        if let slider = musicSlider, slider.hitTest(scenePt) {
            return
        }
        
        // Check buttons
        for child in uiLayer.children {
            guard let btn = child as? MenuButton,
                  let name = btn.name else { continue }
            if SKScene.pointInSprite(scenePt, sprite: btn) {
                onUIAction?()
                switch name {
                case "back":
                    onBack?()
                case "mute":
                    audio?.isMuted.toggle()
                    updateMuteButton()
                case "fullscreen":
                    toggleFullscreen()
                case "key_bindings":
                    onUIAction?()
                    onKeyBindings?()
                case "reset_save":
                    // Two-step: first click arms the confirm, second deletes.
                    if clearSaveArmed {
                        clearSaveArmed = false
                        onClearSave?()
                        // Show a brief "Cleared" confirmation, then reset label.
                        if let lbl = btn.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode {
                            lbl.text = "Save Cleared"
                        }
                        run(SKAction.wait(forDuration: 1.2)) { [weak self] in
                            self?.updateClearSaveButton()
                        }
                    } else {
                        clearSaveArmed = true
                        updateClearSaveButton()
                    }
                default:
                    break
                }
                return
            }
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }
        sfxSlider?.onDrag(scenePt)
        musicSlider?.onDrag(scenePt)
    }
    
    public override func mouseUp(with event: NSEvent) {
        sfxSlider?.endDrag()
        musicSlider?.endDrag()
    }
    
    private func toggleFullscreen() {
        guard let window = NSApp.mainWindow else { return }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        } else {
            window.toggleFullScreen(nil)
        }
    }
}

// MARK: - Slider Control

@MainActor
public final class SliderControl: SKNode {
    public let track: SKShapeNode
    public let thumb: SKShapeNode
    public let valueLabel: SKLabelNode
    
    public var value: CGFloat = 0.5
    private var isDragging = false
    private let trackRect: CGRect
    private let onChange: (Float) -> Void
    
    public init(position: CGPoint, width: CGFloat, height: CGFloat, value: Float, label: @escaping (Float) -> Void) {
        self.trackRect = CGRect(x: -width/2, y: -height/2, width: width, height: height)
        self.value = CGFloat(value)
        self.onChange = label
        
        self.track = SKShapeNode(rect: trackRect, cornerRadius: height / 2)
        self.track.fillColor = NSColor.black.withAlphaComponent(0.4)
        self.track.strokeColor = NSColor.white.withAlphaComponent(0.2)
        self.track.lineWidth = 1
        
        self.thumb = SKShapeNode(circleOfRadius: height)
        self.thumb.fillColor = NSColor.systemBlue
        self.thumb.strokeColor = NSColor.white.withAlphaComponent(0.4)
        self.thumb.lineWidth = 1
        
        self.valueLabel = SKLabelNode()
        self.valueLabel.fontName = ".AppleSystemUIFont"
        self.valueLabel.fontSize = 12
        self.valueLabel.fontColor = NSColor.gray
        self.valueLabel.position = CGPoint(x: width/2 + 12, y: 0)
        self.valueLabel.horizontalAlignmentMode = .left
        self.valueLabel.text = String(format: "%.0f%%", value * 100)
        
        super.init()
        
        self.addChild(track)
        self.addChild(thumb)
        self.addChild(valueLabel)
        self.position = position
        self.isUserInteractionEnabled = true
        updateThumbPosition()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }
    
    public func setValue(_ newValue: Float) {
        value = CGFloat(newValue)
        updateThumbPosition()
    }
    
    private func updateThumbPosition() {
        let clamped = max(0, min(1, value))
        let x = trackRect.minX + clamped * trackRect.width
        thumb.position = CGPoint(x: x, y: 0)
        valueLabel.text = String(format: "%.0f%%", Float(clamped) * 100)
    }
    
    public func hitTest(_ point: CGPoint) -> Bool {
        guard let parent = parent else { return false }
        let local = convert(point, from: parent)
        return trackRect.insetBy(dx: -10, dy: -10).contains(local)
    }
    
    public func onDrag(_ point: CGPoint) {
        guard let parent = parent else { return }
        let local = convert(point, from: parent)
        let relativeX = (local.x - trackRect.minX) / trackRect.width
        let clamped = max(0, min(1, relativeX))
        value = clamped
        updateThumbPosition()
        onChange(Float(clamped))
    }
    
    public func endDrag() {
        isDragging = false
    }
}

// MARK: - Menu Button Helper

@MainActor
public final class MenuButton: SKSpriteNode {
    public init(text: String, width: CGFloat, height: CGFloat, color: NSColor) {
        super.init(texture: nil, color: NSColor.black.withAlphaComponent(0.3), size: CGSize(width: width, height: height))
        
        let border = SKShapeNode(
            rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerRadius: 12
        )
        border.fillColor = color.withAlphaComponent(0.15)
        border.strokeColor = color.withAlphaComponent(0.5)
        border.lineWidth = 2
        addChild(border)
        
        let label = SKLabelNode()
        label.fontName = "Helvetica Neue"
        label.fontSize = 16
        label.fontColor = NSColor.white.withAlphaComponent(0.9)
        label.text = text
        label.position = CGPoint(x: 0, y: 4)
        addChild(label)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }
}
