import StarfallCore

/// The Audio module handles music and sound effects.
///
/// Uses AVFoundation for all audio playback.

/// Sound effect type.
public enum SoundEffect {
    case weaponFire
    case impact
    case explosion
    case thruster
    case uiClick
    case victory
    case defeat
}

/// Music track type.
public enum MusicTrack {
    case menu
    case combat
    case campaign
    case victory
    case defeat
}