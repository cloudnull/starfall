import AppKit
import SpriteKit
import StarfallCore
import StarfallData
import StarfallMelee

/// Bridges SKView and MeleeScene for rendering a melee match.
@MainActor
public final class MeleeRenderer {
    private let skView: SKView
    private let scene: MeleeScene

    public init(in skView: SKView, arena: ArenaState) {
        self.skView = skView
        self.scene = MeleeScene(arena: arena, size: kSceneSize)
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        scene.scaleMode = .aspectFit
    }

    /// Called once per frame to provide updated simulation state.
    /// The renderer uses SpriteKit's update(_:) loop for timing.
    public func render(sim: MeleeSimulation, matchMode: String? = nil) {
        scene.update(sim: sim, matchMode: matchMode)
    }
    
    /// Returns the underlying SKScene so the game loop can drive
    /// simulation from SpriteKit's update(_:) callback.
    public var meleeScene: MeleeScene { scene }
}