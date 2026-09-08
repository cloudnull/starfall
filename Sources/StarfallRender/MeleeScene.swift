import AppKit
import SpriteKit
import StarfallCore
import StarfallData
import StarfallMelee

/// SpriteKit scene that renders a melee match.
@MainActor
public final class MeleeScene: SKScene {
    /// Closure called for every keyboard event received by the scene.
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil

    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }

    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    // MARK: - Nodes

    private let bgLayer = SKNode()
    private let planetNode = SKShapeNode()
    private let asteroidLayer = SKNode()
    private let ship1Node = SKNode()
    private let ship2Node = SKNode()
    private let projectileLayer = SKNode()
    private let hudLayer = SKNode()

    // Camera: a parent node for all world-space objects, used for zoom.
    private let cameraNode = SKNode()

    // Particle effects.
    private let particles = ParticleManager(parent: SKNode())

    // HUD bars.
    private let p1ShieldBar = SKShapeNode()
    private let p1CrewBar = SKShapeNode()
    private let p1HeatBar = SKShapeNode()
    private let p1EnergyBar = SKShapeNode()
    private let p2ShieldBar = SKShapeNode()
    private let p2CrewBar = SKShapeNode()
    private let p2HeatBar = SKShapeNode()
    private let p2EnergyBar = SKShapeNode()

    // Shield label.
    private let p1ShieldLabel = SKLabelNode()
    private let p2ShieldLabel = SKLabelNode()
    private let p1HullLabel = SKLabelNode()
    private let p2HullLabel = SKLabelNode()

    // HUD cooldown bars.
    private let p1PrimaryCooldownBar = SKShapeNode()
    private let p1SpecialCooldownBar = SKShapeNode()
    private let p2PrimaryCooldownBar = SKShapeNode()
    private let p2SpecialCooldownBar = SKShapeNode()

    // HUD labels.
    private let timerLabel = SKLabelNode()
    private let p1NameLabel = SKLabelNode()
    private let p2NameLabel = SKLabelNode()
    private let p1EnergyLabel = SKLabelNode()
    private let p2EnergyLabel = SKLabelNode()
    private let p1SpecialLabel = SKLabelNode()
    private let p2SpecialLabel = SKLabelNode()
    private let p1ModeLabel = SKLabelNode()
    private let p2ModeLabel = SKLabelNode()
    private let matchOverLabel = SKLabelNode()
    private let matchReasonLabel = SKLabelNode()
    private let matchOverDim = SKShapeNode()

    // Replay speed label (top-left corner, shown only during replay).
    private let replaySpeedLabel = SKLabelNode()

    // MARK: - Pause overlay

    /// Called when the player selects an option in the pause overlay.
    public var onPauseMenuSelect: ((String) -> Void)? = nil

    private let pauseOverlay = SKNode()
    private let pauseBackground = SKShapeNode()
    private let pauseTitleLabel = SKLabelNode()
    private let pauseResumeLabel = SKLabelNode()
    private let pauseQuitLabel = SKLabelNode()
    private let pauseCursor = SKShapeNode()
    private var pauseMenuIndex: Int = 0 // 0 = Resume, 1 = Quit
    private let pauseMenuItems = ["resume", "quit"]

    // MARK: - Scale

    private let scale: Double
    private var arenaBounds: Rect = Rect(min: Vec2.zero, max: Vec2.zero)
    private var arenaCenter: Vec2 = .zero
    private var matchMode: String = ""
    /// Whether the control legend has already been shown for this match.
    private var legendShown = false
    private let legendLabel = SKLabelNode()

    // Particle effect tracking.
    private var prevShip1Crew: Int = 0
    private var prevShip2Crew: Int = 0
    private var prevProjectileIDs: Set<UInt32> = []
    private var prevShip1SpecialCooldown: Int = 0
    private var prevShip2SpecialCooldown: Int = 0
    // Impact flash timers (frames remaining for each ship).
    private var flash1Timer: Int = 0
    private var flash2Timer: Int = 0

    // MARK: - HUD stored positions

    private var storedLeftX: CGFloat = 0
    private var storedRightX: CGFloat = 0
    private var p1ShieldY: CGFloat = 0
    private var p1HullY: CGFloat = 0
    private var p1EnergyY: CGFloat = 0
    private var p1HeatY: CGFloat = 0
    private var p1PrimaryY: CGFloat = 0
    private var p1SpecialY: CGFloat = 0
    private var p2ShieldY: CGFloat = 0
    private var p2HullY: CGFloat = 0
    private var p2EnergyY: CGFloat = 0
    private var p2HeatY: CGFloat = 0
    private var p2PrimaryY: CGFloat = 0
    private var p2SpecialY: CGFloat = 0

    // MARK: - Init

    public init(arena: ArenaState, size: CGSize) {
        self.arenaBounds = arena.bounds
        self.arenaCenter = Vec2(
            x: (arena.bounds.min.x + arena.bounds.max.x) / 2,
            y: (arena.bounds.min.y + arena.bounds.max.y) / 2
        )

        let arenaWidth = arena.bounds.width
        let arenaHeight = arena.bounds.height
        let margin: Double = 100
        let scaleX = (Double(size.width) - margin) / arenaWidth
        let scaleY = (Double(size.height) - margin) / arenaHeight
        self.scale = min(scaleX, scaleY)

        super.init(size: size)
        backgroundColor = .black
        setupScene(arena: arena)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupScene(arena: ArenaState) {
        bgLayer.zPosition = 0
        addChild(bgLayer)
        generateStars(count: 200)

        // Camera node holds all world-space objects for zoom.
        cameraNode.zPosition = 1
        addChild(cameraNode)

        let planetRadius = CGFloat(arena.planetRadius * scale)
        let planetScreen = worldToScreen(arena.planetPosition)
        planetNode.path = CGPath(ellipseIn: CGRect(
            x: planetScreen.x - planetRadius,
            y: planetScreen.y - planetRadius,
            width: planetRadius * 2,
            height: planetRadius * 2
        ), transform: nil)
        planetNode.fillColor = NSColor.systemYellow
        planetNode.strokeColor = NSColor.orange
        planetNode.lineWidth = 2
        planetNode.zPosition = 1
        cameraNode.addChild(planetNode)

        // Planet glow ring.
        let glowPath = CGPath(ellipseIn: CGRect(
            x: planetScreen.x - planetRadius * 1.5,
            y: planetScreen.y - planetRadius * 1.5,
            width: planetRadius * 3,
            height: planetRadius * 3
        ), transform: nil)
        let glowRing = SKShapeNode(path: glowPath)
        glowRing.fillColor = NSColor.clear
        glowRing.strokeColor = NSColor.orange.withAlphaComponent(0.15)
        glowRing.lineWidth = planetRadius * 0.5
        glowRing.zPosition = 0
        glowRing.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 1.5),
                SKAction.fadeAlpha(to: 0.1, duration: 1.5)
            ])
        ))
        cameraNode.addChild(glowRing)

        asteroidLayer.zPosition = 2
        cameraNode.addChild(asteroidLayer)

        projectileLayer.zPosition = 10
        cameraNode.addChild(projectileLayer)

        ship1Node.zPosition = 20
        cameraNode.addChild(ship1Node)

        ship2Node.zPosition = 20
        cameraNode.addChild(ship2Node)

        // Particle effects layer — between asteroids and projectiles.
        particles.parent.zPosition = 5
        cameraNode.addChild(particles.parent)

        hudLayer.zPosition = 100
        addChild(hudLayer)
        setupHUD()
    }

    // MARK: - Stars

    private var starsArray: [SKShapeNode] = []

    private func generateStars(count: Int) {
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.fillColor = .white
            star.strokeColor = .clear
            let baseAlpha = CGFloat.random(in: 0.3...1.0)
            star.alpha = baseAlpha

            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )

            // Add twinkle effect — slow alpha pulse with random timing.
            let twinkleDuration = Double.random(in: 1.5...4.0)
            let highAlpha = min(1.0, baseAlpha + 0.3)
            star.run(SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: highAlpha, duration: twinkleDuration),
                    SKAction.fadeAlpha(to: baseAlpha, duration: twinkleDuration)
                ])
            ))

            bgLayer.addChild(star)
            starsArray.append(star)
        }
    }

// MARK: - HUD

    private func setupHUD() {
        let hudY: CGFloat = 20
        let barW: CGFloat = 180
        let barH: CGFloat = 10
        let cdH: CGFloat = 3
        let gap: CGFloat = 6
        let labelFont: CGFloat = 10
        let panelPad: CGFloat = 80  // extra horizontal padding between panels
        let labelPad: CGFloat = 8   // gap between bar right edge and value text

        // Timer at top center of screen.
        timerLabel.fontName = "Helvetica Neue"
        timerLabel.fontSize = 22
        timerLabel.fontColor = NSColor.white
        timerLabel.position = CGPoint(x: size.width / 2, y: size.height - 28)
        hudLayer.addChild(timerLabel)

        // --- Left panel (P1) ---
        let leftX: CGFloat = 22
        storedLeftX = leftX
        let top: CGFloat = hudY + 120 - 10
        var curY = top

        // Ship name.
        p1NameLabel.fontName = "Helvetica Neue"
        p1NameLabel.fontSize = 14
        p1NameLabel.text = "Player 1"
        p1NameLabel.fontColor = NSColor.systemGreen
        p1NameLabel.position = CGPoint(x: leftX, y: curY)
        hudLayer.addChild(p1NameLabel)
        curY -= 18

        // Mode label.
        p1ModeLabel.fontName = "Helvetica Neue"
        p1ModeLabel.fontSize = labelFont
        p1ModeLabel.text = "P1"
        p1ModeLabel.fontColor = NSColor.systemGreen.withAlphaComponent(0.7)
        p1ModeLabel.position = CGPoint(x: leftX, y: curY)
        hudLayer.addChild(p1ModeLabel)
        curY -= 14

        // Special ability label.
        p1SpecialLabel.fontName = "Helvetica Neue"
        p1SpecialLabel.fontSize = labelFont
        p1SpecialLabel.text = ""
        p1SpecialLabel.fontColor = NSColor.systemOrange.withAlphaComponent(0.7)
        p1SpecialLabel.position = CGPoint(x: leftX, y: curY)
        hudLayer.addChild(p1SpecialLabel)
        curY -= gap + barH / 2

        // --- Right panel (P2) ---
        let rightX: CGFloat = size.width - 20 - barW - panelPad
        storedRightX = rightX
        curY = top

        p2NameLabel.fontName = "Helvetica Neue"
        p2NameLabel.fontSize = 13
        p2NameLabel.text = "Player 2"
        p2NameLabel.fontColor = NSColor.systemRed
        p2NameLabel.horizontalAlignmentMode = .right
        p2NameLabel.position = CGPoint(x: rightX + barW + panelPad, y: curY)
        hudLayer.addChild(p2NameLabel)
        curY -= 18

        p2ModeLabel.fontName = "Helvetica Neue"
        p2ModeLabel.fontSize = labelFont
        p2ModeLabel.text = "P2"
        p2ModeLabel.fontColor = NSColor.systemRed.withAlphaComponent(0.7)
        p2ModeLabel.horizontalAlignmentMode = .right
        p2ModeLabel.position = CGPoint(x: rightX + barW + panelPad, y: curY)
        hudLayer.addChild(p2ModeLabel)
        curY -= 14

        p2SpecialLabel.fontName = "Helvetica Neue"
        p2SpecialLabel.fontSize = labelFont
        p2SpecialLabel.text = ""
        p2SpecialLabel.fontColor = NSColor.systemOrange.withAlphaComponent(0.7)
        p2SpecialLabel.horizontalAlignmentMode = .right
        p2SpecialLabel.position = CGPoint(x: rightX + barW + panelPad, y: curY)
        hudLayer.addChild(p2SpecialLabel)
        curY -= gap + barH / 2

        // Helper: draw a bar + value label pair.
        // label is placed on the appropriate side of the bar.
        // For P1: label after bar (x = leftX + barW + labelPad).
        // For P2: label before bar (x = rightX - labelPad), right-aligned.
        func addBarAndLabel(_ bar: SKShapeNode, _ label: SKLabelNode, barY: CGFloat, barColor: NSColor, fillColor: Bool, rightSide: Bool) {
            let labelTop = barY + barH / 2
            if fillColor {
                bar.path = CGPath(rect: CGRect(x: rightSide ? rightX : leftX, y: barY, width: barW, height: barH), transform: nil)
            } else {
                bar.path = CGPath(rect: CGRect(x: rightSide ? rightX : leftX, y: barY, width: barW, height: cdH), transform: nil)
            }
            bar.fillColor = barColor
            bar.strokeColor = barColor.withAlphaComponent(0.3)
            bar.lineWidth = 0.5
            let lx = rightSide ? rightX - labelPad : leftX + barW + labelPad
            label.position = CGPoint(x: lx, y: labelTop)
            label.horizontalAlignmentMode = rightSide ? .right : .left
        }

        // --- P1 Shield bar + label.
        addBarAndLabel(p1ShieldBar, p1ShieldLabel, barY: curY, barColor: NSColor.systemCyan, fillColor: true, rightSide: false)
        p1ShieldY = curY
        hudLayer.addChild(p1ShieldBar)
        hudLayer.addChild(p1ShieldLabel)
        curY = curY + barH + gap

        // --- P2 Shield bar + label.
        addBarAndLabel(p2ShieldBar, p2ShieldLabel, barY: curY, barColor: NSColor.systemCyan, fillColor: true, rightSide: true)
        p2ShieldY = curY
        hudLayer.addChild(p2ShieldBar)
        hudLayer.addChild(p2ShieldLabel)
        curY = curY + barH + gap

        // --- P1 Hull bar + label.
        addBarAndLabel(p1CrewBar, p1HullLabel, barY: curY, barColor: NSColor.systemGreen, fillColor: true, rightSide: false)
        p1HullY = curY
        hudLayer.addChild(p1CrewBar)
        hudLayer.addChild(p1HullLabel)
        curY = curY + barH + gap

        // --- P2 Hull bar + label.
        addBarAndLabel(p2CrewBar, p2HullLabel, barY: curY, barColor: NSColor.systemRed, fillColor: true, rightSide: true)
        p2HullY = curY
        hudLayer.addChild(p2CrewBar)
        hudLayer.addChild(p2HullLabel)
        curY = curY + barH + gap

        // --- P1 Energy bar + label.
        addBarAndLabel(p1EnergyBar, p1EnergyLabel, barY: curY, barColor: NSColor.systemBlue, fillColor: true, rightSide: false)
        p1EnergyY = curY
        hudLayer.addChild(p1EnergyBar)
        hudLayer.addChild(p1EnergyLabel)
        curY = curY + barH + gap

        // --- P2 Energy bar + label.
        addBarAndLabel(p2EnergyBar, p2EnergyLabel, barY: curY, barColor: NSColor.systemBlue, fillColor: true, rightSide: true)
        p2EnergyY = curY
        hudLayer.addChild(p2EnergyBar)
        hudLayer.addChild(p2EnergyLabel)
        curY = curY + barH + gap

        // --- P1 Heat bar (thin, no label).
        p1HeatBar.path = CGPath(rect: CGRect(x: leftX, y: curY, width: barW, height: cdH), transform: nil)
        p1HeatBar.fillColor = NSColor.systemOrange.withAlphaComponent(0.7)
        p1HeatBar.strokeColor = .clear
        p1HeatY = curY
        hudLayer.addChild(p1HeatBar)
        curY -= gap + cdH

        // --- P2 Heat bar (thin).
        p2HeatBar.path = CGPath(rect: CGRect(x: rightX, y: curY, width: barW, height: cdH), transform: nil)
        p2HeatBar.fillColor = NSColor.systemOrange.withAlphaComponent(0.7)
        p2HeatBar.strokeColor = .clear
        p2HeatY = curY
        hudLayer.addChild(p2HeatBar)
        curY -= gap + cdH

        // --- P1 Primary cooldown bar.
        p1PrimaryCooldownBar.path = CGPath(rect: CGRect(x: leftX, y: curY, width: barW, height: cdH), transform: nil)
        p1PrimaryCooldownBar.fillColor = NSColor.white.withAlphaComponent(0.4)
        p1PrimaryCooldownBar.strokeColor = .clear
        p1PrimaryY = curY
        hudLayer.addChild(p1PrimaryCooldownBar)
        curY -= gap + cdH

        // --- P2 Primary cooldown bar.
        p2PrimaryCooldownBar.path = CGPath(rect: CGRect(x: rightX, y: curY, width: barW, height: cdH), transform: nil)
        p2PrimaryCooldownBar.fillColor = NSColor.white.withAlphaComponent(0.4)
        p2PrimaryCooldownBar.strokeColor = .clear
        p2PrimaryY = curY
        hudLayer.addChild(p2PrimaryCooldownBar)
        curY -= gap + cdH

        // --- P1 Special cooldown bar.
        p1SpecialCooldownBar.path = CGPath(rect: CGRect(x: leftX, y: curY, width: barW, height: cdH), transform: nil)
        p1SpecialCooldownBar.fillColor = NSColor.systemOrange.withAlphaComponent(0.4)
        p1SpecialCooldownBar.strokeColor = .clear
        p1SpecialY = curY
        hudLayer.addChild(p1SpecialCooldownBar)

        // --- P2 Special cooldown bar.
        p2SpecialCooldownBar.path = CGPath(rect: CGRect(x: rightX, y: curY, width: barW, height: cdH), transform: nil)
        p2SpecialCooldownBar.fillColor = NSColor.systemOrange.withAlphaComponent(0.4)
        p2SpecialCooldownBar.strokeColor = .clear
        p2SpecialY = curY
        hudLayer.addChild(p2SpecialCooldownBar)

        // Match over label.
        matchOverLabel.fontName = "Helvetica Neue"
        matchOverLabel.fontSize = 36
        matchOverLabel.fontColor = NSColor.yellow
        matchOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 12)
        matchOverLabel.alpha = 0
        hudLayer.addChild(matchOverLabel)

        // Reason sub-label (why the match ended) — shown below the result.
        matchReasonLabel.fontName = ".AppleSystemUIFont"
        matchReasonLabel.fontSize = 14
        matchReasonLabel.fontColor = NSColor.white.withAlphaComponent(0.7)
        matchReasonLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 22)
        matchReasonLabel.alpha = 0
        hudLayer.addChild(matchReasonLabel)

        // Dim overlay behind the match-over card for drama and readability.
        matchOverDim.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height), transform: nil)
        matchOverDim.fillColor = NSColor.black.withAlphaComponent(0.55)
        matchOverDim.strokeColor = .clear
        matchOverDim.alpha = 0
        matchOverDim.zPosition = -1  // behind the labels in hudLayer
        hudLayer.addChild(matchOverDim)

        // Control legend — shown briefly at the start of a live match so a new
        // player (or the second player) always knows the keys.
        legendLabel.fontName = ".AppleSystemUIFont"
        legendLabel.fontSize = 13
        legendLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        legendLabel.horizontalAlignmentMode = .center
        legendLabel.position = CGPoint(x: size.width / 2, y: 60)
        legendLabel.alpha = 0
        hudLayer.addChild(legendLabel)

        // Replay speed label.
        replaySpeedLabel.fontName = "Helvetica Neue"
        replaySpeedLabel.fontSize = 14
        replaySpeedLabel.fontColor = NSColor.systemYellow.withAlphaComponent(0.8)
        replaySpeedLabel.text = ""
        replaySpeedLabel.position = CGPoint(x: 16, y: size.height - 16)
        replaySpeedLabel.alpha = 0
        hudLayer.addChild(replaySpeedLabel)

        // Restart hint.
        let restartHint = SKLabelNode()
        restartHint.name = "restartHint"
        restartHint.fontName = "Helvetica Neue"
        restartHint.fontSize = 14
        restartHint.fontColor = NSColor.white.withAlphaComponent(0.8)
        restartHint.text = "Press Enter to return"
        restartHint.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        restartHint.alpha = 0
        hudLayer.addChild(restartHint)

        // Pause overlay.
        pauseOverlay.zPosition = 200
        pauseOverlay.alpha = 0
        hudLayer.addChild(pauseOverlay)
        setupPauseOverlay()
    }

    private func setupPauseOverlay() {
        // Dim background.
        pauseBackground.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height), transform: nil)
        pauseBackground.fillColor = NSColor.black.withAlphaComponent(0.6)
        pauseBackground.strokeColor = .clear
        pauseOverlay.addChild(pauseBackground)

        // Title.
        pauseTitleLabel.fontName = "Helvetica Neue"
        pauseTitleLabel.fontSize = 32
        pauseTitleLabel.fontColor = NSColor.white
        pauseTitleLabel.text = "PAUSED"
        pauseTitleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        pauseOverlay.addChild(pauseTitleLabel)

        // Resume.
        pauseResumeLabel.fontName = "Helvetica Neue"
        pauseResumeLabel.fontSize = 18
        pauseResumeLabel.fontColor = NSColor.white.withAlphaComponent(0.6)
        pauseResumeLabel.text = "  Resume"
        pauseResumeLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        pauseOverlay.addChild(pauseResumeLabel)

        // Quit.
        pauseQuitLabel.fontName = "Helvetica Neue"
        pauseQuitLabel.fontSize = 18
        pauseQuitLabel.fontColor = NSColor.white.withAlphaComponent(0.6)
        pauseQuitLabel.text = "  Quit"
        pauseQuitLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.40)
        pauseOverlay.addChild(pauseQuitLabel)

        // Cursor indicator.
        pauseCursor.path = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 20), transform: nil)
        pauseCursor.fillColor = NSColor.systemYellow
        pauseCursor.strokeColor = .clear
        pauseOverlay.addChild(pauseCursor)
        updatePauseCursor()
    }

    private func updatePauseCursor() {
        let cursorX: CGFloat = size.width / 2 - 40
        if pauseMenuIndex == 0 {
            pauseCursor.position = CGPoint(x: cursorX, y: size.height * 0.45)
            pauseResumeLabel.fontColor = NSColor.white
            pauseQuitLabel.fontColor = NSColor.white.withAlphaComponent(0.6)
        } else {
            pauseCursor.position = CGPoint(x: cursorX, y: size.height * 0.40)
            pauseResumeLabel.fontColor = NSColor.white.withAlphaComponent(0.6)
            pauseQuitLabel.fontColor = NSColor.white
        }
    }

    public func showPauseOverlay() {
        pauseMenuIndex = 0
        pauseOverlay.alpha = 1
        updatePauseCursor()
    }

    public func hidePauseOverlay() {
        pauseOverlay.alpha = 0
    }

    public func pauseMenuUp() {
        pauseMenuIndex = (pauseMenuIndex == 0) ? 1 : 0
        updatePauseCursor()
    }

    public func pauseMenuDown() {
        pauseMenuIndex = (pauseMenuIndex == 1) ? 0 : 1
        updatePauseCursor()
    }

    public func pauseMenuSelect() {
        let action = pauseMenuItems[pauseMenuIndex]
        onPauseMenuSelect?(action)
    }

    // MARK: - Replay Controls

    public func showReplaySpeedLabel(_ text: String) {
        replaySpeedLabel.text = text
        replaySpeedLabel.alpha = 1
    }

    public func hideReplaySpeedLabel() {
        replaySpeedLabel.alpha = 0
    }

    public func updateReplaySpeedLabel(_ text: String) {
        replaySpeedLabel.text = text
    }

    public func hideMatchOverLabel() {
        matchOverLabel.alpha = 0
    }

    // MARK: - Update

    public func update(sim: MeleeSimulation, matchMode: String? = nil) {
        if let mode = matchMode {
            if mode != self.matchMode {
                // The match context changed; allow the legend to show again.
                legendShown = false
            }
            self.matchMode = mode
        }

        // Show the control legend once per live match (not replays, not after end).
        let modeStr = matchMode ?? ""
        if !legendShown && modeStr != "REPLAY" && sim.outcome == nil {
            legendShown = true
            let legend: String
            if modeStr.hasPrefix("vs AI") {
                legend = "You: W thrust · A/D turn · Space fire · Shift special   —   ESC pause"
            } else if modeStr == "2P" {
                legend = "P1: W/A/D + Space/Shift      P2: Arrows + / and ."
            } else {
                legend = "W thrust · A/D turn · Space fire · Shift special   —   ESC pause"
            }
            legendLabel.text = legend
            legendLabel.alpha = 0
            legendLabel.run(.sequence([
                .fadeAlpha(to: 1, duration: 0.3),
                .wait(forDuration: 3.5),
                .fadeAlpha(to: 0, duration: 0.5),
            ]))
        }

        let s1 = sim.ship1
        let s2 = sim.ship2

        // Camera zoom based on ship separation.
        applyCameraZoom(ship1Pos: s1.position, ship2Pos: s2.position)

        // --- Detect ship destruction — fire explosion on death. ---
        let s1Died = prevShip1Crew > 0 && s1.crew <= 0
        let s2Died = prevShip2Crew > 0 && s2.crew <= 0

        if s1Died {
            particles.emitExplosion(position: worldToScreen(s1.position), color: NSColor.systemGreen)
        }
        if s2Died {
            particles.emitExplosion(position: worldToScreen(s2.position), color: NSColor.systemRed)
        }

        // --- Detect ship hits (crew decreased but not dead) — impact flash. ---
        let s1Hit = s1.crew < prevShip1Crew && s1.crew > 0
        let s2Hit = s2.crew < prevShip2Crew && s2.crew > 0

        if s1Hit {
            flash1Timer = 6
            particles.emit(position: worldToScreen(s1.position), count: 10, color: NSColor.white, speed: 60, size: 3, lifetime: 0.2)
        }
        if s2Hit {
            flash2Timer = 6
            particles.emit(position: worldToScreen(s2.position), count: 10, color: NSColor.white, speed: 60, size: 3, lifetime: 0.2)
        }

        // --- Detect special ability activation — fire glow VFX. ---
        let s1SpecialUsed = s1.specialCooldown > 0 && prevShip1SpecialCooldown == 0
        let s2SpecialUsed = s2.specialCooldown > 0 && prevShip2SpecialCooldown == 0

        if s1SpecialUsed {
            ParticleEffects.specialGlow(particles: particles, position: worldToScreen(s1.position), color: NSColor.systemGreen)
        }
        if s2SpecialUsed {
            ParticleEffects.specialGlow(particles: particles, position: worldToScreen(s2.position), color: NSColor.systemRed)
        }

        // --- Thrust flames. ---
        if s1.thrustTimer > 0 && s1.speed > 0 {
            let accent1 = s1.definition.shape.accentColor
            particles.emitThrustDual(
                position: worldToScreen(s1.position),
                facingRadians: -s1.facing.radians,
                coreColor: NSColor(
                    red: accent1.red, green: accent1.green, blue: accent1.blue, alpha: 1.0
                ),
                glowColor: NSColor.systemGreen.withAlphaComponent(0.6)
            )
        }
        if s2.thrustTimer > 0 && s2.speed > 0 {
            let accent2 = s2.definition.shape.accentColor
            particles.emitThrustDual(
                position: worldToScreen(s2.position),
                facingRadians: -s2.facing.radians,
                coreColor: NSColor(
                    red: accent2.red, green: accent2.green, blue: accent2.blue, alpha: 1.0
                ),
                glowColor: NSColor.systemRed.withAlphaComponent(0.6)
            )
        }

        // --- Projectile trails. ---
        let currentProjectileIDs = Set(sim.projectiles.map { $0.id.value })

        // Detect destroyed projectiles and emit impact effects.
        let vanishedProjectiles = prevProjectileIDs.subtracting(currentProjectileIDs)
        for _ in vanishedProjectiles {
            // We don't have the vanished projectile's position, but we can
            // emit a small sparkle near nearby asteroids for visual feedback.
            // (This is a best-effort effect since we don't store vanished positions.)
        }

        for proj in sim.projectiles {
            particles.emitTrail(
                position: worldToScreen(proj.position),
                color: proj.ownerShipID == s1.id ? NSColor.systemGreen : NSColor.systemRed
            )
        }

        // --- Update particles. ---
        particles.update(dt: 1 / 24)

        // --- Decrement flash timers. ---
        if flash1Timer > 0 { flash1Timer -= 1 }
        if flash2Timer > 0 { flash2Timer -= 1 }

        // --- Update ship visuals. ---
        ship1Node.position = worldToScreen(s1.position)
        ship1Node.zRotation = -s1.facing.radians
        drawShip(node: ship1Node, def: s1.definition, state: s1, color: NSColor.systemGreen, flash: flash1Timer > 0)

        ship2Node.position = worldToScreen(s2.position)
        ship2Node.zRotation = -s2.facing.radians
        drawShip(node: ship2Node, def: s2.definition, state: s2, color: NSColor.systemRed, flash: flash2Timer > 0)

        updateProjectiles(sim: sim)
        updateAsteroids(sim: sim)
        updateHUD(sim: sim)

        // --- Store state for next frame. ---
        prevShip1Crew = s1.crew
        prevShip2Crew = s2.crew
        prevProjectileIDs = currentProjectileIDs
        prevShip1SpecialCooldown = s1.specialCooldown
        prevShip2SpecialCooldown = s2.specialCooldown
    }

    // MARK: - Ship Visual

    private func drawShip(node: SKNode, def: ShipDefinition, state: ShipState, color: NSColor, flash: Bool = false) {
        node.removeAllChildren()

        let shipSize: CGFloat = 24  // Larger for SVG texture detail
        let path = shipShapePath(shape: def.shape, size: shipSize)
        let accent = def.shape.accentColor

        // Try to load SVG texture first (authoritative art asset).
        // Fall back to CGPath rendering if SVG is unavailable.
        let textureLoader = SVGTextureLoader.shared
        let svgSize = shipSize * 2
        
        if let texture = textureLoader.texture(for: def.shape, size: svgSize) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: shipSize, height: shipSize)
            sprite.color = flash ? NSColor.white : color.withAlphaComponent(0.85)
            sprite.colorBlendFactor = flash ? 0.8 : 0.3
            sprite.texture?.usesMipmaps = false
            node.addChild(sprite)
        } else {
            // Fallback: hand-coded CGPath silhouette (kept for development).
            let shipShapeNode = SKShapeNode(path: path)
            shipShapeNode.fillColor = flash ? NSColor.white : color.withAlphaComponent(0.85)
            shipShapeNode.strokeColor = NSColor(
                red: accent.red, green: accent.green, blue: accent.blue, alpha: flash ? 1.0 : 0.9
            )
            shipShapeNode.lineWidth = 1.5
            node.addChild(shipShapeNode)
        }

        // Shield bubble with shimmer.
        if state.shield > 0 {
            let shimmer = ParticleEffects.shieldShimmer(radius: shipSize * 1.2)
            node.addChild(shimmer)
        }

        // Cloak.
        node.alpha = state.isCloaked ? 0.3 : 1.0

        // Kamikaze glow.
        if state.isKamikaze {
            let glow = SKShapeNode(circleOfRadius: shipSize * 1.5)
            glow.fillColor = NSColor.orange.withAlphaComponent(0.3)
            glow.strokeColor = NSColor.clear
            node.addChild(glow)
        }

        // Parasite indicator.
        if state.parasiteTimer > 0 {
            let parasite = SKShapeNode(circleOfRadius: 3)
            parasite.fillColor = NSColor.systemPurple
            parasite.strokeColor = NSColor.clear
            parasite.position = CGPoint(x: 0, y: -shipSize * 0.5)
            node.addChild(parasite)
        }

        // Point defense field.
        if state.pointDefenseTimer > 0 {
            let field = SKShapeNode(circleOfRadius: shipSize * 1.5)
            field.fillColor = NSColor.clear
            field.strokeColor = NSColor.systemOrange.withAlphaComponent(0.4)
            field.lineWidth = 1
            node.addChild(field)
        }

        // Retro-pulse slow indicator.
        if state.retroPulseSlowTimer > 0 {
            let slow = SKShapeNode(circleOfRadius: shipSize * 1.1)
            slow.fillColor = NSColor.clear
            slow.strokeColor = NSColor.systemPurple.withAlphaComponent(0.4)
            slow.lineWidth = 2
            node.addChild(slow)
        }

        // Morph/Special form indicator.
        if state.isSpecialForm {
            let form = SKShapeNode(circleOfRadius: shipSize * 1.3)
            form.fillColor = NSColor.clear
            form.strokeColor = NSColor.systemYellow.withAlphaComponent(0.5)
            form.lineWidth = 2
            node.addChild(form)
        }
    }

    // MARK: - Ship Shapes

    /// Returns a CGPath for a specific ship silhouette, sized to `size`.
    /// Coordinates: Y+ = forward (nose up).
    private func shipShapePath(shape: ShipShape, size: CGFloat) -> CGPath {
        let s = size
        let path = CGMutablePath()

        switch shape {
        // -- Kaelen Compact --

        case .broodstone:
            // Large crystalline mothership — wide diamond with crystal spikes.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.4, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.8, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.8, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.4, y: s * 0.6))
            path.closeSubpath()

        case .striker:
            // Aggressive angular fighter — swept-back wings, sharp nose.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.8, y: -s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.8, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.4))
            path.closeSubpath()

        case .shifter:
            // Mmrnmhrm-style — organic blob with asymmetric bulge.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.7, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.5))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.4, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.5))
            path.closeSubpath()

        case .dart:
            // Tiny Arilou-style — small rounded teardrop.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.4, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.1, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.1, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.4, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.2))
            path.closeSubpath()

        case .veil:
            // Syreen-style — sleek, curved with fin-like extensions.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.15, y: s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.3))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.15, y: s * 0.5))
            path.closeSubpath()

        case .runner:
            // Earthling-style — blocky, symmetrical, military look.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.25, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.7, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.15, y: -s * 0.5))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.15, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.7, y: 0))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.25, y: s * 0.6))
            path.closeSubpath()

        case .spark:
            // Shofixti-style — jagged, aggressive, pointed.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.4, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.3))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.4, y: 0))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.3))
            path.closeSubpath()

        // -- Vexari Dominion --

        case .dreadCommand:
            // Ur-Quan-style — wide, menacing, horned.
            path.move(to: CGPoint(x: 0, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.9, y: -s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.7))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.9, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.5))
            path.closeSubpath()

        case .sporepod:
            // Mycon-style — round fungal pod.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.4, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.7, y: s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.5, y: -s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.7, y: s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.4, y: s * 0.7))
            path.closeSubpath()

        case .kesharunner:
            // Spathi-style — bulbous front, tapering rear.
            path.move(to: CGPoint(x: 0, y: s * 0.9))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.4))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.6))
            path.closeSubpath()

        case .warden:
            // Androsynth-style — elegant, symmetrical, with swept wings.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.15, y: s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.4, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.4, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.7, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.3, y: s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.15, y: s * 0.5))
            path.closeSubpath()

        case .harasser:
            // VUX-style — heavy, armored, with turret-like bulge.
            path.move(to: CGPoint(x: 0, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.4, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s * 0.6, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.7, y: -s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.4, y: -s * 0.5))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.4, y: -s * 0.5))
            path.addLine(to: CGPoint(x: s * 0.7, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.4, y: s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.5))
            path.closeSubpath()

        case .reaver:
            // Ilwrath-style — sleek, claw-like, with forward spikes.
            path.move(to: CGPoint(x: 0, y: s))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s * 0.4, y: 0))
            path.addLine(to: CGPoint(x: -s * 0.6, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.2, y: -s * 0.4))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.6, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.4, y: 0))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.4))
            path.closeSubpath()

        case .skirmisher:
            // Umgah-style — bird-like, small, with wing-like protrusions.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.15, y: s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.5, y: s * 0.4))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.6, y: -s * 0.3))
            path.addLine(to: CGPoint(x: -s * 0.15, y: -s * 0.4))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.15, y: -s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.6, y: -s * 0.3))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.15, y: s * 0.3))
            path.closeSubpath()
        }

        return path
    }

    // MARK: - Ship Details

    /// Returns inner detail lines for each ship shape (panel lines, secondary
    /// engine nacelles, structural features). Returns nil for ships that are
    /// simple enough to not need extra detail.
    private func shipDetailPath(shape: ShipShape, size: CGFloat) -> CGPath? {
        let s = size
        let path = CGMutablePath()

        switch shape {
        case .broodstone:
            // Crystal facets — cross lines suggesting crystal structure.
            path.move(to: CGPoint(x: 0, y: s * 0.6))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))
            path.move(to: CGPoint(x: -s * 0.6, y: 0))
            path.addLine(to: CGPoint(x: s * 0.6, y: 0))

        case .striker:
            // Wing sweep lines.
            path.move(to: CGPoint(x: -s * 0.6, y: -s * 0.1))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.3))
            path.move(to: CGPoint(x: s * 0.6, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.3))

        case .shifter:
            // Organic membrane lines — curved suggestion.
            path.move(to: CGPoint(x: 0, y: s * 0.6))
            path.addLine(to: CGPoint(x: -s * 0.3, y: 0))
            path.addLine(to: CGPoint(x: s * 0.2, y: -s * 0.4))

        case .dart:
            return nil // Too small for detail.

        case .veil:
            // Fin lines along the sleek body.
            path.move(to: CGPoint(x: -s * 0.4, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s * 0.3, y: -s * 0.2))
            path.move(to: CGPoint(x: s * 0.4, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.3, y: -s * 0.2))

        case .runner:
            // Blocky panel lines — horizontal and vertical.
            path.move(to: CGPoint(x: -s * 0.6, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.1))
            path.move(to: CGPoint(x: 0, y: s * 0.5))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))

        case .spark:
            // Jagged structural line down center.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.1, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.1, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))

        case .dreadCommand:
            // Horn-to-horn connection and center spine.
            path.move(to: CGPoint(x: -s * 0.6, y: s * 0.7))
            path.addLine(to: CGPoint(x: s * 0.6, y: s * 0.7))
            path.move(to: CGPoint(x: 0, y: s * 0.5))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.3))

        case .sporepod:
            // Fungal ring detail.
            let ring = CGPath(ellipseIn: CGRect(
                x: -s * 0.3, y: -s * 0.1, width: s * 0.6, height: s * 0.6
            ), transform: nil)
            path.addPath(ring)

        case .kesharunner:
            return nil // Simple bulbous shape, detail would clutter.

        case .warden:
            // Elegant center line and wing sweep.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.3))
            path.move(to: CGPoint(x: -s * 0.5, y: 0))
            path.addLine(to: CGPoint(x: s * 0.5, y: 0))

        case .harasser:
            // Turret bulge and armor plate lines.
            path.move(to: CGPoint(x: -s * 0.5, y: s * 0.4))
            path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.4))
            path.move(to: CGPoint(x: -s * 0.5, y: -s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.5, y: -s * 0.1))

        case .reaver:
            // Claw-line down center.
            path.move(to: CGPoint(x: 0, y: s * 0.8))
            path.addLine(to: CGPoint(x: -s * 0.15, y: s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.15, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -s * 0.4))

        case .skirmisher:
            return nil // Small bird-like shape, detail would clutter.
        }

        return path
    }

    // MARK: - Projectiles

    private func updateProjectiles(sim: MeleeSimulation) {
        projectileLayer.removeAllChildren()

        let s1ID = sim.ship1.id

        for proj in sim.projectiles {
            let isP1 = proj.ownerShipID == s1ID
            let (node, trailColor) = projectileNode(for: proj, ownerIsP1: isP1, p1Color: NSColor.systemGreen, p2Color: NSColor.systemRed)
            node.position = worldToScreen(proj.position)
            projectileLayer.addChild(node)

            // Trail particle.
            particles.emitTrail(position: worldToScreen(proj.position), color: trailColor)
        }
    }

    /// Creates a projectile node styled by weapon type.
    /// Returns the node and a trail color.
    private func projectileNode(for proj: Projectile, ownerIsP1: Bool, p1Color: NSColor, p2Color: NSColor) -> (SKNode, NSColor) {
        let baseColor: NSColor = ownerIsP1 ? p1Color : p2Color

        switch proj.weaponType {
        case .laser:
            // Lasers: elongated diamond shape, bright.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 5))
            path.addLine(to: CGPoint(x: -1.5, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -5))
            path.addLine(to: CGPoint(x: 1.5, y: 0))
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.fillColor = baseColor.withAlphaComponent(0.95)
            node.strokeColor = NSColor.white.withAlphaComponent(0.6)
            node.lineWidth = 0.5
            let angle = atan2(proj.velocity.y, proj.velocity.x) + .pi / 2
            node.zRotation = angle
            return (node, baseColor.withAlphaComponent(0.4))

        case .missile, .tracking:
            // Missiles/tracking: slightly larger circle with a small trailing tail.
            let group = SKNode()
            let body = SKShapeNode(circleOfRadius: 3.5)
            body.fillColor = baseColor
            body.strokeColor = NSColor.white.withAlphaComponent(0.5)
            body.lineWidth = 1
            group.addChild(body)

            // Tiny trail dot behind it.
            let trail = SKShapeNode(circleOfRadius: 1.5)
            trail.fillColor = NSColor.orange.withAlphaComponent(0.6)
            trail.strokeColor = .clear
            let trailAngle = atan2(proj.velocity.y, proj.velocity.x)
            trail.position = CGPoint(x: -cos(trailAngle) * 4, y: -sin(trailAngle) * 4)
            group.addChild(trail)

            return (group, NSColor.orange.withAlphaComponent(0.3))

        case .cone:
            // Cone weapons: small triangle.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 4))
            path.addLine(to: CGPoint(x: -3, y: -3))
            path.addLine(to: CGPoint(x: 3, y: -3))
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.fillColor = NSColor.systemYellow.withAlphaComponent(0.8)
            node.strokeColor = baseColor.withAlphaComponent(0.5)
            node.lineWidth = 0.5
            let angle = atan2(proj.velocity.y, proj.velocity.x) + .pi / 2
            node.zRotation = angle
            return (node, NSColor.systemYellow.withAlphaComponent(0.3))

        case .spread:
            // Spread: small crystal shard (diamond).
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 3))
            path.addLine(to: CGPoint(x: -2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -3))
            path.addLine(to: CGPoint(x: 2, y: 0))
            path.closeSubpath()
            let node = SKShapeNode(path: path)
            node.fillColor = NSColor.cyan.withAlphaComponent(0.8)
            node.strokeColor = .clear
            return (node, NSColor.cyan.withAlphaComponent(0.3))

        case .projectile:
            // Standard projectile: circle.
            let node = SKShapeNode(circleOfRadius: 3)
            node.fillColor = baseColor.withAlphaComponent(0.9)
            node.strokeColor = NSColor.white.withAlphaComponent(0.4)
            node.lineWidth = 0.5
            return (node, baseColor.withAlphaComponent(0.3))

        case .contact:
            // Contact: small pulsing ring.
            let node = SKShapeNode(circleOfRadius: 4)
            node.fillColor = .clear
            node.strokeColor = baseColor.withAlphaComponent(0.8)
            node.lineWidth = 1.5
            return (node, baseColor.withAlphaComponent(0.3))
        }
    }

    // MARK: - HUD Update

    private func updateHUD(sim: MeleeSimulation) {
        let s1 = sim.ship1
        let s2 = sim.ship2

        p1NameLabel.text = "\(s1.definition.name) · \(s1.definition.species)"
        p2NameLabel.text = "\(s2.definition.name) · \(s2.definition.species)"

        p1SpecialLabel.text = "W: \(s1.definition.primaryWeapon.name)  S: \(s1.definition.specialAbility.name)"
        p2SpecialLabel.text = "W: \(s2.definition.primaryWeapon.name)  S: \(s2.definition.specialAbility.name)"

        // Mode labels.
        if !matchMode.isEmpty {
            p1ModeLabel.text = "P1"
            p2ModeLabel.text = matchMode
        } else {
            p1ModeLabel.text = "P1"
            p2ModeLabel.text = "P2"
        }

        let barW: CGFloat = 180
        let barH: CGFloat = 10
        let cdH: CGFloat = 3

        // --- P1 shield ---
        let p1ShieldMaxSafe = max(1, s1.shieldMax)
        let p1ShieldFrac = CGFloat(max(0, s1.shield)) / CGFloat(p1ShieldMaxSafe)
        p1ShieldBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1ShieldY,
            width: barW * p1ShieldFrac,
            height: barH
        ), transform: nil)
        p1ShieldLabel.text = "\(s1.shield)/\(s1.shieldMax)"

        // --- P1 hull ---
        let p1HullFrac = CGFloat(max(0, s1.hull)) / CGFloat(s1.definition.startingCrew)
        p1CrewBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1HullY,
            width: barW * p1HullFrac,
            height: barH
        ), transform: nil)
        p1HullLabel.text = "\(s1.hull)/\(s1.definition.startingCrew)"

        // --- P1 heat ---
        let p1HeatFrac = CGFloat(s1.heat) / CGFloat(s1.definition.heatCapacity)
        let p1HeatColor: NSColor = s1.isOverheated ? .systemRed : .systemOrange
        p1HeatBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1HeatY,
            width: barW * max(0, min(1, p1HeatFrac)),
            height: cdH
        ), transform: nil)
        p1HeatBar.fillColor = p1HeatColor.withAlphaComponent(0.7)

        // --- P1 energy ---
        let p1EnergyMaxSafe = max(1, s1.definition.maxEnergy)
        let p1EnergFrac = CGFloat(s1.energy) / CGFloat(p1EnergyMaxSafe)
        p1EnergyBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1EnergyY,
            width: barW * max(0, p1EnergFrac),
            height: barH
        ), transform: nil)
        p1EnergyLabel.text = "\(s1.energy)/\(s1.definition.maxEnergy)"

        // --- P1 cooldowns ---
        let p1PrimaryMax = CGFloat(s1.definition.primaryWeapon.fireWait)
        let p1PrimaryFrac = p1PrimaryMax > 0 ? CGFloat(min(s1.primaryCooldown, s1.definition.primaryWeapon.fireWait)) / p1PrimaryMax : 0
        p1PrimaryCooldownBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1PrimaryY,
            width: barW * (1 - p1PrimaryFrac),
            height: cdH
        ), transform: nil)
        p1PrimaryCooldownBar.alpha = s1.primaryCooldown > 0 ? 1 : 0

        let p1SpecialMax = CGFloat(s1.definition.specialAbility.useWait)
        let p1SpecialFrac = p1SpecialMax > 0 ? CGFloat(min(s1.specialCooldown, s1.definition.specialAbility.useWait)) / p1SpecialMax : 0
        p1SpecialCooldownBar.path = CGPath(rect: CGRect(
            x: storedLeftX, y: p1SpecialY,
            width: barW * (1 - p1SpecialFrac),
            height: cdH
        ), transform: nil)
        p1SpecialCooldownBar.alpha = s1.specialCooldown > 0 ? 1 : 0

        // --- P2 shield ---
        let p2ShieldMaxSafe = max(1, s2.shieldMax)
        let p2ShieldFrac = CGFloat(max(0, s2.shield)) / CGFloat(p2ShieldMaxSafe)
        p2ShieldBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2ShieldY,
            width: barW * p2ShieldFrac,
            height: barH
        ), transform: nil)
        p2ShieldLabel.text = "\(s2.shield)/\(s2.shieldMax)"

        // --- P2 hull ---
        let p2HullFrac = CGFloat(max(0, s2.hull)) / CGFloat(s2.definition.startingCrew)
        p2CrewBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2HullY,
            width: barW * p2HullFrac,
            height: barH
        ), transform: nil)
        p2HullLabel.text = "\(s2.hull)/\(s2.definition.startingCrew)"

        // --- P2 heat ---
        let p2HeatFrac = CGFloat(s2.heat) / CGFloat(s2.definition.heatCapacity)
        let p2HeatColor: NSColor = s2.isOverheated ? .systemRed : .systemOrange
        p2HeatBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2HeatY,
            width: barW * max(0, min(1, p2HeatFrac)),
            height: cdH
        ), transform: nil)
        p2HeatBar.fillColor = p2HeatColor.withAlphaComponent(0.7)

        // --- P2 energy ---
        let p2EnergyMaxSafe = max(1, s2.definition.maxEnergy)
        let p2EnergFrac = CGFloat(s2.energy) / CGFloat(p2EnergyMaxSafe)
        p2EnergyBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2EnergyY,
            width: barW * max(0, p2EnergFrac),
            height: barH
        ), transform: nil)
        p2EnergyLabel.text = "\(s2.energy)/\(s2.definition.maxEnergy)"

        // --- P2 cooldowns ---
        let p2PrimaryMax = CGFloat(s2.definition.primaryWeapon.fireWait)
        let p2PrimaryFrac = p2PrimaryMax > 0 ? CGFloat(min(s2.primaryCooldown, s2.definition.primaryWeapon.fireWait)) / p2PrimaryMax : 0
        p2PrimaryCooldownBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2PrimaryY,
            width: barW * (1 - p2PrimaryFrac),
            height: cdH
        ), transform: nil)
        p2PrimaryCooldownBar.alpha = s2.primaryCooldown > 0 ? 1 : 0

        let p2SpecialMax = CGFloat(s2.definition.specialAbility.useWait)
        let p2SpecialFrac = p2SpecialMax > 0 ? CGFloat(min(s2.specialCooldown, s2.definition.specialAbility.useWait)) / p2SpecialMax : 0
        p2SpecialCooldownBar.path = CGPath(rect: CGRect(
            x: storedRightX, y: p2SpecialY,
            width: barW * (1 - p2SpecialFrac),
            height: cdH
        ), transform: nil)
        p2SpecialCooldownBar.alpha = s2.specialCooldown > 0 ? 1 : 0

        // Timer.
        let seconds = sim.matchTimer / 24
        let min = seconds / 60
        let sec = seconds % 60
        timerLabel.text = String(format: "%02d:%02d", min, sec)

        // Match over — player-perspective result with a dim card and a reason.
        if let outcome = sim.outcome {
            matchOverDim.alpha = 1
            matchOverLabel.alpha = 1
            matchReasonLabel.alpha = 1

            let isReplay = matchMode == "REPLAY"
            if let winnerID = outcome.winnerID {
                let winnerIsP1 = winnerID == s1.id
                if isReplay {
                    let name = winnerIsP1 ? s1.definition.name : s2.definition.name
                    matchOverLabel.text = "\(name) WINS"
                    matchOverLabel.fontColor = NSColor.white
                } else if winnerIsP1 {
                    matchOverLabel.text = "VICTORY"
                    matchOverLabel.fontColor = NSColor.systemYellow
                    matchReasonLabel.text = "\(s1.definition.name) destroyed \(s2.definition.name)"
                } else {
                    matchOverLabel.text = "DEFEAT"
                    matchOverLabel.fontColor = NSColor.systemRed
                    matchReasonLabel.text = "\(s2.definition.name) destroyed \(s1.definition.name)"
                }
            } else {
                matchOverLabel.text = "DRAW"
                matchOverLabel.fontColor = NSColor.white
                matchReasonLabel.text = isReplay ? "" : "Time expired — hull tied"
            }
            self.revealRestartHint(visible: true)
        } else {
            matchOverDim.alpha = 0
            matchOverLabel.alpha = 0
            matchReasonLabel.alpha = 0
            self.revealRestartHint(visible: false)
        }
    }

    /// Show/hide the "Press Enter to return" hint by name (avoids the old
    /// string-scan over every HUD child).
    private func revealRestartHint(visible: Bool) {
        guard let hint = hudLayer.childNode(withName: "restartHint") as? SKLabelNode else { return }
        hint.alpha = visible ? 1 : 0
    }

    // MARK: - Asteroids

    private func updateAsteroids(sim: MeleeSimulation) {
        asteroidLayer.removeAllChildren()

        for ast in sim.asteroids {
            let radius = CGFloat(ast.radius * scale * 0.8)
            let astId = ast.id.value

            // Generate a jagged asteroid shape for visual variety.
            let path = CGMutablePath()
            let segments = 8 + Int(astId % 5)
            var currentAngle: CGFloat = 0
            for i in 0..<segments {
                let angleStep = CGFloat.pi * 2 / CGFloat(segments)
                currentAngle += angleStep
                let jitter = radius * (0.7 + 0.3 * CGFloat(sin(Double(astId) * Double(i) * 2.399)))
                let x = cos(currentAngle) * jitter
                let y = sin(currentAngle) * jitter
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()

            let asteroid = SKShapeNode(path: path)
            asteroid.position = worldToScreen(ast.position)
            let shade: Double = 0.3 + 0.3 * sin(Double(astId) * 1.618)
            asteroid.fillColor = NSColor(calibratedRed: CGFloat(shade), green: CGFloat(shade), blue: CGFloat(shade), alpha: 0.8)
            asteroid.strokeColor = NSColor.darkGray
            asteroid.lineWidth = 1
            asteroidLayer.addChild(asteroid)
        }
    }

    // MARK: - Camera Zoom

    private func applyCameraZoom(ship1Pos: Vec2, ship2Pos: Vec2) {
        // Account for arena wrap when computing separation and midpoint.
        let dx = wrapDelta(ship2Pos.x - ship1Pos.x, bounds: arenaBounds.width)
        let dy = wrapDelta(ship2Pos.y - ship1Pos.y, bounds: arenaBounds.height)
        let separation = Vec2(x: dx, y: dy).length

        // Zoom range: zoom in when ships are close, out when far apart.
        let minSep: Double = 100  // ships very close -> max zoom in
        let maxSep: Double = 600  // ships far apart -> zoom out
        let clampedSep = min(max(separation, minSep), maxSep)
        let t = (clampedSep - minSep) / (maxSep - minSep) // 0 = close, 1 = far

        // Scale range: 1.4x when close, 1.0x when far.
        var zoomFactor = 1.0 + (1.4 - 1.0) * (1.0 - t)

        // Center camera on midpoint (accounting for wrap).
        let midX = ship1Pos.x + dx * 0.5
        let midY = ship1Pos.y + dy * 0.5
        let midOffset = worldToScreen(Vec2(x: midX, y: midY))

        // Clamp zoom so the farthest ship never leaves the viewport. Each ship
        // sits (separation/2)*scale*zoom from the camera center; that must stay
        // within the smaller half-dimension or the enemy goes off-screen.
        let halfViewport = min(size.width, size.height) / 2
        let shipOffsetWorld = (separation / 2) * scale
        if shipOffsetWorld > 0 {
            zoomFactor = min(zoomFactor, halfViewport / shipOffsetWorld)
        }
        let zoom = CGFloat(zoomFactor)

        cameraNode.position = CGPoint(
            x: CGFloat(size.width / 2) - midOffset.x,
            y: CGFloat(size.height / 2) - midOffset.y
        )
        cameraNode.xScale = zoom
        cameraNode.yScale = zoom

        // Star parallax — move stars opposite to camera movement, scaled down.
        bgLayer.position = CGPoint(
            x: midOffset.x * 0.05,
            y: midOffset.y * 0.05
        )
    }

    // MARK: - Coordinate Conversion

    private func worldToScreen(_ pos: Vec2) -> CGPoint {
        let dx = (pos.x - arenaCenter.x) * scale
        let dy = (pos.y - arenaCenter.y) * scale
        return CGPoint(
            x: size.width / 2 + CGFloat(dx),
            y: size.height / 2 - CGFloat(dy)
        )
    }
}