import AppKit
import SpriteKit
import StarfallAI
import StarfallAudio
import StarfallCampaign
import StarfallCore
import StarfallData
import StarfallMelee
import StarfallInput
import StarfallRender

/// Monotonic clock wrapper for accurate delta-time measurement.
private func monotonicTime() -> TimeInterval {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1_000_000_000
}

/// High-level game controller managing screen flow and mode switching.
@MainActor
final class GameController: NSObject {
    
    enum Screen {
        case mainMenu
        case settings
        case tutorial
        case meleeSelect
        case meleePlaying
        case meleeMatchOver
        case campaign
        case briefing
        case cinematicVictory
        case cinematicDefeat
    }
    
    private let window: NSWindow
    private let gameView: SKView
    private var displayLink: Any?
    private var gameTimer: Timer?
    private var lastLoopTimestamp: TimeInterval = 0
    private var currentScreen: Screen = .mainMenu
    
    // Arena for melee.
    private let arena: ArenaState
    
    // Melee state.
    private var simulation: MeleeSimulation?
    private var renderer: MeleeRenderer?
    private var selectScene: SelectScene?
    private var inputProcessor = InputProcessor()
    private let fixedTimestep = FixedTimestep()
    private let audio = AudioEngine()
    private var aiPilot: AIPilot?
    private var isMatchOver: Bool = false
    private var isPaused: Bool = false
    private var matchModeStr: String = ""
    private var lastThrustP1: Bool = false
    private var lastThrustP2: Bool = false

    // Replay state.
    private var replayPlayer: MeleeReplayPlayer?
    private var isReplayMode: Bool = false
    private var replayRecorder: MeleeReplayRecorder?
    private var savedReplays: [MeleeReplay] = []
    private var replaySpeedMode: ReplaySpeedMode = .normal

    /// Playback speed modes for replay.
    enum ReplaySpeedMode: CaseIterable {
        case `step`   // Space advances one frame at a time
        case normal   // 1x — one frame per tick
        case fast2x   // 2x — two frames per tick
        case fast4x   // 4x — four frames per tick
        case fast8x   // 8x — eight frames per tick

        var frameCount: Int {
            switch self {
            case .step: return 0
            case .normal: return 1
            case .fast2x: return 2
            case .fast4x: return 4
            case .fast8x: return 8
            }
        }

        var displayName: String {
            switch self {
            case .step: return "STEP"
            case .normal: return "1x"
            case .fast2x: return "2x"
            case .fast4x: return "4x"
            case .fast8x: return "8x"
            }
        }
    }

    // Campaign state.
    private var campaignSim: CampaignSimulation?
    private var campaignScene: CampaignScene?
    private var briefingScene: BriefingScene?
    private var victoryScene: VictoryScene?
    private var defeatScene: DefeatScene?
    
    // Pending combat before dropping to melee.
    private var pendingCombatFleets: (attacker: EntityID, defender: EntityID)?
    
    /// Tracks campaign turn processing state when combat interrupts the flow.
    /// 0 = not in progress, 1 = waiting for AI turn after combat, 2 = waiting for second endTurn after AI combat.
    private var campaignTurnStep: Int = 0
    
    private let replaysFileURL: URL
    private let campaignSaveFileURL: URL
    
    init(arena: ArenaState, windowSize: CGSize = CGSize(width: 1440, height: 810)) {
        self.arena = arena
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Starfall", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.replaysFileURL = appDir.appendingPathComponent("replays.json")
        self.campaignSaveFileURL = appDir.appendingPathComponent("campaign.json")

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Starfall"
        window.center()
        // Enable mouse-moved events for tooltips and hover feedback.
        (window as AnyObject).setValue(true, forKey: "acceptsMouseMovedEvents")

        gameView = SKView(frame: window.contentView!.bounds)
        gameView.ignoresSiblingOrder = true
        gameView.translatesAutoresizingMaskIntoConstraints = false
        if let contentView = window.contentView {
            contentView.addSubview(gameView)
            NSLayoutConstraint.activate([
                gameView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                gameView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                gameView.topAnchor.constraint(equalTo: contentView.topAnchor),
                gameView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        super.init()
        loadSavedReplays()
        showMainMenu()

        // Use Timer for proper main run loop integration with SpriteKit.
        // Timer fires on the main run loop (not main dispatch queue), allowing
        // SpriteKit's CADisplayLink to interleave rendering between ticks.
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.gameLoopTick()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Ensure the window becomes key on the next run loop iteration.
        DispatchQueue.main.async {
            self.window.makeKeyAndOrderFront(nil)
            self.window.makeFirstResponder(self.gameView)
        }
        window.makeFirstResponder(gameView)
        // Force the SKView to accept mouse-moved events.
        (window as AnyObject).setValue(true, forKey: "acceptsMouseMovedEvents")
        
    }
    
// MARK: - Input

    /// Helper: attach keyboard event forwarding to any scene.
    private func wireSceneKeyboard(_ onKeyEvent: inout ((UInt16, Bool) -> Void)?) {
        onKeyEvent = { [self] keyCode, isDown in
            if isDown {
                self.inputProcessor.keyDown(keyCode: keyCode)
            } else {
                self.inputProcessor.keyUp(keyCode: keyCode)
            }
        }
    }
    
    // MARK: - Screens
    
    /// A full-screen overlay for fade transitions between scenes.
    private let fadeOverlay: SKSpriteNode = {
        let node = SKSpriteNode(color: NSColor.black, size: kSceneSize)
        node.alpha = 0
        return node
    }()
    
    /// Present a scene with a fade transition.
    //
    // Default to .resizeFill: menu/select/tutorial/cinematic scenes hit-test
    // mouse clicks with SKScene.pointInSprite against node *layout* positions,
    // and convertMouseLocation (convertPoint(fromView:)) does NOT undo the
    // .aspectFit letterbox scale. Under .aspectFit the returned point is
    // mis-scaled, so clicks miss every button. .resizeFill makes scene
    // coordinates map 1:1 to the view, which is what the hit-testing assumes.
    // This is the same class of bug as BUG-1 in docs/resolved-BUG_REPORT.md,
    // previously fixed only for the campaign scene.
    private func presentSceneWithFade(_ scene: SKScene, scaleMode: SKSceneScaleMode = .resizeFill) {
        gameView.ignoresSiblingOrder = true
        scene.scaleMode = scaleMode
        
        // Fade transition. The overlay must live in the *presented* scene for
        // its SKActions to run — SpriteKit only executes actions on nodes in the
        // active scene. So: fade the current scene's overlay to black, swap the
        // scene, then attach the same overlay to the new scene and fade it in.
        fadeOverlay.removeFromParent()
        
        if let current = gameView.scene {
            fadeOverlay.alpha = 0
            fadeOverlay.zPosition = 9999
            current.addChild(fadeOverlay)
            
            let fadeOut = SKAction.fadeAlpha(to: 1, duration: 0.25)
            let swap = SKAction.run {
                self.gameView.presentScene(scene)
                // Move the overlay into the new scene (still alpha 1) so we can
                // fade in over it.
                self.fadeOverlay.removeFromParent()
                scene.addChild(self.fadeOverlay)
                self.fadeOverlay.zPosition = 9999
            }
            let fadeIn = SKAction.fadeAlpha(to: 0, duration: 0.25)
            
            fadeOverlay.run(SKAction.sequence([fadeOut, swap, fadeIn])) {
                self.fadeOverlay.removeFromParent()
            }
        } else {
            gameView.presentScene(scene)
        }
    }
    
    private func showMainMenu() {
        currentScreen = .mainMenu
        inputProcessor.clear()
        simulation = nil
        renderer = nil
        aiPilot = nil
        selectScene = nil
        
        let menu = MainMenuScene(size: kSceneSize)
        menu.onSelectMelee = { [self] in
            self.showMeleeSelect()
        }
        menu.onSelectCampaign = { [self] difficulty in
            showCampaign(aiDifficulty: difficulty)
        }
        menu.onSettings = { [self] in
            self.showSettings()
        }
        menu.onTutorial = { [self] in
            self.showTutorial()
        }
        menu.onNewCampaign = { [self] difficulty in
            startNewCampaign(aiDifficulty: difficulty)
        }
        menu.hasSavedCampaign = (loadCampaignSave() != nil)
        menu.onUIAction = { [self] in
            self.audio.play(.uiClick)
        }
        wireSceneKeyboard(&menu.onKeyEvent)
        presentSceneWithFade(menu)
        audio.playMusic(.menu)
    }
    
    // MARK: - Settings
    
    func showSettings() {
        currentScreen = .settings
        inputProcessor.clear()
        simulation = nil
        renderer = nil
        aiPilot = nil
        selectScene = nil
        
        let settings = SettingsScene(size: kSceneSize)
        settings.audio = audio
        settings.applySettings(to: audio)
        settings.onBack = { [self] in
            self.showMainMenu()
        }
        settings.onClearSave = { [self] in
            try? FileManager.default.removeItem(at: self.campaignSaveFileURL)
            self.audio.play(.uiClick)
        }
        settings.onUIAction = { [self] in
            self.audio.play(.uiClick)
        }
        settings.onKeyBindings = { [self] in
            self.showKeyBindings()
        }
        wireSceneKeyboard(&settings.onKeyEvent)
        presentSceneWithFade(settings)
        audio.playMusic(.menu)
    }
    
    // MARK: - Key Bindings
    
    func showKeyBindings() {
        currentScreen = .settings
        inputProcessor.clear()
        simulation = nil
        renderer = nil
        aiPilot = nil
        selectScene = nil
        
        let scene = KeyBindingsScene(size: kSceneSize)
        scene.onBack = { [self] in
            // Reload input processor with saved bindings.
            self.inputProcessor = InputProcessor(p1: loadSavedKeyBindings())
            self.showSettings()
        }
        scene.onUIAction = { [self] in
            self.audio.play(.uiClick)
        }
        wireSceneKeyboard(&scene.onKeyEvent)
        presentSceneWithFade(scene)
    }
    
    /// Loads saved key bindings from UserDefaults, falling back to defaults.
    private func loadSavedKeyBindings() -> MeleeKeyBindings {
        if let data = UserDefaults.standard.data(forKey: "starfall_key_bindings"),
           let saved = try? JSONDecoder().decode(MeleeKeyBindings.self, from: data) {
            return saved
        }
        return MeleeKeyBindings()
    }
    
    // MARK: - Tutorial
    
    private func showTutorial() {
        currentScreen = .tutorial
        inputProcessor.clear()
        simulation = nil
        renderer = nil
        aiPilot = nil
        selectScene = nil
        
        let tutorial = TutorialScene(size: kSceneSize)
        tutorial.onBack = { [self] in
            self.showMainMenu()
        }
        tutorial.onUIAction = { [self] in
            self.audio.play(.uiClick)
        }
        wireSceneKeyboard(&tutorial.onKeyEvent)
        presentSceneWithFade(tutorial)
    }
    
    private func startNewCampaign(aiDifficulty: AIDifficulty = .medium) {
        // Delete any existing save.
        try? FileManager.default.removeItem(at: campaignSaveFileURL)
        campaignSim = nil
        showCampaign(aiDifficulty: aiDifficulty)
    }
    
    // MARK: - Melee Select
    
    private func showMeleeSelect() {
        currentScreen = .meleeSelect
        inputProcessor.clear()
        simulation = nil
        renderer = nil
        aiPilot = nil
        
        let select = SelectScene(size: kSceneSize)
        select.setSavedReplays(savedReplays)
        select.onLaunch = { [self] result in
            self.startMeleeMatch(result: result)
        }
        select.onBack = { [self] in
            self.showMainMenu()
        }
        select.onUIAction = { [self] in
            self.audio.play(.uiClick)
        }
        wireSceneKeyboard(&select.onKeyEvent)
        selectScene = select
        presentSceneWithFade(select)
        audio.playMusic(.menu)
    }
    
    // MARK: - Replay Persistence
    
    private func loadSavedReplays() {
        guard let data = try? Data(contentsOf: replaysFileURL) else { return }
        guard let replays = try? JSONDecoder().decode([MeleeReplay].self, from: data) else { return }
        savedReplays = replays
    }
    
    private func saveReplaysToDisk() {
        guard let data = try? JSONEncoder().encode(savedReplays) else { return }
        try? data.write(to: replaysFileURL)
    }
    
    // MARK: - Campaign Persistence
    
    private func loadCampaignSave() -> CampaignState? {
        guard let data = try? Data(contentsOf: campaignSaveFileURL) else { return nil }
        guard let state = try? JSONDecoder().decode(CampaignState.self, from: data) else { return nil }
        // Don't load a save from a finished game — start fresh.
        guard !state.isOver else { return nil }
        return state
    }
    
    private func saveCampaignToDisk() {
        guard let sim = campaignSim else { return }
        guard let data = try? JSONEncoder().encode(sim.state) else { return }
        try? data.write(to: campaignSaveFileURL)
    }

    // MARK: - Melee Match
    
    private func startMeleeMatch(result: SelectResult) {
        if result.isDemoReplay {
            startDemoReplay()
            return
        }
        
        if let replay = result.savedReplay {
            startSavedReplay(replay)
            return
        }

        currentScreen = .meleePlaying
        
        if let diff = result.aiDifficulty {
            aiPilot = AIPilot(difficulty: diff, seed: UInt64.random(in: 0...UInt64.max))
        } else {
            aiPilot = nil
        }
        
        let modeStr: String
        if let aiDiff = result.aiDifficulty {
            let diff: String
            switch aiDiff {
            case .easy: diff = "Easy"
            case .medium: diff = "Medium"
            case .hard: diff = "Hard"
            }
            modeStr = "vs AI (\(diff))"
        } else {
            modeStr = "2P"
        }
        window.title = "Starfall - \(result.ship1.name) vs \(result.ship2.name) (\(modeStr))"
        matchModeStr = modeStr
        
        let s1Pos = Vec2(x: arena.bounds.min.x + 100, y: arena.bounds.min.y + 100)
        let s2Pos = Vec2(x: arena.bounds.max.x - 100, y: arena.bounds.max.y - 100)
        
        simulation = MeleeSimulation(
            arena: arena,
            ship1Def: result.ship1,
            ship1Pos: s1Pos,
            ship1Facing: .zero,
            ship2Def: result.ship2,
            ship2Pos: s2Pos,
            ship2Facing: Angle(.pi)
        )
        
        renderer = MeleeRenderer(in: gameView, arena: arena)
        wireSceneKeyboard(&renderer!.meleeScene.onKeyEvent)
        renderer!.meleeScene.onPauseMenuSelect = { [self] action in
            self.handlePauseMenuSelect(action)
        }
        selectScene = nil
        inputProcessor.clear()
        isMatchOver = false
        lastThrustP1 = false
        lastThrustP2 = false
        
        // Start recording this match for potential replay.
        let ship1Idx = ShipRoster.all.firstIndex(of: result.ship1) ?? 0
        let ship2Idx = ShipRoster.all.firstIndex(of: result.ship2) ?? 0
        replayRecorder = MeleeReplayRecorder(
            ship1Index: ship1Idx,
            ship2Index: ship2Idx,
            arena: arena,
            ship1StartPos: s1Pos,
            ship1StartFacing: .zero,
            ship2StartPos: s2Pos,
            ship2StartFacing: Angle(.pi)
        )
        
        audio.playMusic(.combat)
    }
    
    // MARK: - Demo Replay

    private func startDemoReplay() {
        currentScreen = .meleePlaying
        isReplayMode = true
        isMatchOver = false
        lastThrustP1 = false
        lastThrustP2 = false
        aiPilot = nil
        matchModeStr = "REPLAY"

        let demoReplay = generateDemoReplay()
        replayPlayer = MeleeReplayPlayer(replay: demoReplay)

        let ship1Name = ShipRoster.all[demoReplay.ship1Index].name
        let ship2Name = ShipRoster.all[demoReplay.ship2Index].name
        window.title = "Starfall - \(ship1Name) vs \(ship2Name) (REPLAY)"

        renderer = MeleeRenderer(in: gameView, arena: demoReplay.arena)
        wireSceneKeyboard(&renderer!.meleeScene.onKeyEvent)
        renderer!.meleeScene.onPauseMenuSelect = { [self] action in
            self.handlePauseMenuSelect(action)
        }
        selectScene = nil

        replayPlayer?.onFrame = { [weak self] sim in
            self?.renderer?.render(sim: sim, matchMode: "REPLAY")
        }

        replayPlayer?.onEnd = { [weak self] _ in
            self?.isMatchOver = true
        }

        replayPlayer?.prepare()
        audio.playMusic(.combat)
        renderer?.meleeScene.showReplaySpeedLabel(replaySpeedMode.displayName)
    }
    
    private func startSavedReplay(_ replay: MeleeReplay) {
        currentScreen = .meleePlaying
        isReplayMode = true
        isMatchOver = false
        lastThrustP1 = false
        lastThrustP2 = false
        aiPilot = nil
        matchModeStr = "REPLAY"
        
        replayPlayer = MeleeReplayPlayer(replay: replay)
        
        let ship1Name = replay.ship1Index >= 0 && replay.ship1Index < ShipRoster.all.count
            ? ShipRoster.all[replay.ship1Index].name : "?"
        let ship2Name = replay.ship2Index >= 0 && replay.ship2Index < ShipRoster.all.count
            ? ShipRoster.all[replay.ship2Index].name : "?"
        window.title = "Starfall - \(ship1Name) vs \(ship2Name) (REPLAY)"
        
        renderer = MeleeRenderer(in: gameView, arena: replay.arena)
        wireSceneKeyboard(&renderer!.meleeScene.onKeyEvent)
        renderer!.meleeScene.onPauseMenuSelect = { [self] action in
            self.handlePauseMenuSelect(action)
        }
        selectScene = nil
        
        replayPlayer?.onFrame = { [weak self] sim in
            self?.renderer?.render(sim: sim, matchMode: "REPLAY")
        }
        
        replayPlayer?.onEnd = { [weak self] _ in
            self?.isMatchOver = true
        }
        
        replayPlayer?.prepare()
        audio.playMusic(.combat)
        renderer?.meleeScene.showReplaySpeedLabel(replaySpeedMode.displayName)
    }

    // MARK: - Campaign
    
    private func showCampaign(aiDifficulty: AIDifficulty = .medium) {
        currentScreen = .campaign
        inputProcessor.clear()
        
        // Check for saved game.
        if let savedState = loadCampaignSave() {
            campaignSim = CampaignSimulation(seed: 0)
            campaignSim!.state = savedState
        } else {
            campaignSim = CampaignSimulation(seed: UInt64.random(in: 0...UInt64.max))
            campaignSim!.state.aiDifficulty = aiDifficulty
        }
        
        showCampaignScene()
        window.title = "Starfall - Campaign"

        // Ensure starting systems are revealed.
        _ = campaignSim?.updateRevealedSystems()

        // Show opening briefing only for new campaigns.
        guard let sim = campaignSim else { return }
        if !sim.state.firedStoryEvents.contains("opening_briefing"),
           let opening = CampaignStory.all.first(where: { $0.id == "opening_briefing" }) {
            sim.state.pendingStoryEvent = nil
            showBriefing(event: opening, isEpilogue: false)
            sim.state.firedStoryEvents.insert("opening_briefing")
        }
    }
    
    private func quitCampaign() {
        campaignScene?.hidePauseOverlay()
        campaignSim = nil
        campaignScene = nil
        campaignTurnStep = 0
        pendingCombatFleets = nil
        inputProcessor.clear()
        showMainMenu()
    }

     private func campaignEndTurn() {
        guard let sim = campaignSim else { return }
        
        // If we're resuming after combat interrupted a previous turn cycle,
        // continue from where we left off.
        if campaignTurnStep > 0 {
            NSLog("[GC] Resuming campaign turn from step %d", campaignTurnStep)
            resumeCampaignTurn()
            return
        }
        
        // Step 1: End the current faction's turn (Compact → Dominion).
        NSLog("[GC] Step 1: endTurn() for %@ turn", sim.state.currentFaction == .compact ? "Compact" : "Dominion")
        let combatTriggered = sim.endTurn()
        
        if combatTriggered {
            NSLog("[GC] Combat triggered during endTurn! Setting step=1, launching melee")
            campaignTurnStep = 1  // After combat, resume at AI turn (step 2)
            _ = handleCombatTriggered()
            return
        }
        
        NSLog("[GC] No combat. Running AI turn (step 2)")
        // Step 2: Run AI turn (Dominion).
        campaignTurnStep = 2  // After combat, resume at step 3
        let aiCombat = sim.runAITurn()
        if aiCombat {
            // AI triggered combat -- auto-resolve, then continue to step 3.
            let _ = handleCombatTriggered(autoResolve: true)
            if sim.state.isOver {
                finishCampaignTurn()
                return
            }
        }
        
        // Step 3: End the AI's turn (Dominion → Compact).
        campaignTurnStep = 3  // After combat, resume at step 4 (cleanup)
        let postAICombat = sim.endTurn()
        if postAICombat {
            let _ = handleCombatTriggered(autoResolve: true)
            if sim.state.isOver {
                finishCampaignTurn()
                return
            }
        }
        
        finishCampaignTurn()
    }
    
    /// Resume the campaign turn after combat has been resolved.
    private func resumeCampaignTurn() {
        guard let sim = campaignSim else { return }
        let step = campaignTurnStep
        campaignTurnStep = 0
        
        switch step {
        case 1:
            // Combat was during Compact's endTurn. Faction is still Compact.
            // Now switch to Dominion and run AI.
            if sim.state.currentFaction == .compact {
                sim.state.currentFaction = .dominion
            }
            campaignTurnStep = 2
            let aiCombat = sim.runAITurn()
            if aiCombat {
                // Auto-resolve AI-triggered combat, then continue.
                let _ = handleCombatTriggered(autoResolve: true)
                if sim.state.isOver {
                    finishCampaignTurn()
                    return
                }
            }
            campaignTurnStep = 3
            let postAICombat = sim.endTurn()
            if postAICombat {
                let _ = handleCombatTriggered(autoResolve: true)
                if sim.state.isOver {
                    finishCampaignTurn()
                    return
                }
            }
            finishCampaignTurn()
            
        case 2:
            // Combat was during AI's runAITurn. Faction is Dominion.
            // Need to end AI's turn (Dominion → Compact).
            campaignTurnStep = 3
            let postAICombat = sim.endTurn()
            if postAICombat {
                let _ = handleCombatTriggered(autoResolve: true)
                if sim.state.isOver {
                    finishCampaignTurn()
                    return
                }
            }
            finishCampaignTurn()
            
        case 3:
            // Combat was during AI's endTurn. Faction is still Dominion.
            // Switch to Compact and finish.
            if sim.state.currentFaction == .dominion {
                sim.state.currentFaction = .compact
                sim.state.currentTurn += 1
            }
            finishCampaignTurn()
            
        default:
            finishCampaignTurn()
        }
    }
    
    /// Finish the campaign turn cycle: check game over, story events, render.
    private func finishCampaignTurn() {
        guard let sim = campaignSim else { return }
        campaignTurnStep = 0
        
        // Check for game over.
        if sim.state.isOver {
            clearCompletedCampaignSave()
            audio.playMusic(sim.state.winner == .compact ? .victory : .defeat)
            audio.play(sim.state.winner == .compact ? .victory : .defeat)
            showCinematicEpilogue(winner: sim.state.winner)
            return
        }
        
        // Check for story events.
        if let eventId = sim.state.pendingStoryEvent,
           let storyEvent = CampaignStory.all.first(where: { $0.id == eventId }) {
            sim.state.pendingStoryEvent = nil
            simulation = nil
            renderer = nil
            aiPilot = nil
            showBriefing(event: storyEvent, isEpilogue: false)
            return
        }
        
        saveCampaignToDisk()

        // Update fog of war at the start of the player's turn.
        if let sim = self.campaignSim {
            _ = sim.updateRevealedSystems()
        }

        // Create and show the campaign scene if needed.
        showCampaignScene()
    }
    
    /// Create and present the campaign scene if it's not already presented.
    private func showCampaignScene() {
        guard let sim = campaignSim else { return }
        NSLog("[GC] showCampaignScene, turn=%d, faction=%@", sim.state.currentTurn, sim.state.currentFaction == .compact ? "Compact" : "Dominion")
        
        let scene = CampaignScene(simulation: sim, size: kSceneSize)
        scene.onAction = { [self] action in
            guard let sim = self.campaignSim else { return nil }
            return sim.execute(action)
        }
        scene.onEndTurn = { [self] in
            self.campaignEndTurn()
        }
        scene.onCombatTriggered = { [self] in
            return self.handleCombatTriggered()
        }
        scene.onCampaignQuit = { [self] in
            self.saveCampaignToDisk()
            self.quitCampaign()
        }
        scene.onSaveAndQuit = { [self] in
            self.saveCampaignToDisk()
            self.quitCampaign()
        }
        wireSceneKeyboard(&scene.onKeyEvent)
        
        campaignScene = scene
        currentScreen = .campaign
        presentSceneWithFade(scene, scaleMode: .resizeFill)
        audio.playMusic(.campaign)
    }
    
    /// Handles a combat trigger. If `autoResolve` is true, the match is simulated
    /// with two AI pilots and resolved immediately without showing the UI.
    /// Returns true if combat was successfully initiated (or auto-resolved).
    private func handleCombatTriggered(autoResolve: Bool = false) -> Bool {
        guard let sim = campaignSim, let pending = sim.state.pendingCombat else { return false }
        
        if autoResolve {
            return autoResolveCombat()
        }
        
        pendingCombatFleets = (pending.attackerFleetID, pending.defenderFleetID)
        
        // Drop into melee with first ships from each fleet.
        guard let attackerFleet = sim.state.fleets[pending.attackerFleetID],
              let defenderFleet = sim.state.fleets[pending.defenderFleetID],
              !attackerFleet.ships.isEmpty,
              !defenderFleet.ships.isEmpty else { return false }
        
        let aShip = attackerFleet.ships[0]
        let dShip = defenderFleet.ships[0]
        
        guard aShip.shipIndex >= 0, aShip.shipIndex < ShipRoster.all.count,
              dShip.shipIndex >= 0, dShip.shipIndex < ShipRoster.all.count else { return false }
        
        let ship1Def = ShipRoster.all[aShip.shipIndex]
        let ship2Def = ShipRoster.all[dShip.shipIndex]
        
        // Store fleet info for resolving combat.
        pendingCombatFleets = (pending.attackerFleetID, pending.defenderFleetID)
        
        // Determine AI difficulty: use the campaign's chosen difficulty, with
        // a mild turn-based ramp so late-game encounters get a bit sharper.
        // (The old code ignored the player's choice and ramped easy→hard.)
        let turn = sim.state.currentTurn
        let campaignDifficulty: AIDifficulty
        switch sim.state.aiDifficulty {
        case .easy:
            campaignDifficulty = turn > 15 ? .medium : .easy
        case .medium:
            campaignDifficulty = turn > 15 ? .hard : .medium
        case .hard:
            campaignDifficulty = .hard
        }
        
        // Start melee match.
        currentScreen = .meleePlaying
        aiPilot = AIPilot(difficulty: campaignDifficulty, seed: UInt64(turn) ^ UInt64(pending.attackerFleetID.value) ^ UInt64(pending.defenderFleetID.value))
        let diffLabel: String
        switch campaignDifficulty {
        case .easy: diffLabel = "Easy"
        case .medium: diffLabel = "Medium"
        case .hard: diffLabel = "Hard"
        }
        matchModeStr = "Campaign (AI \(diffLabel))"
        isMatchOver = false
        lastThrustP1 = false
        lastThrustP2 = false
        
        let s1Pos = Vec2(x: arena.bounds.min.x + 100, y: arena.bounds.min.y + 100)
        let s2Pos = Vec2(x: arena.bounds.max.x - 100, y: arena.bounds.max.y - 100)
        
        simulation = MeleeSimulation(
            arena: arena,
            ship1Def: ship1Def,
            ship1Pos: s1Pos,
            ship1Facing: .zero,
            ship2Def: ship2Def,
            ship2Pos: s2Pos,
            ship2Facing: Angle(.pi)
        )
        
        renderer = MeleeRenderer(in: gameView, arena: arena)
        wireSceneKeyboard(&renderer!.meleeScene.onKeyEvent)
        renderer!.meleeScene.onPauseMenuSelect = { [self] action in
            self.handlePauseMenuSelect(action)
        }
        inputProcessor.clear()
        
        // Start recording for potential replay.
        replayRecorder = MeleeReplayRecorder(
            ship1Index: aShip.shipIndex,
            ship2Index: dShip.shipIndex,
            arena: arena,
            ship1StartPos: s1Pos,
            ship1StartFacing: .zero,
            ship2StartPos: s2Pos,
            ship2StartFacing: Angle(.pi)
        )
        
        audio.playMusic(.combat)
        window.title = "Starfall - Campaign: \(ship1Def.name) vs \(ship2Def.name) (AI \(diffLabel))"
        return true
    }
    
    /// Auto-resolve a campaign combat encounter by simulating with two AI pilots.
    /// Used when the AI triggers combat (not the player's turn).
    /// Returns true if combat was auto-resolved, false if it could not be set up.
    private func autoResolveCombat() -> Bool {
        guard let sim = campaignSim, let pending = sim.state.pendingCombat else {
            return false
        }
        
        guard let attackerFleet = sim.state.fleets[pending.attackerFleetID],
              let defenderFleet = sim.state.fleets[pending.defenderFleetID],
              !attackerFleet.ships.isEmpty,
              !defenderFleet.ships.isEmpty else {
            sim.state.pendingCombat = nil
            return false
        }
        
        let aShip = attackerFleet.ships[0]
        let dShip = defenderFleet.ships[0]
        
        guard aShip.shipIndex >= 0, aShip.shipIndex < ShipRoster.all.count,
              dShip.shipIndex >= 0, dShip.shipIndex < ShipRoster.all.count else {
            sim.state.pendingCombat = nil
            return false
        }
        
        let ship1Def = ShipRoster.all[aShip.shipIndex]
        let ship2Def = ShipRoster.all[dShip.shipIndex]
        
        let s1Pos = Vec2(x: arena.bounds.min.x + 100, y: arena.bounds.min.y + 100)
        let s2Pos = Vec2(x: arena.bounds.max.x - 100, y: arena.bounds.max.y - 100)
        
        let meleeSim = MeleeSimulation(
            arena: arena,
            ship1Def: ship1Def,
            ship1Pos: s1Pos,
            ship1Facing: .zero,
            ship2Def: ship2Def,
            ship2Pos: s2Pos,
            ship2Facing: Angle(.pi)
        )
        
        let turn = sim.state.currentTurn
        let seed1 = UInt64(turn) ^ UInt64(pending.attackerFleetID.value) ^ 0x1000
        let seed2 = UInt64(turn) ^ UInt64(pending.defenderFleetID.value) ^ 0x2000
        
        let pilot1 = AIPilot(difficulty: .hard, seed: seed1)
        let pilot2 = AIPilot(difficulty: .hard, seed: seed2)
        
        // Run the simulation until it ends or times out.
        let maxFrames = 60 * 24
        for _ in 0..<maxFrames {
            if meleeSim.outcome != nil { break }
            
            // Safety: if match timer expires, outcome will be non-nil, so we break.
            let p1Intent = pilot1.think(
                own: meleeSim.ship1,
                opponent: meleeSim.ship2,
                projectiles: meleeSim.projectiles,
                arena: meleeSim.arena
            )
            let p2Intent = pilot2.think(
                own: meleeSim.ship2,
                opponent: meleeSim.ship1,
                projectiles: meleeSim.projectiles,
                arena: meleeSim.arena
            )
            meleeSim.step(p1Input: p1Intent, p2Input: p2Intent)
        }
        
        // Resolve combat.
        pendingCombatFleets = (pending.attackerFleetID, pending.defenderFleetID)
        let outcome = meleeSim.outcome ?? MatchOutcome(
            winnerID: nil,
            shipStates: [meleeSim.ship1.id: meleeSim.ship1, meleeSim.ship2.id: meleeSim.ship2]
        )
        
        // Compute winner faction.
        let attackerFaction = attackerFleet.faction
        let defenderFaction = defenderFleet.faction
        let winnerFaction: Faction?
        if let winnerID = outcome.winnerID {
            winnerFaction = winnerID == EntityID(1) ? attackerFaction : defenderFaction
        } else {
            winnerFaction = nil
        }
        
        // Map melee crew to fleet ship entries.
        let attackerShips: [FleetShipEntry]
        if let attackerFleet = sim.state.fleets[pending.attackerFleetID],
           let s1State = outcome.shipStates[EntityID(1)] {
            attackerShips = attackerFleet.ships.enumerated().map { idx, entry in
                FleetShipEntry(
                    shipIndex: entry.shipIndex,
                    crew: idx == 0 ? s1State.crew : entry.crew
                )
            }
        } else {
            attackerShips = []
        }
        
        let defenderShips: [FleetShipEntry]
        if let defenderFleet = sim.state.fleets[pending.defenderFleetID],
           let s2State = outcome.shipStates[EntityID(2)] {
            defenderShips = defenderFleet.ships.enumerated().map { idx, entry in
                FleetShipEntry(
                    shipIndex: entry.shipIndex,
                    crew: idx == 0 ? s2State.crew : entry.crew
                )
            }
        } else {
            defenderShips = []
        }
        
        let combatResult = CombatResult(
            winnerFaction: winnerFaction,
            attackerShips: attackerShips.filter { $0.crew > 0 },
            defenderShips: defenderShips.filter { $0.crew > 0 }
        )
        
        sim.resolveCombat(attackerFleetID: pending.attackerFleetID, defenderFleetID: pending.defenderFleetID, result: combatResult)
        sim.checkVictory()
        
        pendingCombatFleets = nil
        return true
    }
    
    private func returnFromMeleeCombat() {
        // Finalize recorder if match ended naturally.
        if let recorder = replayRecorder, let meleeSim = simulation, meleeSim.outcome != nil {
            savedReplays.append(recorder.finalize())
            saveReplaysToDisk()
        }
        replayRecorder = nil
        
        guard let sim = campaignSim,
              let fleets = pendingCombatFleets,
              let meleeSim = simulation else {
            return
        }
        
        pendingCombatFleets = nil
        
        // Determine combat result from melee outcome. If the player quit mid-match,
        // compute a forced outcome based on remaining hull (like a timeout).
        let outcome: MatchOutcome
        if let resolved = meleeSim.outcome {
            outcome = resolved
        } else {
            let winnerID: EntityID?
            if meleeSim.ship1.hull > meleeSim.ship2.hull {
                winnerID = meleeSim.ship1.id
            } else if meleeSim.ship2.hull > meleeSim.ship1.hull {
                winnerID = meleeSim.ship2.id
            } else {
                winnerID = nil
            }
            outcome = MatchOutcome(winnerID: winnerID, shipStates: [meleeSim.ship1.id: meleeSim.ship1, meleeSim.ship2.id: meleeSim.ship2])
        }
        
        let attackerFleetID = fleets.attacker
        let defenderFleetID = fleets.defender
        let attackerFaction = sim.state.fleets[attackerFleetID]?.faction ?? .compact
        let defenderFaction = sim.state.fleets[defenderFleetID]?.faction ?? .dominion
        
        let winnerFaction: Faction?
        if let winnerID = outcome.winnerID {
            winnerFaction = winnerID == EntityID(1) ? attackerFaction : defenderFaction
        } else {
            winnerFaction = nil
        }
        
        // Map melee crew to fleet ship entries.
        // Only the first ship from each fleet fought in melee; update its crew.
        let attackerShips: [FleetShipEntry]
        if let attackerFleet = sim.state.fleets[attackerFleetID],
           let s1State = outcome.shipStates[EntityID(1)] {
            attackerShips = attackerFleet.ships.enumerated().map { idx, entry in
                FleetShipEntry(
                    shipIndex: entry.shipIndex,
                    crew: idx == 0 ? s1State.crew : entry.crew
                )
            }
        } else {
            attackerShips = []
        }
        
        let defenderShips: [FleetShipEntry]
        if let defenderFleet = sim.state.fleets[defenderFleetID],
           let s2State = outcome.shipStates[EntityID(2)] {
            defenderShips = defenderFleet.ships.enumerated().map { idx, entry in
                FleetShipEntry(
                    shipIndex: entry.shipIndex,
                    crew: idx == 0 ? s2State.crew : entry.crew
                )
            }
        } else {
            defenderShips = []
        }
        
        let combatResult = CombatResult(
            winnerFaction: winnerFaction,
            attackerShips: attackerShips.filter { $0.crew > 0 },
            defenderShips: defenderShips.filter { $0.crew > 0 }
        )
        
        sim.resolveCombat(attackerFleetID: attackerFleetID, defenderFleetID: defenderFleetID, result: combatResult)
        
        // Re-check victory conditions after combat may have destroyed a starbase fleet.
        sim.checkVictory()
        
        // Check game over after combat.
        if sim.state.isOver {
            clearCompletedCampaignSave()
            audio.playMusic(sim.state.winner == .compact ? .victory : .defeat)
            audio.play(sim.state.winner == .compact ? .victory : .defeat)
            showCinematicEpilogue(winner: sim.state.winner)
            return
        }
        
        currentScreen = .campaign
        
        // Check for post-combat story events.
        if let eventId = sim.state.pendingStoryEvent,
           let storyEvent = CampaignStory.all.first(where: { $0.id == eventId }) {
            sim.state.pendingStoryEvent = nil
            simulation = nil
            renderer = nil
            aiPilot = nil
            showBriefing(event: storyEvent, isEpilogue: false)
            return
        }
        
        simulation = nil
        renderer = nil
        aiPilot = nil
        
        // Resume the campaign turn cycle if combat interrupted it.
        if campaignTurnStep > 0 {
            resumeCampaignTurn()
            return
        }
        
        // Save campaign state and return to campaign screen.
        saveCampaignToDisk()
        showCampaignScene()
    }
    
    // MARK: - Briefing
    
    private func showBriefing(event: StoryEvent, isEpilogue: Bool) {
        currentScreen = .briefing
        
        let scene = BriefingScene(event: event, size: kSceneSize)
        scene.isEpilogue = isEpilogue
        scene.onClose = { [self] in
            self.closeBriefing(isEpilogue: isEpilogue)
        }
        wireSceneKeyboard(&scene.onKeyEvent)
        briefingScene = scene
        presentSceneWithFade(scene)
    }
    
    private func closeBriefing(isEpilogue: Bool) {
        briefingScene = nil
        
        if isEpilogue {
            // After epilogue, return to main menu.
            showMainMenu()
            return
        }
        
        // After a mid-campaign briefing, return to campaign map.
        currentScreen = .campaign
        audio.playMusic(.campaign)
        showCampaignScene()
    }
    
    // MARK: - Cinematic Epilogue
    
    /// A finished campaign should not persist as a resumable save. Clear the
    /// save file so the main menu offers a fresh campaign, not the epilogue.
    private func clearCompletedCampaignSave() {
        try? FileManager.default.removeItem(at: campaignSaveFileURL)
        campaignSim = nil
    }
    
    private func showCinematicEpilogue(winner: Faction?) {
        if winner == .compact {
            showVictoryCinematic()
        } else {
            showDefeatCinematic()
        }
    }
    
    private func showVictoryCinematic() {
        currentScreen = .cinematicVictory
        
        let scene = VictoryScene(size: kSceneSize)
        scene.onClose = { [self] in
            self.closeCinematic()
        }
        wireSceneKeyboard(&scene.onKeyEvent)
        victoryScene = scene
        defeatScene = nil
        presentSceneWithFade(scene)
    }
    
    private func showDefeatCinematic() {
        currentScreen = .cinematicDefeat
        
        let scene = DefeatScene(size: kSceneSize)
        scene.onClose = { [self] in
            self.closeCinematic()
        }
        wireSceneKeyboard(&scene.onKeyEvent)
        defeatScene = scene
        victoryScene = nil
        presentSceneWithFade(scene)
    }
    
    private func closeCinematic() {
        victoryScene = nil
        defeatScene = nil
        showMainMenu()
    }
    
    // MARK: - Game Loop
    
    private func gameLoopTick() {
        switch currentScreen {
        case .meleePlaying, .meleeMatchOver:
            meleeTick()
        case .cinematicVictory:
            cinematicVictoryTick()
        case .cinematicDefeat:
            cinematicDefeatTick()
        case .campaign:
            campaignTick()
        case .briefing:
            // ESC closes the briefing (skips the remaining pages).
            if inputProcessor.isEscapePressed {
                briefingScene?.onClose?()
            }
        default:
            break
        }
    }
    
    private func cinematicVictoryTick() {
        if inputProcessor.isEnterPressed {
            victoryScene?.handleEnter()
            inputProcessor.clear()
        }
        // ESC skips straight to the end of the cinematic.
        if inputProcessor.isEscapePressed {
            victoryScene?.skipToEnd()
        }
    }

    private func cinematicDefeatTick() {
        if inputProcessor.isEnterPressed {
            defeatScene?.handleEnter()
            inputProcessor.clear()
        }
        // ESC skips straight to the end of the cinematic.
        if inputProcessor.isEscapePressed {
            defeatScene?.skipToEnd()
        }
    }

    private func campaignTick() {
        // Allow the campaign scene to run per-frame animations.
        // The campaign simulation itself is turn-based and doesn't step here.
        // (Escape is handled directly in CampaignScene.keyDown so it works on
        // the first press instead of getting swallowed by the one-shot tick.)
        campaignScene?.update()
    }
    
    private func meleeTick() {
        // Replay mode: drive replay player instead of simulation.
        if isReplayMode {
            meleeTickReplay()
            return
        }

        guard let sim = simulation else { return }

        if isMatchOver {
            renderer?.render(sim: sim, matchMode: matchModeStr.isEmpty ? nil : matchModeStr)
            if inputProcessor.isEnterPressed {
                NSLog("[GC] Enter pressed on match over, returning to select")
                // Check if we came from campaign.
                if pendingCombatFleets != nil || (campaignSim != nil && campaignScene == nil) {
                    returnFromMeleeCombat()
                } else {
                    returnToMeleeSelect()
                }
            }
            return
        }

        // Handle pause overlay.
        if isPaused {
            renderer?.render(sim: sim, matchMode: matchModeStr.isEmpty ? nil : matchModeStr)
            if inputProcessor.isEscapePressed {
                isPaused = false
                renderer?.meleeScene.hidePauseOverlay()
                lastLoopTimestamp = 0
                inputProcessor.clear()
            }
            if inputProcessor.menuUpPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuUp()
            }
            if inputProcessor.menuDownPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuDown()
            }
            if inputProcessor.isEnterPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuSelect()
            }
            return
        }

        // Toggle pause on Escape.
        if inputProcessor.isEscapePressed {
            isPaused = true
            renderer?.meleeScene.showPauseOverlay()
            lastLoopTimestamp = 0
            return
        }

        // Measure real elapsed time and accumulate simulation steps.
let now = monotonicTime()
        let elapsed: Double
        if lastLoopTimestamp == 0 {
            elapsed = 0
        } else {
            elapsed = now - lastLoopTimestamp
        }
        lastLoopTimestamp = now

        let steps = fixedTimestep.update(elapsed: min(elapsed, 0.1))

        if steps > 0 {
            let inputs = inputProcessor.read()
            let p2Input: InputIntent

            if let pilot = aiPilot {
                p2Input = pilot.think(
                    own: sim.ship2,
                    opponent: sim.ship1,
                    projectiles: sim.projectiles,
                    arena: sim.arena
                )
            } else {
                p2Input = inputs.p2
            }

            let beforeProjectiles = sim.projectiles.count
            let beforeCrew1 = sim.ship1.crew
            let beforeCrew2 = sim.ship2.crew

            // Thrust edge detection — play thruster SFX on press.
            if inputs.p1.thrust && !lastThrustP1 {
                audio.play(.thruster)
            }
            if p2Input.thrust && !lastThrustP2 {
                audio.play(.thruster)
            }

            sim.step(p1Input: inputs.p1, p2Input: p2Input)

            lastThrustP1 = inputs.p1.thrust
            lastThrustP2 = p2Input.thrust
            
            // Record frame after stepping (so we can detect match end).
            replayRecorder?.record(p1Input: inputs.p1, p2Input: p2Input, matchEnded: sim.outcome != nil)

            if sim.projectiles.count > beforeProjectiles {
                audio.play(.weaponFire)
            }

            if sim.ship1.crew < beforeCrew1 || sim.ship2.crew < beforeCrew2 {
                audio.play(.impact)
            }

            if sim.outcome != nil {
                isMatchOver = true
                inputProcessor.clear()
                
                // Auto-save replay.
                if let recorder = replayRecorder {
                    savedReplays.append(recorder.finalize())
                    saveReplaysToDisk()
                    replayRecorder = nil
                }

                if let winner = sim.outcome?.winnerID {
                    if winner == sim.ship1.id {
                        audio.play(.victory)
                    } else {
                        audio.play(.defeat)
                    }
                } else {
                    audio.play(.explosion)
                }
            }
        }

        renderer?.render(sim: sim, matchMode: matchModeStr.isEmpty ? nil : matchModeStr)
    }

    private func meleeTickReplay() {
        guard let player = replayPlayer else { return }

        if isMatchOver {
            if let sim = player.simulation {
                renderer?.render(sim: sim, matchMode: matchModeStr.isEmpty ? nil : matchModeStr)
            }
            if inputProcessor.isEnterPressed {
                returnToMeleeSelect()
            }
            return
        }

        // Handle pause overlay.
        if isPaused {
            if let sim = player.simulation {
                renderer?.render(sim: sim, matchMode: matchModeStr.isEmpty ? nil : matchModeStr)
            }
            if inputProcessor.isEscapePressed {
                isPaused = false
                renderer?.meleeScene.hidePauseOverlay()
                lastLoopTimestamp = 0
                inputProcessor.clear()
            }
            if inputProcessor.menuUpPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuUp()
            }
            if inputProcessor.menuDownPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuDown()
            }
            if inputProcessor.isEnterPressed {
                audio.play(.uiClick)
                renderer?.meleeScene.pauseMenuSelect()
            }
            return
        }

        // Toggle pause on Escape.
        if inputProcessor.isEscapePressed {
            isPaused = true
            renderer?.meleeScene.showPauseOverlay()
            lastLoopTimestamp = 0
            return
        }

        // Replay controls — handled every frame before input is cleared.
        handleReplayControls(player: player)

        let now = monotonicTime()
        let elapsed: Double
        if lastLoopTimestamp == 0 {
            elapsed = 0
        } else {
            elapsed = now - lastLoopTimestamp
        }
        lastLoopTimestamp = now

        let steps = fixedTimestep.update(elapsed: min(elapsed, 0.1))

        if steps > 0 {
            let framesPerTick = replaySpeedMode.frameCount
            for _ in 0..<framesPerTick {
                let hasMore = player.nextFrame()
                if !hasMore {
                    break
                }
            }
        }

        if isMatchOver {
            if let sim = player.simulation, let outcome = sim.outcome {
                if let winner = outcome.winnerID {
                    if winner == sim.ship1.id {
                        audio.play(.victory)
                    } else {
                        audio.play(.defeat)
                    }
                } else {
                    audio.play(.explosion)
                }
            }
        }

        inputProcessor.clear()
    }

    // MARK: - Replay Controls

    private func handleReplayControls(player: MeleeReplayPlayer) {
        // D (key code 32) — cycle speed: step -> 1x -> 2x -> 4x -> 8x -> step
        if inputProcessor.isKeyHeld(32) && !replayDKeyHeld {
            audio.play(.uiClick)
            let allCases = ReplaySpeedMode.allCases
            let currentIndex = allCases.firstIndex(of: replaySpeedMode) ?? 0
            let nextIndex = (currentIndex + 1) % allCases.count
            replaySpeedMode = allCases[nextIndex]
            renderer?.meleeScene.updateReplaySpeedLabel(replaySpeedMode.displayName)
        }
        replayDKeyHeld = inputProcessor.isKeyHeld(32)

        // Space (key code 49) — step one frame in step mode
        if replaySpeedMode == .step && inputProcessor.isKeyHeld(49) {
            _ = player.nextFrame()
        }

        // Z (key code 6) — rewind to beginning
        if inputProcessor.isRewindPressed {
            audio.play(.uiClick)
            player.reset()
            isMatchOver = false
            renderer?.meleeScene.hideMatchOverLabel()
        }
    }

    private var replayDKeyHeld: Bool = false

    private func returnToMeleeSelect() {
        isMatchOver = false
        isReplayMode = false
        aiPilot = nil
        replayPlayer = nil
        replayRecorder = nil
        lastThrustP1 = false
        lastThrustP2 = false
        replaySpeedMode = .normal
        replayDKeyHeld = false
        renderer?.meleeScene.hideReplaySpeedLabel()
        inputProcessor.clear()
        showMeleeSelect()
    }

    // MARK: - Pause Menu

    private func handlePauseMenuSelect(_ action: String) {
        isPaused = false
        renderer?.meleeScene.hidePauseOverlay()
        inputProcessor.clear()

        if action == "quit" {
            // Check if we came from campaign.
            if pendingCombatFleets != nil || (campaignSim != nil && campaignScene == nil) {
                returnFromMeleeCombat()
            } else {
                simulation = nil
                renderer = nil
                aiPilot = nil
                replayPlayer = nil
                isReplayMode = false
                showMainMenu()
            }
        } else {
            // Resume — reset timestamp to avoid frame spike.
            lastLoopTimestamp = 0
        }
    }
}