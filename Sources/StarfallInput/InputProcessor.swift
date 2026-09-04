import AppKit
import StarfallCore

/// Maps NSEvent keyboard events into InputIntent for one or two players.
///
/// Player 1 uses WASD + Space + Shift.
/// Player 2 uses arrow keys + / + -.
public final class InputProcessor {
    private var keyCodeStates: Set<UInt16> = []

    var p1ThrustKey: UInt16
    var p1TurnLeftKey: UInt16
    var p1TurnRightKey: UInt16
    var p1FireKey: UInt16
    var p1SpecialKey: UInt16

    var p2ThrustKey: UInt16
    var p2TurnLeftKey: UInt16
    var p2TurnRightKey: UInt16
    var p2FireKey: UInt16
    var p2SpecialKey: UInt16

    public init(p1: MeleeKeyBindings = MeleeKeyBindings()) {
        let codes = p1.keyCodes()
        
        // Player 1
        self.p1ThrustKey = codes.p1.thrust
        self.p1TurnLeftKey = codes.p1.turnLeft
        self.p1TurnRightKey = codes.p1.turnRight
        self.p1FireKey = codes.p1.fire
        self.p1SpecialKey = codes.p1.special
        
        // Player 2
        self.p2ThrustKey = codes.p2.thrust
        self.p2TurnLeftKey = codes.p2.turnLeft
        self.p2TurnRightKey = codes.p2.turnRight
        self.p2FireKey = codes.p2.fire
        self.p2SpecialKey = codes.p2.special
    }

    /// Add a key-down event.
    public func keyDown(keyCode: UInt16) {
        keyCodeStates.insert(keyCode)
    }

    /// Add a key-up event.
    public func keyUp(keyCode: UInt16) {
        keyCodeStates.remove(keyCode)
    }

    /// Read current intents for both players.
    public func read() -> (p1: InputIntent, p2: InputIntent) {
        (
            InputIntent(
                thrust: keyCodeStates.contains(p1ThrustKey),
                turnLeft: keyCodeStates.contains(p1TurnLeftKey),
                turnRight: keyCodeStates.contains(p1TurnRightKey),
                firePrimary: keyCodeStates.contains(p1FireKey),
                fireSpecial: keyCodeStates.contains(p1SpecialKey)
            ),
            InputIntent(
                thrust: keyCodeStates.contains(p2ThrustKey),
                turnLeft: keyCodeStates.contains(p2TurnLeftKey),
                turnRight: keyCodeStates.contains(p2TurnRightKey),
                firePrimary: keyCodeStates.contains(p2FireKey),
                fireSpecial: keyCodeStates.contains(p2SpecialKey)
            )
        )
    }

    /// Clear all input state.
    public func clear() {
        keyCodeStates.removeAll()
        escapeHeld = false
        menuUpHeld = false
        menuDownHeld = false
        rewindHeld = false
    }

    /// Whether Enter (key code 36) is currently held.
    public var isEnterPressed: Bool {
        keyCodeStates.contains(36) || keyCodeStates.contains(76)
    }

    /// Whether Escape (key code 53) was just pressed (one-shot).
    private var escapeHeld: Bool = false
    public var isEscapePressed: Bool {
        let held = keyCodeStates.contains(53)
        defer { escapeHeld = held }
        return held && !escapeHeld
    }

    /// One-shot menu up/down for pause overlay (W=13/S=1 or Up=126/Down=125).
    private var menuUpHeld: Bool = false
    private var menuDownHeld: Bool = false
    public var menuUpPressed: Bool {
        let held = keyCodeStates.contains(13) || keyCodeStates.contains(126)
        defer { menuUpHeld = held }
        return held && !menuUpHeld
    }
    public var menuDownPressed: Bool {
        let held = keyCodeStates.contains(1) || keyCodeStates.contains(125)
        defer { menuDownHeld = held }
        return held && !menuDownHeld
    }

    /// Check if a specific key code is currently held (for replay controls that
    /// need to read raw key state outside the one-shot pattern).
    public func isKeyHeld(_ keyCode: UInt16) -> Bool {
        keyCodeStates.contains(keyCode)
    }

    /// One-shot rewind press — Z key (key code 6).
    private var rewindHeld: Bool = false
    public var isRewindPressed: Bool {
        let held = keyCodeStates.contains(6)
        defer { rewindHeld = held }
        return held && !rewindHeld
    }
}