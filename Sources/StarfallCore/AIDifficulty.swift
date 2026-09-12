/// The AI module provides opponent pilots for melee combat and
/// strategic opponent behavior for the campaign layer.
///
/// AI difficulty is implemented through behavioral changes and reaction times,
/// never through stat multipliers.

/// AI difficulty level.
public enum AIDifficulty: Int, CaseIterable, Sendable, Codable {
    /// Easy - slow reactions, simple tactics.
    case easy
    
    /// Medium - moderate reactions, situational awareness.
    case medium
    
    /// Hard - fast reactions, advanced tactics (gravity whipping, kiting).
    case hard
}