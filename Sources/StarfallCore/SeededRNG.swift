/// Seeded, deterministic pseudo-random number generator.
///
/// Uses a splitmix63 algorithm, which provides high-quality randomness
/// with a period of 2^64. The generator is fully deterministic:
/// the same seed always produces the same sequence.
public final class SeededRNG {
    private var state: UInt64

    /// Creates a new RNG from a 64-bit seed.
    public init(seed: UInt64) {
        self.state = seed
        // Warm the generator with 20 iterations.
        for _ in 0..<20 {
            _ = next()
        }
    }

    /// Returns the next random UInt64 value.
    public func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        z = z ^ (z &>> 31)
        return z
    }

    /// Returns a random Double in the range [0, 1).
    public func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Returns a random Int in the range [0, upperBound).
    public func nextInt(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }

    /// Returns a random Double in the range [min, max).
    public func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    /// Returns a random element from an array.
    public func choose<T>(from array: [T]) -> T {
        guard !array.isEmpty else {
            fatalError("Cannot choose from empty array")
        }
        return array[nextInt(upperBound: array.count)]
    }
}