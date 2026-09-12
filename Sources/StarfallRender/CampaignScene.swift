import AppKit
import SpriteKit
import StarfallCore
import StarfallCampaign
import StarfallData

/// SpriteKit scene for the campaign star map.
///
/// Renders star systems as nodes, connections as lines, and fleets as markers.
/// Supports clicking systems to move fleets and perform actions, with
/// pinch-to-zoom and drag-to-pan navigation.
@MainActor
public final class CampaignScene: SKScene {

    /// Called when the player takes an action. Returns the action result message.
    public var onAction: ((CampaignAction) -> String?)?

    /// Called when the player ends their turn.
    public var onEndTurn: (() -> Void)?

    /// Called when combat is triggered and the game should drop into melee.
    public var onCombatTriggered: (() -> Bool)?

    /// Called when the player presses ESC and chooses "Quit to Menu".
    public var onCampaignQuit: (() -> Void)?
    
    /// Called when the player chooses "Save & Quit".
    public var onSaveAndQuit: (() -> Void)?

    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    public override func keyDown(with event: NSEvent) {
        // Escape must work immediately (and not re-fire while held). Handle it
        // here on the edge rather than in the game-loop tick, which made the
        // first press get swallowed and only worked on a second press.
        if event.keyCode == 53, !event.isARepeat {
            handleEscape()
            return
        }
        onKeyEvent?(event.keyCode, true)
    }

    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }

    private let sim: CampaignSimulation

    // Layers — worldLayer is the pan/zoom container for everything except HUD.
    private let worldLayer = SKNode()
    private let bgLayer = SKNode()      // deep space background + stars
    private let nebulaLayer = SKNode()  // colored nebulae
    private let connectionLayer = SKNode()
    private let systemLayer = SKNode()
    private let fleetLayer = SKNode()
    private let indicatorLayer = SKNode()
    private let hudLayer = SKNode()

    // Pan/zoom state
    private var currentScale: CGFloat = 1.0
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 2.0
    private var panOffset: CGPoint = .zero
    private var isPanning = false
    private var lastPanPoint: CGPoint = .zero
    private var panStartPoint: CGPoint = .zero

    // Map coordinate state (computed lazily).
    private var cachedMapScale: CGFloat = 1.0

    // Fog of war cache — updated each renderMap()
    private var visibleSet: Set<EntityID> = []
    private var currentlyVisibleSet: Set<EntityID> = []

    // HUD labels.
    private let turnLabel = SKLabelNode()
    private let factionLabel = SKLabelNode()
    private let actionsLabel = SKLabelNode()
    private let resourcesLabel = SKLabelNode()
    private let seedLabel = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let tooltipLabel = SKLabelNode()

    // Action button — modern macOS control style.
    private let actionPanel = SKNode()
    private let endTurnButton = SKNode()
    private let endTurnLabel = SKLabelNode()

    // Actions menu (contextual, appears when a system with your fleet is selected)
    private let actionsMenu = SKNode()
    private var actionButtons: [(node: SKNode, action: CampaignAction, label: String)] = []
    private var buildShipButtons: [SKNode] = []
    private var buildShipIndices: [Int] = []
    private var isBuildShipMenuOpen: Bool = false

    // Selected system tracking.
    private var selectedSystemID: EntityID?
    private var selectedFleetID: EntityID?

    private let mapMargin: Double = 80

    // Pause/ESC overlay
    private let pauseOverlay = SKNode()
    private var isPauseVisible = false

    public init(simulation: CampaignSimulation, size: CGSize) {
        self.sim = simulation
        super.init(size: size)
        backgroundColor = NSColor.black
        setupScene()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupScene() {
        // Fixed background — not panned or zoomed
        bgLayer.zPosition = -1
        addChild(bgLayer)
        generateGradientBackground()
        generateStarLayers()
        generateNebulae()

        // World layer holds everything that pans/zooms
        worldLayer.zPosition = 0
        addChild(worldLayer)

        // Connections
        connectionLayer.zPosition = 1
        worldLayer.addChild(connectionLayer)

        // Systems
        systemLayer.zPosition = 10
        worldLayer.addChild(systemLayer)

        // Fleets
        fleetLayer.zPosition = 20
        worldLayer.addChild(fleetLayer)

        // Move indicators
        indicatorLayer.zPosition = 15
        worldLayer.addChild(indicatorLayer)

        // HUD (always on top, never panned/zoomed)
        hudLayer.zPosition = 100
        addChild(hudLayer)
        setupHUD()

        renderMap()
    }

    // MARK: - Background

    private func generateGradientBackground() {
        // Deep space gradient: dark blue to black
        let gradientNode = SKNode()
        let rect = CGRect(x: -size.width, y: -size.height, width: size.width * 2, height: size.height * 2)

        let colors: [CGColor] = [
            NSColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1.0).cgColor,
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor,
        ]

        // Use a gradient sprite
        let gradientImage = createGradientImage(colors: colors, size: rect.size)
        let gradientSprite = SKSpriteNode(texture: SKTexture(image: gradientImage))
        gradientSprite.size = rect.size
        gradientNode.addChild(gradientSprite)

        bgLayer.addChild(gradientNode)
    }

    private func createGradientImage(colors: [CGColor], size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!

        let startPoint = CGPoint(x: size.width / 2, y: size.height)
        let endPoint = CGPoint(x: size.width / 2, y: 0)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        image.unlockFocus()
        return image
    }

    private func generateStarLayers() {
        // Three layers of stars for parallax depth
        for layer in 0..<3 {
            let starCount = [150, 80, 40][layer]
            let layerNode = SKNode()
            layerNode.zPosition = CGFloat(layer)

            for _ in 0..<starCount {
                let star = SKShapeNode(circleOfRadius: CGFloat(layer == 0 ? 0.8 : (layer == 1 ? 1.2 : 1.8)))
                star.fillColor = .white
                star.strokeColor = .clear

                let baseAlpha: CGFloat
                switch layer {
                case 0: baseAlpha = CGFloat.random(in: 0.2...0.6)
                case 1: baseAlpha = CGFloat.random(in: 0.3...0.7)
                default: baseAlpha = CGFloat.random(in: 0.4...0.9)
                }
                star.alpha = baseAlpha

                star.position = CGPoint(
                    x: CGFloat.random(in: -size.width...size.width),
                    y: CGFloat.random(in: -size.height...size.height * 2)
                )

                let twinkleDuration = Double.random(in: 2.0...6.0)
                let highAlpha = min(1.0, baseAlpha + 0.2)
                star.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: highAlpha, duration: twinkleDuration),
                        SKAction.fadeAlpha(to: baseAlpha, duration: twinkleDuration)
                    ])
                ))
                layerNode.addChild(star)
            }
            bgLayer.addChild(layerNode)
        }
    }

    private func generateNebulae() {
        // Soft colored nebulae as large radial gradients
        let nebulaColors: [NSColor] = [
            NSColor.systemPurple.withAlphaComponent(0.08),
            NSColor.systemBlue.withAlphaComponent(0.06),
            NSColor.systemTeal.withAlphaComponent(0.05),
            NSColor.magenta.withAlphaComponent(0.05),
        ]

        for i in 0..<4 {
            let size_val: CGFloat = CGFloat.random(in: 300...600)
            let ovalPath = CGPath(ellipseIn: CGRect(
                x: -size_val / 2,
                y: -size_val / 2,
                width: size_val,
                height: size_val * CGFloat.random(in: 0.6...0.9)
            ), transform: nil)

            let nebulaNode = SKEmitterNode()
            let nebula = SKShapeNode(path: ovalPath)
            nebula.fillColor = nebulaColors[i % nebulaColors.count]
            nebula.strokeColor = .clear
            nebula.alpha = 0.4
            nebula.position = CGPoint(
                x: CGFloat.random(in: -size.width / 2...size.width / 2),
                y: CGFloat.random(in: -size.height / 2...size.height / 2)
            )
            nebulaNode.addChild(nebula)
            bgLayer.addChild(nebulaNode)
        }
    }

    // MARK: - HUD

    private func setupHUD() {
        let panelHeight: CGFloat = 48
        // Background panel — SKShapeNode(rect:) centers at node position, so
        // we create a rect centered at origin and position the node where we want it.
        let panel = SKShapeNode(rectOf: CGSize(width: size.width, height: panelHeight))
        panel.fillColor = NSColor.black.withAlphaComponent(0.6)
        panel.strokeColor = .clear
        panel.position = CGPoint(x: size.width / 2, y: panelHeight / 2)
        hudLayer.addChild(panel)

        // Top edge highlight line
        let highlight = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
        highlight.fillColor = NSColor.white.withAlphaComponent(0.06)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: size.width / 2, y: panelHeight)
        hudLayer.addChild(highlight)

        let labelY: CGFloat = panelHeight / 2

        // Left cluster — measure each label and flow them left-to-right with
        // fixed spacing instead of hard-coded x positions, so the longer
        // "Dominion Campaign" faction name never runs into the neighbours.
        turnLabel.fontName = "Helvetica Neue"
        turnLabel.fontSize = 13
        turnLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        turnLabel.horizontalAlignmentMode = .left
        hudLayer.addChild(turnLabel)

        factionLabel.fontName = "Helvetica Neue"
        factionLabel.fontSize = 13
        factionLabel.fontColor = NSColor.systemBlue
        factionLabel.horizontalAlignmentMode = .left
        hudLayer.addChild(factionLabel)

        resourcesLabel.fontName = ".AppleSystemUIFont"
        resourcesLabel.fontSize = 12
        resourcesLabel.fontColor = NSColor.systemYellow
        resourcesLabel.horizontalAlignmentMode = .left
        hudLayer.addChild(resourcesLabel)

        actionsLabel.fontName = ".AppleSystemUIFont"
        actionsLabel.fontSize = 12
        actionsLabel.fontColor = NSColor.systemGreen
        actionsLabel.horizontalAlignmentMode = .left
        hudLayer.addChild(actionsLabel)

        // End Turn button geometry (see setupActionPanel) — the right-side
        // reserve starts just left of it.
        let btnW: CGFloat = 110
        hudRightReserve = size.width - 12 - btnW - 8

        // Seed label (right side, left of the End Turn button)
        seedLabel.fontName = ".AppleSystemUIFont"
        seedLabel.fontSize = 10
        seedLabel.fontColor = NSColor.gray.withAlphaComponent(0.6)
        seedLabel.horizontalAlignmentMode = .right
        hudLayer.addChild(seedLabel)

        // Status label — flows after the left cluster, clamped so long text
        // never runs into the End Turn button zone.
        statusLabel.fontName = ".AppleSystemUIFont"
        statusLabel.fontSize = 12
        statusLabel.fontColor = NSColor.gray.withAlphaComponent(0.7)
        statusLabel.text = "Click a fleet or system to begin"
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.numberOfLines = 1
        hudLayer.addChild(statusLabel)

        layoutHUDLeftCluster(labelY: labelY)

        // Tooltip — appears near cursor
        tooltipLabel.fontName = ".AppleSystemUIFont"
        tooltipLabel.fontSize = 13
        tooltipLabel.fontColor = NSColor.white.withAlphaComponent(0.9)
        tooltipLabel.name = "tooltip"
        tooltipLabel.alpha = 0
        tooltipLabel.horizontalAlignmentMode = .left
        tooltipLabel.preferredMaxLayoutWidth = 300
        tooltipLabel.numberOfLines = 0
        hudLayer.addChild(tooltipLabel)

        // Action panel (right side)
        setupActionPanel(height: panelHeight)

        // Actions menu (contextual, below action panel — hidden by default)
        actionsMenu.zPosition = 200
        actionsMenu.alpha = 0
        actionsMenu.isHidden = true
        hudLayer.addChild(actionsMenu)

        // Pause overlay (hidden by default)
        setupPauseOverlay()

        updateHUD()
    }

    private func setupActionPanel(height: CGFloat) {
        actionPanel.zPosition = 200
        hudLayer.addChild(actionPanel)

        let btnW: CGFloat = 110
        let btnH: CGFloat = 32
        // Button center position
        let btnCX = size.width - btnW / 2 - 12
        let btnCY: CGFloat = height / 2

        // Button background — rect centered at origin
        let bg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 8)
        bg.fillColor = NSColor.systemOrange.withAlphaComponent(0.12)
        bg.strokeColor = NSColor.systemOrange.withAlphaComponent(0.45)
        bg.lineWidth = 1
        bg.position = CGPoint(x: btnCX, y: btnCY)
        actionPanel.addChild(bg)

        endTurnButton.position = CGPoint(x: btnCX, y: btnCY)
        endTurnButton.name = "endTurn"
        actionPanel.addChild(endTurnButton)

        endTurnLabel.fontName = "Helvetica Neue"
        endTurnLabel.fontSize = 13
        endTurnLabel.fontColor = NSColor.systemOrange
        endTurnLabel.text = "End Turn"
        endTurnLabel.position = CGPoint(x: 0, y: 0)
        endTurnLabel.horizontalAlignmentMode = .center
        endTurnButton.addChild(endTurnLabel)
    }

    private func layoutHUDLeftCluster(labelY: CGFloat) {
        // hudLayer has no transform in this fixed-size scene, so a label's
        // frame width is its text width.
        func width(_ label: SKLabelNode) -> CGFloat { label.frame.width }
        let spacing: CGFloat = 20
        var x: CGFloat = 20

        turnLabel.position = CGPoint(x: x, y: labelY)
        x += width(turnLabel) + spacing

        factionLabel.position = CGPoint(x: x, y: labelY)
        x += width(factionLabel) + spacing

        resourcesLabel.position = CGPoint(x: x, y: labelY)
        x += width(resourcesLabel) + spacing

        actionsLabel.position = CGPoint(x: x, y: labelY)
        let leftClusterEnd = x + width(actionsLabel)

        // Seed label hugs the left side of the End Turn button.
        seedLabel.position = CGPoint(x: hudRightReserve - 12, y: labelY)

        // Status label flows after the cluster. Its available band is between
        // the cluster end and the seed label.
        let statusStart = leftClusterEnd + 12
        let statusEnd = hudRightReserve - 150
        let band = statusEnd - statusStart

        let statusWidth = width(statusLabel)
        if band > 0, statusWidth > band {
            // Doesn't fit in the middle band — anchor it right, after the seed.
            statusLabel.preferredMaxLayoutWidth = 150
            statusLabel.horizontalAlignmentMode = .right
            statusLabel.position = CGPoint(x: statusEnd, y: labelY)
        } else {
            statusLabel.preferredMaxLayoutWidth = max(0, band)
            statusLabel.horizontalAlignmentMode = .left
            statusLabel.position = CGPoint(x: statusStart, y: labelY)
        }
    }

    // MARK: - Actions Menu

    private func updateActionsMenu() {
        actionsMenu.removeAllChildren()
        actionButtons.removeAll()

        guard !sim.state.isOver,
              let systemID = selectedSystemID,
              let system = sim.state.systems[systemID] else {
            actionsMenu.isHidden = true
            return
        }

        // Check if we have a friendly fleet at this system
        let hasOwnFleet = sim.state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == sim.state.currentFaction
        }
        // Fleet-gated actions only make sense with a fleet present, but the
        // starbase can always offer Build / Rebuild — a faction that has lost
        // every ship must still be able to rebuild at home.
        let isOwnStarbase = system.owner == sim.state.currentFaction && system.hasStarbase
        guard hasOwnFleet || isOwnStarbase else {
            actionsMenu.isHidden = true
            return
        }

        var availableActions: [(CampaignAction, String)] = []

        // System development (mine/colony/fortify) requires a fleet present to
        // supervise the build.
        if hasOwnFleet {
            switch system.type {
            case .life:
                if !system.hasColony {
                    availableActions.append((.colonize(systemID: systemID), "Colonize"))
                }
            case .mineral:
                if !system.hasMine {
                    availableActions.append((.mine(systemID: systemID), "Build Mine"))
                }
            case .dead:
                if !system.isFortified {
                    availableActions.append((.fortify(systemID: systemID), "Fortify"))
                }
            }

            if system.hasColony && system.owner == sim.state.currentFaction {
                availableActions.append((.recruitCrew(systemID: systemID), "Recruit Crew"))
            }
        }

        if sim.state.actionsRemaining > 0, isOwnStarbase {
            // A sentinel buildShip action that the click handler intercepts to
            // open the ship-picker submenu (see mouseDown below).
            availableActions.append((.buildShip(shipIndex: -1), "Build Ship..."))
            // If this faction has lost every ship, offer a full rebuild so the
            // game can't soft-lock with a starbase but no way to field a fleet.
            let factionHasFleet = sim.state.fleets.values.contains {
                $0.faction == sim.state.currentFaction && !$0.isEmpty
            }
            if !factionHasFleet {
                availableActions.append((.rebuildFleet, "Rebuild Fleet"))
            }
            isBuildShipMenuOpen = false
        }

        // Check for multiple friendly fleets at this system (can merge)
        let friendlyFleetsHere = sim.state.fleets.values.filter {
            $0.systemID == systemID && $0.faction == sim.state.currentFaction && $0.destinationSystemID == nil
        }
        if sim.state.actionsRemaining > 0, friendlyFleetsHere.count >= 2 {
            // Add a merge action for the second fleet
            let fleetIDs = sim.state.fleets.compactMap { (key, fleet) -> EntityID? in
                fleet.systemID == systemID && fleet.faction == sim.state.currentFaction && fleet.destinationSystemID == nil ? key : nil
            }.sorted { $0.value < $1.value }
            if fleetIDs.count >= 2 {
                availableActions.append((.mergeFleets(fleetID1: fleetIDs[0], fleetID2: fleetIDs[1]), "Merge Fleets"))
            }
        }

        if availableActions.isEmpty {
            actionsMenu.isHidden = true
            return
        }

        actionsMenu.isHidden = false
        actionsMenu.alpha = 0
        actionsMenu.run(SKAction.fadeAlpha(to: 1, duration: 0.2))

        // Position menu to the left of the End Turn button, stacked vertically
        let btnW: CGFloat = 180
        let btnH: CGFloat = 28
        let spacing: CGFloat = 6
        let menuHeight = CGFloat(availableActions.count) * btnH + CGFloat(availableActions.count - 1) * spacing
        let panelHeight: CGFloat = 48

        // Position below the HUD, centered between left labels and End Turn button
        let menuX: CGFloat = size.width / 2
        let menuStartY: CGFloat = panelHeight + 20 + menuHeight / 2

        for (i, (action, label)) in availableActions.enumerated() {
            let btnY = menuStartY - CGFloat(i) * (btnH + spacing)

            let btnNode = SKNode()
            btnNode.position = CGPoint(x: menuX, y: btnY)
            btnNode.name = "actionBtn_\(i)"

            let bg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 6)
            bg.fillColor = NSColor.black.withAlphaComponent(0.6)
            bg.strokeColor = NSColor.white.withAlphaComponent(0.2)
            bg.lineWidth = 1
            btnNode.addChild(bg)

            let labelNode = SKLabelNode()
            labelNode.fontName = ".AppleSystemUIFont"
            labelNode.fontSize = 12
            labelNode.fontColor = NSColor.white.withAlphaComponent(0.85)
            labelNode.text = label
            labelNode.position = CGPoint(x: 0, y: 2)
            labelNode.horizontalAlignmentMode = .center
            btnNode.addChild(labelNode)

            actionsMenu.addChild(btnNode)
            actionButtons.append((btnNode, action, label))
        }
    }

    // MARK: - Pause Overlay

    private func setupPauseOverlay() {
        pauseOverlay.alpha = 0
        pauseOverlay.isHidden = true
        pauseOverlay.zPosition = 200
        addChild(pauseOverlay)

        let cx = size.width / 2
        let cy = size.height / 2

        // Dim background
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = NSColor.black.withAlphaComponent(0.65)
        dim.strokeColor = .clear
        dim.position = CGPoint(x: cx, y: cy)
        pauseOverlay.addChild(dim)

        // Compact center panel
        let pw: CGFloat = 260
        let ph: CGFloat = 160
        let panel = SKShapeNode(rectOf: CGSize(width: pw, height: ph), cornerRadius: 12)
        panel.fillColor = NSColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.95)
        panel.strokeColor = NSColor.white.withAlphaComponent(0.1)
        panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy)
        pauseOverlay.addChild(panel)

        // Title
        let title = SKLabelNode()
        title.fontName = "Helvetica Neue"
        title.fontSize = 18
        title.fontColor = NSColor.white.withAlphaComponent(0.9)
        title.text = "Paused"
        title.position = CGPoint(x: cx, y: cy + 28)
        title.horizontalAlignmentMode = .center
        pauseOverlay.addChild(title)

        // Button dimensions
        let btnW: CGFloat = 200
        let btnH: CGFloat = 30
        let quitY = cy - 16

        // Save & Quit button
        let saveQuitBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 7)
        saveQuitBg.fillColor = NSColor.systemBlue.withAlphaComponent(0.15)
        saveQuitBg.strokeColor = NSColor.systemBlue.withAlphaComponent(0.4)
        saveQuitBg.lineWidth = 1
        saveQuitBg.position = CGPoint(x: cx, y: quitY + 38)
        saveQuitBg.name = "pause_save_quit"
        pauseOverlay.addChild(saveQuitBg)

        let saveQuitLabel = SKLabelNode()
        saveQuitLabel.fontName = ".AppleSystemUIFont"
        saveQuitLabel.fontSize = 13
        saveQuitLabel.fontColor = NSColor.systemBlue
        saveQuitLabel.text = "Save & Quit"
        saveQuitLabel.position = CGPoint(x: cx, y: quitY + 38)
        saveQuitLabel.horizontalAlignmentMode = .center
        pauseOverlay.addChild(saveQuitLabel)

        // Quit to Menu button
        let quitBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 7)
        quitBg.fillColor = NSColor.systemRed.withAlphaComponent(0.15)
        quitBg.strokeColor = NSColor.systemRed.withAlphaComponent(0.4)
        quitBg.lineWidth = 1
        quitBg.position = CGPoint(x: cx, y: quitY)
        quitBg.name = "pause_quit"
        pauseOverlay.addChild(quitBg)

        let quitLabel = SKLabelNode()
        quitLabel.fontName = ".AppleSystemUIFont"
        quitLabel.fontSize = 13
        quitLabel.fontColor = NSColor.systemRed
        quitLabel.text = "Quit to Menu"
        quitLabel.position = CGPoint(x: cx, y: quitY)
        quitLabel.horizontalAlignmentMode = .center
        pauseOverlay.addChild(quitLabel)

        // Resume button
        let resumeY = cy - 54
        let resumeBg = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 7)
        resumeBg.fillColor = NSColor.white.withAlphaComponent(0.07)
        resumeBg.strokeColor = NSColor.white.withAlphaComponent(0.2)
        resumeBg.lineWidth = 1
        resumeBg.position = CGPoint(x: cx, y: resumeY)
        resumeBg.name = "pause_resume"
        pauseOverlay.addChild(resumeBg)

        let resumeLabel = SKLabelNode()
        resumeLabel.fontName = ".AppleSystemUIFont"
        resumeLabel.fontSize = 13
        resumeLabel.fontColor = NSColor.white.withAlphaComponent(0.85)
        resumeLabel.text = "Resume"
        resumeLabel.position = CGPoint(x: cx, y: resumeY)
        resumeLabel.horizontalAlignmentMode = .center
        pauseOverlay.addChild(resumeLabel)
    }

    public func togglePauseOverlay() {
        isPauseVisible.toggle()
        pauseOverlay.isHidden = !isPauseVisible
        pauseOverlay.run(SKAction.fadeAlpha(to: isPauseVisible ? 1.0 : 0, duration: 0.15))
    }

    public func hidePauseOverlay() {
        isPauseVisible = false
        pauseOverlay.isHidden = true
        pauseOverlay.alpha = 0
    }

    /// Whether the player currently has a fleet or system selected.
    public func hasSelection() -> Bool {
        return selectedFleetID != nil || selectedSystemID != nil
    }

    /// Escape: cancel selection (or close an open submenu) first; only open the
    /// pause overlay when nothing is selected. Toggles the pause overlay if it's
    /// already showing.
    public func handleEscape() {
        if isBuildShipMenuOpen {
            buildShipButtons.removeAll()
            buildShipIndices.removeAll()
            isBuildShipMenuOpen = false
            render()
            return
        }
        if hasSelection() {
            deselect()
            return
        }
        togglePauseOverlay()
    }

    /// Clear all selections and hide the actions menu (ESC / right-click cancel).
    public func deselect() {
        selectedFleetID = nil
        selectedSystemID = nil
        actionsMenu.isHidden = true
        actionButtons.removeAll()
        buildShipButtons.removeAll()
        buildShipIndices.removeAll()
        isBuildShipMenuOpen = false
        setStatus("Selection cleared. Click a fleet or system.")
        render()
    }

    private func hitPauseButton(_ point: CGPoint, name: String) -> Bool {
        for child in pauseOverlay.children {
            guard let childName = child.name, childName == name else { continue }
            let childRect = CGRect(
                x: child.position.x - child.frame.width / 2,
                y: child.position.y - child.frame.height / 2,
                width: child.frame.width,
                height: child.frame.height
            )
            if childRect.contains(point) {
                return true
            }
        }
        return false
    }

    // MARK: - Render

    public func render() {
        renderMap()
        updateHUD()
    }

    public func update() {
        // Called each frame — only update HUD text, do NOT rebuild the map.
        // Rebuilding the map destroys all SKAction animations (twinkling stars,
        // pulsing glows, etc.) and is extremely wasteful at 24+ FPS.
        updateHUD()
    }

      private func renderMap() {
        connectionLayer.removeAllChildren()
        systemLayer.removeAllChildren()
        fleetLayer.removeAllChildren()
        indicatorLayer.removeAllChildren()

        let state = sim.state
        let mapBounds = computeMapBounds()
        cachedMapScale = CGFloat(computeScale(mapBounds))

        // Center the map in the full viewport.
        let mapCenterX = mapBounds.midX
        let mapCenterY = mapBounds.midY
        let totalScale = currentScale * cachedMapScale

        // World layer scale handles all zoom.
        worldLayer.xScale = totalScale
        worldLayer.yScale = totalScale

        // Center the map in the viewport.
        let mapCenterScreenX = size.width / 2
        let mapCenterScreenY = size.height / 2

        worldLayer.position = CGPoint(
            x: mapCenterScreenX - CGFloat(mapCenterX) * totalScale + panOffset.x,
            y: mapCenterScreenY - CGFloat(mapCenterY) * totalScale + panOffset.y
        )

        // Connections — only show explored routes
        visibleSet = state.revealedSystems
        currentlyVisibleSet = sim.visibleSystems(for: .compact)
        let visibleSet = visibleSet
        let currentlyVisible = currentlyVisibleSet
        for conn in state.connections {
            guard let sa = state.systems[conn.a], let sb = state.systems[conn.b] else { continue }
            // Both endpoints must be revealed to show the connection
            guard visibleSet.contains(conn.a), visibleSet.contains(conn.b) else { continue }
            let pa = worldToScreen(sa.position)
            let pb = worldToScreen(sb.position)

            let path = CGMutablePath()
            path.move(to: pa)
            path.addLine(to: pb)

            // Dim connection if not currently visible
            let alpha: CGFloat = currentlyVisible.contains(conn.a) || currentlyVisible.contains(conn.b) ? 0.25 : 0.12
            let lineColor = NSColor.systemTeal.withAlphaComponent(alpha)

            // Wide, dim glow line
            let glow = SKShapeNode(path: path)
            glow.strokeColor = lineColor.withAlphaComponent(alpha * 0.3)
            glow.lineWidth = 5
            glow.lineCap = .round
            connectionLayer.addChild(glow)

            // Thin core line
            let line = SKShapeNode(path: path)
            line.strokeColor = lineColor
            line.lineWidth = 1
            line.lineCap = .round
            connectionLayer.addChild(line)
        }

        // Systems — fog of war
        for system in state.systems.values {
            // Skip systems that have never been revealed
            guard visibleSet.contains(system.id) else { continue }

            let pos = worldToScreen(system.position)
            let isCurrentlyVisible = currentlyVisible.contains(system.id)

            // Determine color based on visibility
            let color: NSColor
            if isCurrentlyVisible {
                color = systemColor(system)
            } else {
                // Explored but out of sight — dim gray silhouette
                color = NSColor.gray.withAlphaComponent(0.4)
            }

            // Base radius depends on system type and importance
            let baseRadius: CGFloat
            switch system.type {
            case .life:
                baseRadius = system.hasStarbase ? 18 : 14
            case .mineral:
                baseRadius = system.hasStarbase ? 16 : 12
            case .dead:
                baseRadius = system.hasStarbase ? 14 : 10
            }

            // Starbase glow ring — animated pulse (only when currently visible)
            if system.hasStarbase && isCurrentlyVisible {
                let glowSize = baseRadius * 2.2
                let glowPath = CGPath(ellipseIn: CGRect(
                    x: -glowSize, y: -glowSize,
                    width: glowSize * 2, height: glowSize * 2
                ), transform: nil)

                let glowNode = SKShapeNode(path: glowPath)
                glowNode.fillColor = NSColor.clear
                glowNode.strokeColor = color.withAlphaComponent(0.3)
                glowNode.lineWidth = 2
                glowNode.alpha = 0.3
                glowNode.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.group([
                            SKAction.fadeAlpha(to: 0.5, duration: 2.5),
                            SKAction.scale(to: 1.3, duration: 2.5)
                        ]),
                        SKAction.group([
                            SKAction.fadeAlpha(to: 0.2, duration: 2.5),
                            SKAction.scale(to: 1.0, duration: 2.5)
                        ])
                    ])
                ))

                let glowWrapper = SKNode()
                glowWrapper.position = pos
                glowWrapper.addChild(glowNode)
                systemLayer.addChild(glowWrapper)
            }

            // System node — circle for normal, rounded rect for starbase
            let node: SKShapeNode
            if system.hasStarbase {
                let r: CGFloat = baseRadius + 2
                node = SKShapeNode(rect: CGRect(x: -r, y: -r, width: r * 2, height: r * 2),
                                  cornerRadius: 4)
            } else {
                node = SKShapeNode(circleOfRadius: baseRadius)
            }
            node.fillColor = color.withAlphaComponent(0.5)
            node.strokeColor = color.withAlphaComponent(0.9)
            node.lineWidth = 1.5
            node.name = "system_\((system.id).value)"
            node.position = pos
            systemLayer.addChild(node)

            // Fog overlay — translucent dark tint for revealed-but-not-visible systems
            if !isCurrentlyVisible {
                let fog = SKShapeNode(circleOfRadius: baseRadius + 3)
                fog.fillColor = NSColor.black.withAlphaComponent(0.55)
                fog.strokeColor = .clear
                node.addChild(fog)
            }

            // Subtle outer glow on all systems
            let outerGlow = SKShapeNode(circleOfRadius: baseRadius + 4)
            outerGlow.fillColor = .clear
            outerGlow.strokeColor = color.withAlphaComponent(0.15)
            outerGlow.lineWidth = 2
            node.addChild(outerGlow)

            // Selection ring — pulsing white glow for selected system
            if selectedSystemID == system.id {
                let selRing = SKShapeNode(circleOfRadius: baseRadius + 6)
                selRing.fillColor = .clear
                selRing.strokeColor = NSColor.white.withAlphaComponent(0.6)
                selRing.lineWidth = 2
                selRing.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.group([
                            SKAction.fadeAlpha(to: 0.3, duration: 0.6),
                            SKAction.scale(to: 1.3, duration: 0.6)
                        ]),
                        SKAction.group([
                            SKAction.fadeAlpha(to: 0.7, duration: 0.6),
                            SKAction.scale(to: 1.0, duration: 0.6)
                        ])
                    ])
                ))
                node.addChild(selRing)
            }

            // System name label
            let nameLabel = SKLabelNode()
            nameLabel.fontName = ".AppleSystemUIFont"
            nameLabel.fontSize = isCurrentlyVisible ? 11 : 9
            nameLabel.fontColor = isCurrentlyVisible
                ? NSColor.white.withAlphaComponent(0.8)
                : NSColor.gray.withAlphaComponent(0.5)
            nameLabel.text = system.name
            nameLabel.position = CGPoint(x: 0, y: -baseRadius - 6)
            nameLabel.horizontalAlignmentMode = .center
            node.addChild(nameLabel)

            // Build indicator with progress ring (only visible when currently in sight)
            if isCurrentlyVisible, let action = system.currentAction, system.actionTurnsRemaining > 0 {
                let ringRadius = baseRadius + 5
                let ringPath = CGPath(ellipseIn: CGRect(
                    x: -ringRadius, y: -ringRadius,
                    width: ringRadius * 2, height: ringRadius * 2
                ), transform: nil)
                let ring = SKShapeNode(path: ringPath)
                ring.strokeColor = NSColor.systemYellow
                ring.fillColor = .clear
                ring.lineWidth = 2
                ring.alpha = 0.7

                // Human-readable label with turns remaining (raw enum token was
                // cryptic and collided with the system name label).
                let actionText: String
                switch action {
                case .mine: actionText = "Building Mine"
                case .colony: actionText = "Building Colony"
                case .fortification: actionText = "Building Fortifications"
                }
                let buildLabel = SKLabelNode()
                buildLabel.fontName = ".AppleSystemUIFont"
                buildLabel.fontSize = 9
                buildLabel.fontColor = NSColor.systemYellow
                buildLabel.text = "\(actionText) (\(system.actionTurnsRemaining) left)"
                buildLabel.position = CGPoint(x: 0, y: baseRadius + 10)
                buildLabel.horizontalAlignmentMode = .center
                node.addChild(buildLabel)
                node.addChild(ring)
            }

            // Fortification indicator — hexagon ring
            if system.isFortified {
                let fortRadius = baseRadius + 7
                let hexPath = polygonPath(sides: 6, radius: fortRadius)
                let fort = SKShapeNode(path: hexPath)
                fort.fillColor = .clear
                fort.strokeColor = NSColor.systemRed.withAlphaComponent(0.5)
                fort.lineWidth = 1.5
                node.addChild(fort)
            }

            // Colony/Mine icons
            if system.hasColony || system.hasMine {
                let icon = SKLabelNode()
                icon.fontName = ".AppleSystemUIFont"
                icon.fontSize = 10
                icon.fontColor = NSColor.white
                var text = ""
                if system.hasColony { text += "🏘" }
                if system.hasMine { text += "⛏" }
                icon.text = text
                icon.position = CGPoint(x: 0, y: -baseRadius - 4)
                node.addChild(icon)
            }
        }

        // Fleets — triangular ship markers with count badges
        for fleet in state.fleets.values {
            // An in-transit fleet is physically moving toward its destination;
            // show it at the destination system rather than frozen at its
            // origin (the old behavior made fleets look like they "vanished"
            // and reappeared at End Turn).
            let renderSystemID: EntityID
            if let destID = fleet.destinationSystemID,
               state.systems[destID] != nil {
                renderSystemID = destID
            } else {
                renderSystemID = fleet.systemID
            }
            let sysPos = state.systems[renderSystemID]?.position
            guard let pos = sysPos else { continue }

            let isOwn = fleet.faction == state.currentFaction
            let isMoving = fleet.destinationSystemID != nil

            // Fog of war: only show enemy fleets in currently visible systems.
            // Own fleets are always visible (player controls them directly).
            // Check the rendered position (destination while en route) so an
            // enemy fleet moving into view appears as it arrives.
            if !isOwn && !currentlyVisible.contains(renderSystemID) {
                continue
            }

            let screenPos = worldToScreen(pos)

            // Draw a triangle for the fleet, colored by faction
            let fleetColor: NSColor = isOwn
                ? NSColor.systemGreen
                : NSColor.systemRed

            let fleetCount = fleet.ships.count
            let size: CGFloat = CGFloat(max(16, 16 + fleetCount * 2))

            let fleetNode = SKNode()
            fleetNode.name = "fleet_\(fleet.id.value)"
            fleetNode.position = CGPoint(
                x: screenPos.x + CGFloat(fleetCount) * 0.8,
                y: screenPos.y + 24
            )

            // Triangle pointing up
            let trianglePath = CGMutablePath()
            trianglePath.move(to: CGPoint(x: 0, y: size))
            trianglePath.addLine(to: CGPoint(x: -size * 0.7, y: -size * 0.3))
            trianglePath.addLine(to: CGPoint(x: size * 0.7, y: -size * 0.3))
            trianglePath.closeSubpath()

            let triangle = SKShapeNode(path: trianglePath)
            triangle.fillColor = fleetColor.withAlphaComponent(0.8)
            triangle.strokeColor = fleetColor
            triangle.lineWidth = 1.5

            // Glow for own fleets
            if isOwn {
                let glow = SKEmitterNode()
                triangle.addChild(glow)
            }

            fleetNode.addChild(triangle)

            // Movement trail if moving
            if isMoving, let currentPos = fleetDestinationScreen(fleet: fleet) {
                let movePath = CGMutablePath()
                movePath.move(to: CGPoint(x: 0, y: 0))
                movePath.addLine(to: CGPoint(
                    x: currentPos.x - fleetNode.position.x,
                    y: currentPos.y - fleetNode.position.y
                ))
                let trail = SKShapeNode(path: movePath)
                trail.strokeColor = NSColor.systemYellow.withAlphaComponent(0.5)
                trail.lineWidth = 2
                trail.lineCap = .round
                trail.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.2, duration: 0.5),
                        SKAction.fadeAlpha(to: 0.5, duration: 0.5)
                    ])
                ))
                fleetNode.addChild(trail)
            }

            // Count badge — capped so a large fleet doesn't make a badge bigger
            // than the ship marker itself.
            let badge = SKShapeNode(circleOfRadius: CGFloat(max(6, min(14, fleetCount * 3))))
            badge.fillColor = NSColor.black.withAlphaComponent(0.7)
            badge.strokeColor = fleetColor.withAlphaComponent(0.5)
            badge.lineWidth = 1
            badge.position = CGPoint(x: 0, y: size + 6)
            fleetNode.addChild(badge)

            let countLabel = SKLabelNode()
            countLabel.fontName = "Helvetica Neue"
            countLabel.fontSize = fleetCount >= 10 ? 9 : 10
            countLabel.fontColor = fleetColor
            countLabel.text = "\(fleetCount)"
            countLabel.position = CGPoint(x: 0, y: 0)
            badge.addChild(countLabel)

            // Ship class label
            if let firstShip = fleet.ships.first,
               firstShip.shipIndex >= 0 && firstShip.shipIndex < ShipRoster.all.count {
                let shipDef = ShipRoster.all[firstShip.shipIndex]
                let classLabel = SKLabelNode()
                 classLabel.fontName = ".AppleSystemUIFont"
                 classLabel.fontSize = 9
                 classLabel.fontColor = NSColor.white.withAlphaComponent(0.7)
                 classLabel.text = shipDef.species
                 classLabel.position = CGPoint(x: 0, y: -size - 8)
                 fleetNode.addChild(classLabel)
            }

            fleetLayer.addChild(fleetNode)
        }

        // Move indicators for selected fleet
        if let selectedFleetID = selectedFleetID,
           let selectedFleet = state.fleets[selectedFleetID],
           selectedFleet.faction == state.currentFaction {
            let connected = sim.connectedSystems(to: selectedFleet.systemID)
            for sysID in connected {
                guard let pos = state.systems[sysID]?.position else { continue }
                let screenPos = worldToScreen(pos)

                let indicator = SKShapeNode(circleOfRadius: 16)
                indicator.fillColor = NSColor.systemYellow.withAlphaComponent(0.2)
                indicator.strokeColor = NSColor.systemYellow.withAlphaComponent(0.7)
                indicator.lineWidth = 1.5
                indicator.position = screenPos
                indicator.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.6),
                        SKAction.fadeAlpha(to: 0.2, duration: 0.6)
                    ])
                ))
                indicatorLayer.addChild(indicator)

                // Pulse
                let pulse = SKShapeNode(circleOfRadius: 20)
                pulse.fillColor = .clear
                pulse.strokeColor = NSColor.systemYellow.withAlphaComponent(0.3)
                pulse.lineWidth = 1
                pulse.position = screenPos
                pulse.run(SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: 1.8, duration: 1.0),
                            SKAction.fadeAlpha(to: 0, duration: 1.0)
                        ]),
                        SKAction.scale(to: 1.0, duration: 0)
                    ])
                ))
                indicatorLayer.addChild(pulse)
            }
        }
    }

    // MARK: - HUD

    // X where the right-side reserve (End Turn button / seed) begins.
    private var hudRightReserve: CGFloat = 0

    private func updateHUD() {
        let state = sim.state
        turnLabel.text = "Turn \(state.currentTurn)"

        let factionText: String
        let factionColor: NSColor
        switch state.currentFaction {
        case .compact:
            factionText = "Compact Campaign"
            factionColor = NSColor.systemGreen
        case .dominion:
            factionText = "Dominion Campaign"
            factionColor = NSColor.systemRed
        }
        factionLabel.text = factionText
        factionLabel.fontColor = factionColor

        let resources = state.resources[state.currentFaction] ?? 0
        resourcesLabel.text = "✦ \(resources)"
        seedLabel.text = "Seed: \(sim.seedValue)"
        actionsLabel.text = "Actions: \(state.actionsRemaining)"

        if state.isOver {
            statusLabel.fontName = "Helvetica Neue"
            statusLabel.fontSize = 14
            statusLabel.text = state.winner == .compact
                ? "Victory! The Compact prevails!"
                : "Defeat... The Dominion triumphs."
            statusLabel.fontColor = NSColor.systemYellow
            endTurnLabel.alpha = 0
        } else if let pending = state.pendingCombat {
            statusLabel.fontName = "Helvetica Neue"
            statusLabel.fontSize = 14
            statusLabel.text = "⚔️ Combat at \(state.systems[pending.systemID]?.name ?? "unknown")!"
            statusLabel.fontColor = NSColor.systemRed
        } else {
            statusLabel.fontName = ".AppleSystemUIFont"
            statusLabel.fontSize = 12
            statusLabel.fontColor = NSColor.gray.withAlphaComponent(0.8)
            // Surface a rebuild path when the active faction has no fleets.
            let factionHasFleet = state.fleets.values.contains {
                $0.faction == state.currentFaction && !$0.isEmpty
            }
            if !factionHasFleet, sim.hasStarbase(state.currentFaction) {
                statusLabel.text = "No fleets. Select your home starbase to rebuild."
                statusLabel.fontColor = NSColor.systemYellow.withAlphaComponent(0.9)
            }
        }
        // Re-flow the left cluster and status label now that texts are set.
        layoutHUDLeftCluster(labelY: 24)

        // Hover color feedback for End Turn button
        if !sim.state.isOver {
            endTurnLabel.alpha = 1
        }
    }

    // MARK: - Input

    public override func mouseMoved(with event: NSEvent) {
        guard let location = self.convertMouseLocation(event) else { return }
        // Account for world layer transform
        let worldPos = worldLayer.convert(location, from: self)

        var found = false

        // Check systems
        for child in systemLayer.children {
            guard let sysNode = child as? SKShapeNode,
                  let sysName = sysNode.name,
                  sysName.hasPrefix("system_") else { continue }

            let sysPos = CGPoint(x: sysNode.position.x, y: sysNode.position.y)
            let dist = hypot(worldPos.x - sysPos.x, worldPos.y - sysPos.y)

            if dist < 30 {
                guard let sysIDValue = UInt32(String(sysName.dropFirst(7))) else { continue }
                if let system = sim.state.systems[EntityID(sysIDValue)] {
                    let systemTypeText = systemTypeLabel(system.type)
                    let isCurrentlyVisible = currentlyVisibleSet.contains(system.id)

                    var details: String

                    if !sim.isSystemRevealed(system.id) {
                        // Never been seen — show as unknown
                        details = "Unknown System • Fog of War"
                    } else if !isCurrentlyVisible {
                        // Explored but not in current sight
                        let ownerText: String
                        if let owner = system.owner {
                            ownerText = owner == .compact ? "Compact" : "Dominion"
                        } else {
                            ownerText = "Unowned"
                        }
                        details = "\(system.name) • \(systemTypeText) • \(ownerText)"
                        details += "\n(Out of sight — details unknown)"
                    } else {
                        // Currently visible — show full details
                        let ownerText: String
                        if let owner = system.owner {
                            ownerText = owner == .compact ? "Compact" : "Dominion"
                        } else {
                            ownerText = "Unowned"
                        }

                         details = "\(system.name) • \(systemTypeText) • \(ownerText)"
                         if system.hasStarbase { details += " • ⭐ Starbase" }
                         if system.hasColony { details += " • 🏘 Colony" }
                         if system.hasMine { details += " • ⛏ Mine" }
                         if system.isFortified { details += " • 🛡 Fortified" }
                         
                         // Show fleet info at this system
                         let systemFleets = sim.state.fleets.values.filter { $0.systemID == system.id }
                         for fleet in systemFleets {
                             let factionName = fleet.faction == .compact ? "Compact" : "Dominion"
                             let shipSummary = summarizeFleetShips(fleet)
                             details += "\n\(factionName) Fleet: \(shipSummary)"
                         }

                        // Show available actions
                        let hasOwnFleet = sim.state.fleets.values.contains {
                            $0.systemID == system.id && $0.faction == sim.state.currentFaction
                        }
                        if hasOwnFleet {
                            let actions = actionHintsFor(system)
                            if !actions.isEmpty {
                                details += "\n" + actions.joined(separator: "  |  ")
                            }
                        } else {
                            details += "\n(No friendly fleet present)"
                        }
                    }

                    tooltipLabel.text = details
                    let tipX = max(24, min(size.width - 24, location.x + 12))
                    let tipY = max(24, min(size.height - 24, location.y + 20))
                    tooltipLabel.position = CGPoint(x: tipX, y: tipY)
                    tooltipLabel.alpha = 1
                    found = true
                }
                break
            }
        }

        // Check fleets
        if !found {
            for child in fleetLayer.children {
                guard let name = child.name,
                      name.hasPrefix("fleet_") else { continue }

                guard let fleetIDValue = UInt32(String(name.dropFirst(6))) else { continue }
                let fleetID = EntityID(fleetIDValue)
                guard let fleet = sim.state.fleets[fleetID] else { continue }

                let fleetPos = CGPoint(x: child.position.x, y: child.position.y)
                let dist = hypot(worldPos.x - fleetPos.x, worldPos.y - fleetPos.y)
                let radius = CGFloat(max(12, fleet.ships.count * 2 + 10))

                if dist < radius + 10 {
                    let factionName = fleet.faction == .compact ? "Compact" : "Dominion"
                    let sysName = sim.state.systems[fleet.systemID]?.name ?? "en route"
                    let shipNames = fleet.ships.prefix(3).map {
                        let idx = max(0, min($0.shipIndex, ShipRoster.all.count - 1))
                        return ShipRoster.all[idx].name
                    }
                    let moreCount = fleet.ships.count > 3 ? fleet.ships.count - 3 : 0
                    let extraText = moreCount > 0 ? " +\(moreCount) more" : ""
                    let moreText = moreCount > 0 ? ", " : ""
                    tooltipLabel.text = "\(factionName) Fleet (\(fleet.ships.count)) at \(sysName): \(shipNames.joined(separator: moreText))\(extraText)"
                    tooltipLabel.position = CGPoint(
                        x: max(24, min(size.width - 24, location.x + 12)),
                        y: max(24, min(size.height - 24, location.y + 20))
                    )
                    tooltipLabel.alpha = 1
                    break
                }
            }

            if !found && tooltipLabel.alpha > 0 {
                tooltipLabel.alpha = 0
            }
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let location = self.convertMouseLocation(event) else { return }

        if isPanning {
            let worldPos = worldLayer.convert(location, from: self)
            _ = worldPos

            // Pan by adjusting panOffset (renderMap will apply it).
            let delta = CGPoint(
                x: location.x - lastPanPoint.x,
                y: location.y - lastPanPoint.y
            )
            panOffset = CGPoint(
                x: panOffset.x + delta.x,
                y: panOffset.y + delta.y
            )
            lastPanPoint = location
            renderMap()
            return
        }
        mouseMoved(with: event)
    }

    public override func mouseDown(with event: NSEvent) {
        // Right-click cancels the current selection (spec: right-click or
        // Escape to cancel). Checked first so it works even mid-pan.
        if event.type == .rightMouseUp || event.type == .rightMouseDown {
            if hasSelection() {
                deselect()
            } else {
                // No selection: right-click toggles the pause overlay.
                togglePauseOverlay()
            }
            return
        }

        // Handle pause overlay clicks
        if isPauseVisible {
            guard let location = self.convertMouseLocation(event) else { return }
            if self.hitPauseButton(location, name: "pause_resume") {
                hidePauseOverlay()
                return
            }
            if self.hitPauseButton(location, name: "pause_save_quit") {
                hidePauseOverlay()
                onSaveAndQuit?()
                return
            }
            if self.hitPauseButton(location, name: "pause_quit") {
                hidePauseOverlay()
                onCampaignQuit?()
                return
            }
            return
        }

        guard !sim.state.isOver else { return }
        guard let location = self.convertMouseLocation(event) else { return }

        // Check actions menu buttons first
        for (btnNode, action, _) in actionButtons {
            let btnRect = CGRect(
                x: btnNode.position.x - 90,
                y: btnNode.position.y - 14,
                width: 180,
                height: 28
            )
            if btnRect.contains(location) {
                // The "Build Ship..." sentinel opens the ship-picker submenu.
                if case .buildShip(let idx) = action, idx == -1 {
                    showBuildShipSubmenu()
                    return
                }
                handleAction(action)
                return
            }
        }

        // Check build ship submenu buttons
        if isBuildShipMenuOpen, !buildShipButtons.isEmpty {
            for (i, btnNode) in buildShipButtons.enumerated() {
                let btnRect = CGRect(
                    x: btnNode.position.x - 140,
                    y: btnNode.position.y - 18,
                    width: 280,
                    height: 36
                )
                if btnRect.contains(location) {
                    let playerFaction = sim.state.currentFaction
                    let resources = sim.state.resources[playerFaction] ?? 0
                    guard i < buildShipIndices.count else { return }
                    let shipRosterIndex = buildShipIndices[i]
                    let ship = ShipRoster.all[shipRosterIndex]
                    guard resources >= ship.cost else { return }
                    let result = sim.execute(.buildShip(shipIndex: shipRosterIndex))
                    setStatus(result ?? "Built \(ship.name).")
                    selectedSystemID = nil
                    actionsMenu.isHidden = true
                    actionButtons.removeAll()
                    buildShipButtons.removeAll()
                    buildShipIndices.removeAll()
                    isBuildShipMenuOpen = false
                    render()
                    return
                }
            }
        }

        // Hide actions menu when clicking elsewhere
        actionsMenu.isHidden = true
        actionButtons.removeAll()
        buildShipButtons.removeAll()
        buildShipIndices.removeAll()
        isBuildShipMenuOpen = false

        let worldPos = worldLayer.convert(location, from: self)

        // Check End Turn button (HUD, not in world layer)
        if pointInEndTurnButton(location) {
            handleEndTurn()
            return
        }

        // Start panning if clicked on empty space
        isPanning = true
        lastPanPoint = location
        panStartPoint = location
        tooltipLabel.alpha = 0

        // Check fleet clicks first (they're on top of systems)
        var clickedFleet: EntityID?
        for child in fleetLayer.children {
            guard let name = child.name,
                  name.hasPrefix("fleet_") else { continue }

            guard let fleetIDValue = UInt32(String(name.dropFirst(6))) else { continue }
            let fleetID = EntityID(fleetIDValue)
            guard let fleet = sim.state.fleets[fleetID] else { continue }

            let fleetPos = CGPoint(x: child.position.x, y: child.position.y)
            let dist = hypot(worldPos.x - fleetPos.x, worldPos.y - fleetPos.y)
            let radius = CGFloat(max(16, fleet.ships.count * 2 + 12))

            if dist < radius + 10 {
                clickedFleet = fleetID
                break
            }
        }

        if let fleetID = clickedFleet {
            isPanning = false
            handleFleetClick(fleetID, location: location)
            return
        }

        // Check system clicks
        for child in systemLayer.children {
            guard let sysNode = child as? SKShapeNode,
                  let sysName = sysNode.name,
                  sysName.hasPrefix("system_") else { continue }

            let sysPos = CGPoint(x: sysNode.position.x, y: sysNode.position.y)
            let dist = hypot(worldPos.x - sysPos.x, worldPos.y - sysPos.y)

            if dist < 30 {
                isPanning = false
                guard let sysIDValue = UInt32(String(sysName.dropFirst(7))) else { continue }
                handleSystemClick(EntityID(sysIDValue))
                return
            }
        }

        // Clicked empty space — could be a drag to pan
    }

    public override func mouseUp(with event: NSEvent) {
        // Distinguish a click from a pan by total drag distance. A click on
        // empty space (no selection target hit) clears the current selection;
        // a drag pans the map and preserves it.
        if isPanning, let upLoc = self.convertMouseLocation(event) {
            let dist = hypot(upLoc.x - panStartPoint.x, upLoc.y - panStartPoint.y)
            isPanning = false
            if dist < 5 && hasSelection() {
                deselect()
            }
            return
        }
        isPanning = false
    }

    // MARK: - Pan & Zoom

    public override func scrollWheel(with event: NSEvent) {
        let deltaY = event.deltaY

        if deltaY != 0 {
            // Hide any tooltip so it doesn't lag behind the zooming map.
            tooltipLabel.alpha = 0
            let zoomFactor: CGFloat = deltaY > 0 ? 1.15 : 0.87
            let newScale = max(minScale, min(maxScale, currentScale * zoomFactor))

            guard let mousePos = convertMouseLocation(event) else {
                currentScale = newScale
                renderMap()
                return
            }

            // Get world-layer-local position under mouse before zoom
            let localBefore = worldLayer.convert(mousePos, from: self)

            // Apply new scale
            currentScale = newScale
            renderMap()

            // Get world-layer-local position under mouse after zoom
            let localAfter = worldLayer.convert(mousePos, from: self)

            // Adjust panOffset so the point under the mouse stays fixed
            panOffset = CGPoint(
                x: panOffset.x + (localBefore.x - localAfter.x),
                y: panOffset.y + (localBefore.y - localAfter.y)
            )
            renderMap()
        }
    }

    // MARK: - Actions

    private func handleFleetClick(_ fleetID: EntityID, location: CGPoint) {
        guard let fleet = sim.state.fleets[fleetID] else { return }
        guard fleet.faction == sim.state.currentFaction else {
            setStatus("Not your fleet.")
            return
        }

        // A fleet that is already en route can't be re-tasked from the UI
        // (executeMoveFleet rejects it) — tell the player instead of showing
        // routes from its origin, which would be misleading.
        if fleet.destinationSystemID != nil {
            let destName = sim.state.systems[fleet.destinationSystemID!]?.name ?? "its destination"
            setStatus("Fleet is en route to \(destName) — it arrives at End Turn.")
            render()
            return
        }

        // Select the fleet for movement
        selectedFleetID = fleetID
        selectedSystemID = nil  // Clear any system selection
        actionsMenu.isHidden = true
        actionButtons.removeAll()

        let connected = sim.connectedSystems(to: fleet.systemID)
        let sysName = sim.state.systems[fleet.systemID]?.name ?? "unknown"
        setStatus("Fleet selected at \(sysName). \(connected.count) routes available. Click an adjacent system to move.")
        render()
    }

    private func handleSystemClick(_ systemID: EntityID) {
        // If a fleet is selected, try to move it to this system
        if let fleetID = selectedFleetID,
           let fleet = sim.state.fleets[fleetID] {
            let connected = sim.connectedSystems(to: fleet.systemID)
            if connected.contains(systemID) {
                // Warn before committing to a combat the fleet will likely lose.
                if let enemyFleet = sim.state.fleets.values.first(where: {
                    $0.systemID == systemID && $0.faction != fleet.faction
                }) {
                    let mine = sim.fleetValue(fleet)
                    let theirs = sim.fleetValue(enemyFleet)
                    if theirs > mine {
                        let name = sim.state.systems[systemID]?.name ?? "there"
                        setStatus("⚠ Enemy fleet at \(name) looks stronger than yours (\(theirs) vs \(mine)). Moving will trigger combat.")
                    }
                }
                let result = sim.execute(.moveFleet(fleetID: fleetID, targetSystemID: systemID))
                let sysName = sim.state.systems[systemID]?.name ?? "unknown"
                if result != nil {
                    setStatus(result ?? "Fleet en route to \(sysName)")
                }
                selectedFleetID = nil
                _ = sim.updateRevealedSystems()
                render()
                return
            } else {
                setStatus("System not connected to current fleet position.")
                return
            }
        }

        // No fleet selected — show system info and actions menu
        selectedSystemID = systemID

        guard let system = sim.state.systems[systemID] else { return }

        let hasOwnFleet = sim.state.fleets.values.contains {
            $0.systemID == systemID && $0.faction == sim.state.currentFaction
        }

        if hasOwnFleet {
            // Show actions menu for planet-side interactions
            updateActionsMenu()
            var status = "\(system.name) • \(systemTypeLabel(system.type))"
            if let owner = system.owner {
                status += " • \(owner == .compact ? "Compact" : "Dominion")"
            }
            setStatus(status)
            render()
        } else {
            let ownerText: String
            if let owner = system.owner {
                ownerText = owner == .compact ? "Compact" : "Dominion"
            } else {
                ownerText = "Unowned"
            }
            setStatus("\(system.name) • \(systemTypeLabel(system.type)) • \(ownerText)")
            actionsMenu.isHidden = true
            actionButtons.removeAll()
        }
    }

    private func handleAction(_ action: CampaignAction) {
        guard !sim.state.isOver else { return }
        guard sim.state.actionsRemaining > 0 else {
            setStatus("No actions remaining.")
            return
        }

        let result = sim.execute(action)
        let message: String
        if result != nil {
            message = result!
        } else if case .rebuildFleet = action {
            message = "Fleet rebuilt at the home starbase."
        } else {
            message = "Action completed."
        }
        setStatus(message)
        selectedSystemID = nil
        actionsMenu.isHidden = true
        actionButtons.removeAll()
        buildShipButtons.removeAll()
        isBuildShipMenuOpen = false
        render()
    }

    private func showBuildShipSubmenu() {
        buildShipButtons.removeAll()
        buildShipIndices.removeAll()
        isBuildShipMenuOpen = true

        let playerFaction = sim.state.currentFaction
        let playerShips = ShipRoster.all.filter { $0.faction == playerFaction }
        let resources = sim.state.resources[playerFaction] ?? 0

        let submenuW: CGFloat = 280
        let btnH: CGFloat = 36
        let spacing: CGFloat = 5
        let menuHeight = CGFloat(playerShips.count) * btnH + CGFloat(max(0, playerShips.count - 1)) * spacing
        let menuX = size.width / 2 + 120

        // Anchor below the HUD panel, independent of the (possibly hidden)
        // actions menu node, so the submenu is always positioned correctly.
        let hudPanelHeight: CGFloat = 48
        let menuY = hudPanelHeight + 20 + menuHeight / 2

        for (i, ship) in playerShips.enumerated() {
            let shipRosterIndex = ShipRoster.all.firstIndex(of: ship) ?? i
            let btnY = menuY - CGFloat(i) * (btnH + spacing) - menuHeight / 2

            let btnNode = SKNode()
            btnNode.position = CGPoint(x: menuX, y: btnY)
            btnNode.name = "buildshipbtn_\(i)"

            let canAfford = resources >= ship.cost

            let bg = SKShapeNode(rectOf: CGSize(width: submenuW, height: btnH), cornerRadius: 6)
            bg.fillColor = canAfford
                ? NSColor.black.withAlphaComponent(0.6)
                : NSColor.black.withAlphaComponent(0.3)
            bg.strokeColor = canAfford ? NSColor.white : NSColor.gray
            bg.lineWidth = 1
            btnNode.addChild(bg)

            let label = SKLabelNode()
            label.fontName = ".AppleSystemUIFont"
            label.fontSize = 11
            label.fontColor = canAfford ? NSColor.white.withAlphaComponent(0.85) : NSColor.gray
            label.text = "\(ship.name) (\(ship.species)) — \(ship.cost) credits"
            label.position = CGPoint(x: 0, y: 3)
            label.horizontalAlignmentMode = .center
            btnNode.addChild(label)

            let costLabel = SKLabelNode()
            costLabel.fontName = ".AppleSystemUIFont"
            costLabel.fontSize = 9
            costLabel.fontColor = canAfford ? NSColor.systemGreen.withAlphaComponent(0.7) : NSColor.red.withAlphaComponent(0.7)
            costLabel.text = canAfford ? "BUILD" : "CANT AFFORD"
            costLabel.position = CGPoint(x: 0, y: -12)
            costLabel.horizontalAlignmentMode = .center
            btnNode.addChild(costLabel)

            actionsMenu.addChild(btnNode)
            buildShipButtons.append(btnNode)
            buildShipIndices.append(shipRosterIndex)
        }
    }

    private func handleEndTurn() {
        onEndTurn?()
        selectedFleetID = nil
        selectedSystemID = nil
        actionsMenu.isHidden = true
        actionButtons.removeAll()
        render()
    }

    private func pointInEndTurnButton(_ point: CGPoint) -> Bool {
        let btnW: CGFloat = 110
        let btnH: CGFloat = 32
        let panelHeight: CGFloat = 48
        let btnCX = size.width - btnW / 2 - 12
        let btnCY = panelHeight / 2
        let rect = CGRect(x: btnCX - btnW / 2, y: btnCY - btnH / 2, width: btnW, height: btnH)
        return rect.contains(point)
    }

    // MARK: - Helpers

    private func setStatus(_ text: String) {
        statusLabel.fontName = "Helvetica Neue"
        statusLabel.fontSize = 14
        statusLabel.text = text
        statusLabel.fontColor = text.contains("⚔️") || text.lowercased().contains("combat")
            ? NSColor.systemRed
            : (text.contains("!") && !text.lowercased().contains("route")
                ? NSColor.systemYellow
                : NSColor.gray.withAlphaComponent(0.8))
    }

    private func systemTypeLabel(_ type: SystemType) -> String {
        switch type {
        case .life: return "Life World"
        case .mineral: return "Mineral World"
        case .dead: return "Dead World"
        }
    }
    
    /// Generate a compact summary of fleet composition for tooltips.
    private func summarizeFleetShips(_ fleet: FleetUnit) -> String {
        let total = fleet.ships.count
        if total == 0 { return "Empty" }
        
        // Group by ship type
        var counts: [String: Int] = [:]
        var totalCrew = 0
        var maxCrew = 0
        for entry in fleet.ships {
            let idx = max(0, min(entry.shipIndex, ShipRoster.all.count - 1))
            let def = ShipRoster.all[idx]
            counts[def.name, default: 0] += 1
            totalCrew += entry.crew
            maxCrew += def.maxCrew
        }
        
        let crewStatus = totalCrew >= maxCrew ? "full" : "\(totalCrew)/\(maxCrew)"
        var parts: [String] = []
        for (name, count) in counts.sorted(by: { $0.key < $1.key }) {
            parts.append("\(count)x \(name)")
        }
        return parts.joined(separator: ", ") + " [\(crewStatus)]"
    }

    /// Returns available action hints for a system when the player has a fleet there.
    private func actionHintsFor(_ system: StarSystem) -> [String] {
        var hints: [String] = []
        switch system.type {
        case .life:
            if !system.hasColony {
                hints.append("Click to Colonize")
            }
        case .mineral:
            if !system.hasMine {
                hints.append("Click to Build Mine")
            }
        case .dead:
            if !system.isFortified {
                hints.append("Click to Fortify")
            }
        }
        if system.hasColony, system.owner == sim.state.currentFaction {
            hints.append("Click to Recruit Crew")
        }
        return hints
    }

    private func systemColor(_ system: StarSystem) -> NSColor {
        guard let owner = system.owner else {
            switch system.type {
            case .life: return NSColor.systemGreen.withAlphaComponent(0.7)
            case .mineral: return NSColor.systemYellow.withAlphaComponent(0.7)
            case .dead: return NSColor.gray.withAlphaComponent(0.5)
            }
        }
        return owner == .compact
            ? NSColor.systemGreen
            : NSColor.systemRed
    }

    private func computeMapBounds() -> CGRect {
        var minX: Double = .infinity
        var minY: Double = .infinity
        var maxX: Double = -.infinity
        var maxY: Double = -.infinity

        for system in sim.state.systems.values {
            minX = min(minX, system.position.x)
            minY = min(minY, system.position.y)
            maxX = max(maxX, system.position.x)
            maxY = max(maxY, system.position.y)
        }

        let margin: Double = 120
        return CGRect(
            x: minX - margin,
            y: minY - margin,
            width: (maxX - minX) + 2 * margin,
            height: (maxY - minY) + 2 * margin
        )
    }

    private func computeScale(_ bounds: CGRect) -> Double {
        // Force the map to be larger than the viewport to require scrolling.
        // Scale to 75% of viewport (so the map is always bigger than screen).
        let availableW = (Double(size.width) - mapMargin * 2) * 0.75
        let availableH = (Double(size.height) - mapMargin * 2 - 60) * 0.75
        let scaleToFit = min(availableW / bounds.width, availableH / bounds.height)
        // Also enforce a minimum scale so the map isn't too zoomed in
        let minScaleForMap = min(availableW / bounds.width, availableH / bounds.height)
        return max(scaleToFit, minScaleForMap * 0.85)
    }

     private func worldToScreen(_ pos: Vec2) -> CGPoint {
        // Outputs raw world-space coordinates. The worldLayer's scale and
        // position transform these to screen space for pan/zoom.
        return CGPoint(x: CGFloat(pos.x), y: CGFloat(pos.y))
    }

    private func fleetDestinationScreen(fleet: FleetUnit) -> CGPoint? {
        guard let destID = fleet.destinationSystemID else { return nil }
        guard let dest = sim.state.systems[destID] else { return nil }
        return worldToScreen(dest.position)
    }

    private func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<sides {
            let angle = CGFloat(i) / CGFloat(sides) * 2 * .pi
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}