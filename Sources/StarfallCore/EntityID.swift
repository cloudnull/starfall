/// Unique identifier for entities in the simulation.
public struct EntityID: Hashable, Sendable, Codable {
    public let value: UInt32

    public init(_ value: UInt32) {
        self.value = value
    }
}