import Foundation

/// Fixed timestep game loop accumulator.
///
/// Ensures the simulation advances at a constant rate regardless of
/// rendering frame rate. The fixed timestep provides deterministic
/// simulation: same inputs always produce the same simulation states.
///
/// The game runs at 24 FPS (matching the original Star Control), meaning
/// each simulation step represents 1/24 of a second.
public final class FixedTimestep {
    /// The number of simulation frames per second (matching original Star Control).
    public static let simulationFPS: Int = 24

    /// The duration of one simulation frame in seconds.
    public static var frameDuration: Double {
        1.0 / Double(simulationFPS)
    }

    /// The number of simulation frames per second for rendering.
    public static let renderFPS: Int = 60

    private var accumulator: Double
    private var frameCount: Int

    public init() {
        self.accumulator = 0
        self.frameCount = 0
    }

    /// Processes elapsed time and returns the number of simulation steps to execute.
    ///
    /// - Parameter elapsed: Time in seconds since the last call.
    /// - Returns: Number of simulation frames to step. Always 0 or 1 per call
    ///            to prevent spiral of death under heavy load.
    @discardableResult
    public func update(elapsed: Double) -> Int {
        accumulator += elapsed
        let stepCount = Int(accumulator / Self.frameDuration)

        // Execute at most one step per call to prevent spiral of death.
        let stepsToRun = min(max(stepCount, 0), 1)
        if stepsToRun > 0 {
            accumulator -= Double(stepsToRun) * Self.frameDuration
            frameCount += stepsToRun
        }

        // Prevent accumulator from growing unbounded under extreme lag.
        if accumulator > Self.frameDuration * 2 {
            accumulator = 0
        }

        return stepsToRun
    }

    /// Returns the interpolation alpha for smooth rendering between simulation states.
    /// A value of 0 means display the previous state; 1 means display the current state.
    public var interpolationAlpha: Double {
        accumulator / Self.frameDuration
    }

    /// Total number of simulation frames executed.
    public var totalFrames: Int { frameCount }

    /// Resets the accumulator and frame count.
    public func reset() {
        accumulator = 0
        frameCount = 0
    }
}