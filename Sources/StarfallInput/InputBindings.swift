import StarfallCore

/// The Input module translates keyboard and mouse events into
/// InputIntent data that the simulation consumes.
///
/// The simulation never sees raw input devices.

/// Keyboard key code for bindings (platform-agnostic key identifier).
public enum KeyBinding: UInt16, Codable, Sendable, Hashable {
    case a = 0
    case s = 1
    case d = 2
    case w = 13
    case space = 49
    case shift = 56
    case control = 59
    case option = 58
    case command = 55
    case leftArrow = 123
    case rightArrow = 124
    case upArrow = 126
    case downArrow = 125
    case period = 47      // . key (ANSI layout) - P2 special
    case slash = 43       // / key (ANSI layout) - P2 fire
    case unknown = 65535
}

/// Keyboard key mapping for melee controls.
public struct MeleeKeyBindings: Codable, Sendable {
    // P1 bindings
    public var rotateLeft: KeyBinding
    public var rotateRight: KeyBinding
    public var thrust: KeyBinding
    public var firePrimary: KeyBinding
    public var fireSpecial: KeyBinding
    
    // P2 bindings (default: arrow keys + / + .)
    public var p2RotateLeft: KeyBinding
    public var p2RotateRight: KeyBinding
    public var p2Thrust: KeyBinding
    public var p2FirePrimary: KeyBinding
    public var p2FireSpecial: KeyBinding
    
    public init() {
        // P1 default: W=thrust, A=turn left, D=turn right, Space=fire, Shift=special
        self.rotateLeft = .a
        self.rotateRight = .d
        self.thrust = .w
        self.firePrimary = .space
        self.fireSpecial = .shift
        
        // P2 default: Arrow keys + / for fire + . for special
        self.p2RotateLeft = .leftArrow
        self.p2RotateRight = .rightArrow
        self.p2Thrust = .upArrow
        self.p2FirePrimary = .slash
        self.p2FireSpecial = .period
    }
    
    /// Returns the raw key codes for both players.
    public func keyCodes() -> (p1: (thrust: UInt16, turnLeft: UInt16, turnRight: UInt16, fire: UInt16, special: UInt16),
                                p2: (thrust: UInt16, turnLeft: UInt16, turnRight: UInt16, fire: UInt16, special: UInt16)) {
        (
            p1: (thrust: thrust.rawValue, turnLeft: rotateLeft.rawValue, turnRight: rotateRight.rawValue,
                 fire: firePrimary.rawValue, special: fireSpecial.rawValue),
            p2: (thrust: p2Thrust.rawValue, turnLeft: p2RotateLeft.rawValue, turnRight: p2RotateRight.rawValue,
                  fire: p2FirePrimary.rawValue, special: p2FireSpecial.rawValue)
        )
    }
}