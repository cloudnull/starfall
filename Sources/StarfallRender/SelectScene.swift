import AppKit
import SpriteKit
import StarfallCore
import StarfallData
import StarfallMelee

/// Selection result from the select screen.
@MainActor
public struct SelectResult: Sendable {
    public let ship1: ShipDefinition
    public let ship2: ShipDefinition
    public let aiDifficulty: AIDifficulty? // nil = two-player
    public let isDemoReplay: Bool
    public let savedReplay: MeleeReplay? // non-nil = play saved replay

    public init(ship1: ShipDefinition, ship2: ShipDefinition, aiDifficulty: AIDifficulty?, isDemoReplay: Bool = false, savedReplay: MeleeReplay? = nil) {
        self.ship1 = ship1
        self.ship2 = ship2
        self.aiDifficulty = aiDifficulty
        self.isDemoReplay = isDemoReplay
        self.savedReplay = savedReplay
    }
}

/// SpriteKit scene for ship selection.
/// Shows both factions' rosters with clickable ship buttons.
@MainActor
public final class SelectScene: SKScene {
    
    /// Called when both ships are selected and the player chooses to launch.
    public var onLaunch: ((SelectResult) -> Void)?
    /// Called when the player leaves the select screen (Back button / ESC).
    public var onBack: (() -> Void)?
    public var onUIAction: (() -> Void)?

    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil
    
    /// Saved replays available for playback.
    private var savedReplays: [MeleeReplay] = []
    private var selectedReplayIndex: Int = 0

    public override func keyDown(with event: NSEvent) {
        // ESC returns to the main menu (spec: every non-game screen has a back).
        if event.keyCode == 53 {
            onBack?()
            return
        }
        onKeyEvent?(event.keyCode, true)
    }

    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private let compactShips = ShipRoster.compact
    private let dominionShips = ShipRoster.dominion

    private let buttonLayer = SKNode()
    private let labelLayer = SKNode()
    private let modeLayer = SKNode()
    private let statusLabel = SKLabelNode()
    private var launchBtn: SKSpriteNode?
    private let p1HeaderLabel = SKLabelNode()
    private let p2HeaderLabel = SKLabelNode()

    /// Which player is selecting next: 1 = Compact, 2 = Dominion.
    private var selectingPlayer: Int = 1
    
    /// Ships already picked.
    private var pickedShip1: ShipDefinition?
    private var pickedShip2: ShipDefinition?
    
    /// Selected AI difficulty (nil = two-player).
    private var aiDifficulty: AIDifficulty? = .medium
    
    public override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = NSColor.black
        buttonLayer.zPosition = 10
        addChild(buttonLayer)
        labelLayer.zPosition = 20
        addChild(labelLayer)
        modeLayer.zPosition = 30
        addChild(modeLayer)
        setupUI()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    /// Set saved replays for playback. Call before presenting.
    public func setSavedReplays(_ replays: [MeleeReplay]) {
        savedReplays = replays
        selectedReplayIndex = max(0, replays.count - 1)
        updateReplayButton()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
// Title.
        let title = SKLabelNode()
        title.fontName = "Helvetica Neue"
        title.fontSize = 28
        title.fontColor = NSColor.white
        title.text = "STARFALL"
        title.position = CGPoint(x: size.width / 2, y: size.height - 50)
        labelLayer.addChild(title)

        // Subtitle.
        let subtitle = SKLabelNode()
        subtitle.fontName = "Helvetica Neue"
        subtitle.fontSize = 14
        subtitle.fontColor = NSColor.gray
        subtitle.text = "SELECT YOUR SHIPS"
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 80)
        labelLayer.addChild(subtitle)

        // Faction headers.
        p1HeaderLabel.fontName = "Helvetica Neue"
        p1HeaderLabel.fontSize = 16
        p1HeaderLabel.fontColor = NSColor.systemGreen
        p1HeaderLabel.text = "KAELAN COMPACT (You)"
        p1HeaderLabel.position = CGPoint(x: size.width * 0.25, y: size.height - 110)
        labelLayer.addChild(p1HeaderLabel)

        p2HeaderLabel.fontName = "Helvetica Neue"
        p2HeaderLabel.fontSize = 16
        p2HeaderLabel.fontColor = NSColor.systemRed
        p2HeaderLabel.text = "VEXARI DOMINION (AI)"
        p2HeaderLabel.position = CGPoint(x: size.width * 0.75, y: size.height - 110)
        labelLayer.addChild(p2HeaderLabel)

        // Ship buttons — start below headers with 40px gap.
        let startY: CGFloat = CGFloat(size.height) - 150
        let buttonW: CGFloat = 150
        let buttonH: CGFloat = 36
        let spacing: CGFloat = 8

        // Compact ships (left column).
        for (i, ship) in compactShips.enumerated() {
            let btn = createShipButton(
                ship: ship,
                faction: .compact,
                x: size.width * 0.25 - buttonW / 2,
                y: startY - CGFloat(i) * (buttonH + spacing),
                width: buttonW,
                height: buttonH
            )
            buttonLayer.addChild(btn)
        }

        // Dominion ships (right column).
        for (i, ship) in dominionShips.enumerated() {
            let btn = createShipButton(
                ship: ship,
                faction: .dominion,
                x: size.width * 0.75 - buttonW / 2,
                y: startY - CGFloat(i) * (buttonH + spacing),
                width: buttonW,
                height: buttonH
            )
            buttonLayer.addChild(btn)
        }

        // Status label — between ship columns and mode buttons.
        statusLabel.fontName = "Helvetica Neue"
        statusLabel.fontSize = 14
        statusLabel.fontColor = NSColor.yellow
        statusLabel.text = "Choose a Compact ship (Player 1)"
        statusLabel.position = CGPoint(x: size.width / 2, y: 200)
        labelLayer.addChild(statusLabel)

        // Back button — top-left, clear of the ship columns.
        let backBtn = createModeButton(text: "BACK", width: 90, height: 30,
                                       color: NSColor.systemGray, name: "back")
        backBtn.position = CGPoint(x: 70, y: size.height - 40)
        modeLayer.addChild(backBtn)

        // Mode & difficulty buttons at bottom.
        setupModeButtons()

        // Reflect the implicit default (1P + Medium AI) so the UI and the
        // actual state agree on entry.
        updateP2Header(isAI: true)
        if let oneP = modeLayer.childNode(withName: "mode_1p") as? SKSpriteNode {
            highlightModeButton(oneP)
        }
    }
    
    // MARK: - Ship Button

    private func createShipButton(
        ship: ShipDefinition,
        faction: Faction,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> SKSpriteNode {
        let color: NSColor = faction == .compact ? NSColor.systemGreen : NSColor.systemRed
        let bgColor = color.withAlphaComponent(0.15)

        let btn = SKSpriteNode(color: bgColor, size: CGSize(width: width, height: height))
        btn.position = CGPoint(x: x + width / 2, y: y + height / 2)
        btn.name = "ship_\(ship.name)"

        let border = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        border.fillColor = .clear
        border.strokeColor = color.withAlphaComponent(0.5)
        border.lineWidth = 1
        btn.addChild(border)

        let nameLbl = SKLabelNode()
        nameLbl.fontName = "Helvetica Neue"
        nameLbl.fontSize = 12
        nameLbl.fontColor = NSColor.white
        nameLbl.text = ship.name
        nameLbl.position = CGPoint(x: 0, y: 4)
        btn.addChild(nameLbl)

        let statsLbl = SKLabelNode()
        statsLbl.fontName = "Helvetica Neue"
        statsLbl.fontSize = 9
        statsLbl.fontColor = NSColor.gray
        statsLbl.text = "C:\(ship.startingCrew) E:\(ship.startingEnergy) Cost:\(ship.cost)"
        statsLbl.position = CGPoint(x: 0, y: -8)
        btn.addChild(statsLbl)

        return btn
    }

    // MARK: - Mode Buttons

private func setupModeButtons() {
        let btnW: CGFloat = 100
        let btnH: CGFloat = 30
        let centerX = size.width / 2

        // Row 1 (top): mode buttons
        let row1Y: CGFloat = 50

        let onePBtn = createModeButton(text: "1P + AI", width: btnW, height: btnH,
                                       color: NSColor.systemBlue, name: "mode_1p")
        onePBtn.position = CGPoint(x: centerX - 160, y: row1Y)
        modeLayer.addChild(onePBtn)

        let launchBtn = createModeButton(text: "LAUNCH", width: btnW, height: btnH,
                                         color: NSColor.yellow, name: "launch")
        launchBtn.position = CGPoint(x: centerX, y: row1Y)
        self.launchBtn = launchBtn
        modeLayer.addChild(launchBtn)
        setLaunchEnabled(false)

        let twoPBtn = createModeButton(text: "2P LOCAL", width: btnW, height: btnH,
                                       color: NSColor.systemGreen, name: "mode_2p")
        twoPBtn.position = CGPoint(x: centerX + 160, y: row1Y)
        modeLayer.addChild(twoPBtn)

        // Row 2 (bottom): difficulty buttons + DEMO
        let diffBtnW: CGFloat = 80
        let diffH: CGFloat = 24
        let row2Y: CGFloat = 18

        let easyBtn = createModeButton(text: "EASY", width: diffBtnW, height: diffH,
                                       color: NSColor.systemGreen, name: "diff_easy")
        easyBtn.position = CGPoint(x: centerX - 140, y: row2Y)
        modeLayer.addChild(easyBtn)

        let medBtn = createModeButton(text: "MEDIUM", width: diffBtnW, height: diffH,
                                      color: NSColor.systemOrange, name: "diff_medium")
        medBtn.position = CGPoint(x: centerX - 20, y: row2Y)
        modeLayer.addChild(medBtn)
        highlightDifficultyButton(medBtn)

        let hardBtn = createModeButton(text: "HARD", width: diffBtnW, height: diffH,
                                       color: NSColor.systemRed, name: "diff_hard")
        hardBtn.position = CGPoint(x: centerX + 100, y: row2Y)
        modeLayer.addChild(hardBtn)

        let demoBtn = createModeButton(text: "DEMO", width: 80, height: diffH,
                                       color: NSColor.systemPurple, name: "demo")
        demoBtn.position = CGPoint(x: centerX + 210, y: row2Y)
        modeLayer.addChild(demoBtn)

        let replayBtn = createModeButton(text: "REPLAY", width: 80, height: diffH,
                                         color: NSColor.systemTeal, name: "replay")
        replayBtn.position = CGPoint(x: centerX + 310, y: row2Y)
        replayBtn.isHidden = true
        modeLayer.addChild(replayBtn)

        let replayCycleBtn = createModeButton(text: "< >", width: 40, height: diffH,
                                              color: NSColor.systemGray, name: "replay_cycle")
        replayCycleBtn.position = CGPoint(x: centerX + 360, y: row2Y)
        replayCycleBtn.isHidden = true
        modeLayer.addChild(replayCycleBtn)
    }
    
    private func createModeButton(text: String, width: CGFloat, height: CGFloat,
                                  color: NSColor, name: String) -> SKSpriteNode {
        let btn = SKSpriteNode(color: color.withAlphaComponent(0.2), size: CGSize(width: width, height: height))
        btn.name = name
        
        let border = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        border.fillColor = .clear
        border.strokeColor = color.withAlphaComponent(0.6)
        border.lineWidth = 1
        btn.addChild(border)
        
        let lbl = SKLabelNode()
        lbl.fontName = "Helvetica Neue"
        lbl.fontSize = 11
        lbl.fontColor = NSColor.white
        lbl.text = text
        btn.addChild(lbl)
        
        return btn
    }
    
    private func highlightDifficultyButton(_ btn: SKSpriteNode) {
        if let border = btn.children.first as? SKShapeNode {
            border.strokeColor = NSColor.white
            border.lineWidth = 2
        }
    }
    
    private func clearDifficultyHighlights() {
        for child in modeLayer.children {
            guard let name = child.name, name.hasPrefix("diff_") else { continue }
            if let border = child.children.first as? SKShapeNode {
                let origColor: NSColor
                switch name {
                case "diff_easy": origColor = NSColor.systemGreen
                case "diff_hard": origColor = NSColor.systemRed
                default: origColor = NSColor.systemOrange
                }
                border.strokeColor = origColor.withAlphaComponent(0.6)
                border.lineWidth = 1
            }
        }
    }
    
    private func updateReplayButton() {
        guard let replayBtn = modeLayer.childNode(withName: "replay") as? SKSpriteNode,
              let cycleBtn = modeLayer.childNode(withName: "replay_cycle") as? SKSpriteNode else { return }
        
        if savedReplays.isEmpty {
            replayBtn.isHidden = true
            cycleBtn.isHidden = true
            return
        }
        
        replayBtn.isHidden = false
        cycleBtn.isHidden = savedReplays.count < 2
        
        let replay = savedReplays[selectedReplayIndex]
        let s1Name = replay.ship1Index >= 0 && replay.ship1Index < ShipRoster.all.count
            ? ShipRoster.all[replay.ship1Index].name : "?"
        let s2Name = replay.ship2Index >= 0 && replay.ship2Index < ShipRoster.all.count
            ? ShipRoster.all[replay.ship2Index].name : "?"
        if let lbl = replayBtn.children.first as? SKLabelNode {
            lbl.text = "\(s1Name) vs \(s2Name)"
        }
    }
    
    // MARK: - Touch Handling

public override func mouseDown(with event: NSEvent) {
        guard let scenePt = self.convertMouseLocation(event) else { return }

        // Hit-test mode layer first (buttons, difficulty, launch, demo, replay).
        for child in modeLayer.children {
            guard let btn = child as? SKSpriteNode,
                  let name = btn.name else { continue }
            guard SKScene.pointInSprite(scenePt, sprite: btn) else { continue }

            if name == "back" {
                onUIAction?()
                onBack?()
            } else if name == "mode_1p" {
                onUIAction?()
                aiDifficulty = aiDifficulty ?? .medium
                pickedShip1 = nil
                pickedShip2 = nil
                selectingPlayer = 1
                setLaunchEnabled(false)
                updateP2Header(isAI: true)
                statusLabel.text = "1P mode. Choose a Compact ship, then a Dominion ship."
                highlightModeButton(btn)
            } else if name == "mode_2p" {
                onUIAction?()
                aiDifficulty = nil
                pickedShip1 = nil
                pickedShip2 = nil
                selectingPlayer = 1
                setLaunchEnabled(false)
                updateP2Header(isAI: false)
                statusLabel.text = "2P mode. Player 1 picks a Compact ship, Player 2 a Dominion ship."
                highlightModeButton(btn)
            } else if name == "diff_easy" {
                onUIAction?()
                aiDifficulty = .easy
                clearDifficultyHighlights()
                highlightDifficultyButton(btn)
            } else if name == "diff_medium" {
                onUIAction?()
                aiDifficulty = .medium
                clearDifficultyHighlights()
                highlightDifficultyButton(btn)
            } else if name == "diff_hard" {
                onUIAction?()
                aiDifficulty = .hard
                clearDifficultyHighlights()
                highlightDifficultyButton(btn)
            } else if name == "launch" {
                onUIAction?()
                if let s1 = pickedShip1, let s2 = pickedShip2 {
                    let result = SelectResult(ship1: s1, ship2: s2, aiDifficulty: aiDifficulty)
                    onLaunch?(result)
                }
            } else if name == "demo" {
                onUIAction?()
                let result = SelectResult(ship1: compactShips[0], ship2: dominionShips[0], aiDifficulty: nil, isDemoReplay: true)
                onLaunch?(result)
            } else if name == "replay" {
                onUIAction?()
                guard !savedReplays.isEmpty else { return }
                let replay = savedReplays[selectedReplayIndex]
                let s1 = replay.ship1Index >= 0 && replay.ship1Index < ShipRoster.all.count
                    ? ShipRoster.all[replay.ship1Index] : compactShips[0]
                let s2 = replay.ship2Index >= 0 && replay.ship2Index < ShipRoster.all.count
                    ? ShipRoster.all[replay.ship2Index] : dominionShips[0]
                let result = SelectResult(ship1: s1, ship2: s2, aiDifficulty: nil, savedReplay: replay)
                onLaunch?(result)
            } else if name == "replay_cycle" {
                onUIAction?()
                selectedReplayIndex = (selectedReplayIndex + 1) % savedReplays.count
                updateReplayButton()
            }
            return
        }

        // Hit-test ship buttons.
        for child in buttonLayer.children {
            guard let btn = child as? SKSpriteNode,
                  let name = btn.name,
                  name.hasPrefix("ship_") else { continue }
            guard SKScene.pointInSprite(scenePt, sprite: btn) else { continue }

            let shipName = String(name.dropFirst(5))
            guard let ship = ShipRoster.lookup(named: shipName) else { return }
            onUIAction?()
            handleShipSelect(ship: ship)
            return
        }
    }
    
    private func highlightModeButton(_ btn: SKSpriteNode) {
        for child in modeLayer.children {
            guard let name = child.name, (name == "mode_1p" || name == "mode_2p") else { continue }
            if let border = child.children.first as? SKShapeNode {
                border.lineWidth = 1
                if name == "mode_1p" {
                    border.strokeColor = NSColor.systemBlue.withAlphaComponent(0.6)
                } else {
                    border.strokeColor = NSColor.systemGreen.withAlphaComponent(0.6)
                }
            }
        }
        if let border = btn.children.first as? SKShapeNode {
            border.lineWidth = 3
            border.strokeColor = NSColor.white
        }
    }
    
    private func updateP2Header(isAI: Bool) {
        p2HeaderLabel.text = isAI ? "VEXARI DOMINION (AI)" : "VEXARI DOMINION (Player 2)"
        p1HeaderLabel.text = isAI ? "KAELAN COMPACT (You)" : "KAELAN COMPACT (Player 1)"
    }

    /// Enable/disable the LAUNCH button based on whether both ships are picked.
    private func setLaunchEnabled(_ enabled: Bool) {
        guard let launchBtn else { return }
        launchBtn.alpha = enabled ? 1.0 : 0.4
        if let border = launchBtn.children.first as? SKShapeNode {
            border.strokeColor = enabled ? NSColor.white : NSColor.gray.withAlphaComponent(0.4)
            border.lineWidth = enabled ? 2 : 1
        }
    }
    
    private func handleShipSelect(ship: ShipDefinition) {
        if selectingPlayer == 1 {
            guard ship.faction == .compact else {
                statusLabel.text = "Player 1 must choose a Compact (left) ship."
                return
            }
            pickedShip1 = ship
            selectingPlayer = 2
            statusLabel.text = "Player 2: Choose a Dominion ship"
            highlightPicked(ship: ship, player: 1)
        } else if selectingPlayer == 2 {
            guard ship.faction == .dominion else {
                statusLabel.text = "Player 2 must choose a Dominion (right) ship."
                return
            }
            pickedShip2 = ship
            selectingPlayer = 0
            statusLabel.text = "\(pickedShip1?.name ?? "?") vs \(ship.name) — Press LAUNCH"
            highlightPicked(ship: ship, player: 2)
        }
        setLaunchEnabled(pickedShip1 != nil && pickedShip2 != nil)
    }
    
    private func highlightPicked(ship: ShipDefinition, player: Int) {
        let color: NSColor = player == 1 ? NSColor.systemGreen : NSColor.systemRed
        for child in buttonLayer.children {
            guard let btn = child as? SKSpriteNode,
                  let btnName = btn.name,
                  btnName == "ship_\(ship.name)" else { continue }
            
            if let border = btn.children.first as? SKShapeNode {
                border.strokeColor = color
                border.lineWidth = 3
            }
        }
    }
}