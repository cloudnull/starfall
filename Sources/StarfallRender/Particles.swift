import AppKit
import SpriteKit

/// Fixed scene size used by all SpriteKit scenes.
public let kSceneSize = CGSize(width: 1440, height: 810)

/// Simple particle system for macOS SpriteKit.
/// macOS SKEmitterNode has a very limited API (no variation properties),
/// so we manage particles manually as small circles with fade-out.
struct Particle: Identifiable {
    let id: UUID
    var position: CGPoint
    let velocity: CGPoint
    let color: NSColor
    let size: CGFloat
    let lifetime: CGFloat
    var age: CGFloat = 0
}

/// Manages a pool of particles within a parent SKNode.
@MainActor
final class ParticleManager {
    let parent: SKNode
    private var particles: [Particle] = []
    private var particleNodes: [UUID: SKShapeNode] = [:]
    
    init(parent: SKNode) {
        self.parent = parent
    }
    
    /// Emit a burst of particles from a position.
    func emit(position: CGPoint, count: Int, color: NSColor, speed: CGFloat, size: CGFloat, lifetime: CGFloat) {
        for _ in 0..<count {
            let angle: CGFloat = CGFloat(arc4random()) / CGFloat(UInt32.max) * .pi * 2
            let speedVar = speed * (0.5 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 0.5)
            let particle = Particle(
                id: UUID(),
                position: position,
                velocity: CGPoint(x: cos(angle) * speedVar, y: sin(angle) * speedVar),
                color: color,
                size: size * (0.5 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 0.5),
                lifetime: lifetime
            )
            particles.append(particle)
            
            let circle = CGPath(ellipseIn: CGRect(
                x: -particle.size / 2,
                y: -particle.size / 2,
                width: particle.size,
                height: particle.size
            ), transform: nil)
            let node = SKShapeNode(path: circle)
            node.fillColor = particle.color
            node.strokeColor = NSColor.clear
            node.position = particle.position
            parent.addChild(node)
            particleNodes[particle.id] = node
        }
    }
    
/// Emit thrust particles — directional burst behind a ship.
    /// `facingRadians` is the ship's forward direction in radians.
    func emitThrust(position: CGPoint, facingRadians: CGFloat, color: NSColor, count: Int = 3) {
        let thrustAngle = facingRadians + .pi

        for _ in 0..<count {
            let spread = (CGFloat(arc4random()) / CGFloat(UInt32.max) - 0.5) * CGFloat.pi / 3
            let angle = thrustAngle + spread
            let speed = 40 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 30
            let particle = Particle(
                id: UUID(),
                position: position,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                color: color,
                size: 3 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 3,
                lifetime: 0.3
            )
            particles.append(particle)

            let circle = CGPath(ellipseIn: CGRect(
                x: -particle.size / 2,
                y: -particle.size / 2,
                width: particle.size,
                height: particle.size
            ), transform: nil)
            let node = SKShapeNode(path: circle)
            node.fillColor = particle.color
            node.strokeColor = NSColor.clear
            node.position = particle.position
            parent.addChild(node)
            particleNodes[particle.id] = node
        }
    }

    /// Emit thrust particles with a two-tone flame: inner core in `coreColor`,
    /// outer glow in `glowColor`.
    func emitThrustDual(position: CGPoint, facingRadians: CGFloat, coreColor: NSColor, glowColor: NSColor, count: Int = 5) {
        let thrustAngle = facingRadians + .pi

        for i in 0..<count {
            let isCore = i % 2 == 0
            let spread = (CGFloat(arc4random()) / CGFloat(UInt32.max) - 0.5) * CGFloat.pi / (isCore ? 4 : 3)
            let angle = thrustAngle + spread
            let spd = isCore
                ? 50 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 20
                : 35 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 25
            let color = isCore ? coreColor : glowColor
            let sz = isCore
                ? 2 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 2
                : 3 + CGFloat(arc4random()) / CGFloat(UInt32.max) * 3
            let lifetime: CGFloat = isCore ? 0.25 : 0.35
            let particle = Particle(
                id: UUID(),
                position: position,
                velocity: CGPoint(x: cos(angle) * spd, y: sin(angle) * spd),
                color: color,
                size: sz,
                lifetime: lifetime
            )
            particles.append(particle)

            let circle = CGPath(ellipseIn: CGRect(
                x: -particle.size / 2,
                y: -particle.size / 2,
                width: particle.size,
                height: particle.size
            ), transform: nil)
            let node = SKShapeNode(path: circle)
            node.fillColor = particle.color
            node.strokeColor = NSColor.clear
            node.position = particle.position
            parent.addChild(node)
            particleNodes[particle.id] = node
        }
    }
    
    /// Emit explosion particles.
    func emitExplosion(position: CGPoint, color: NSColor, count: Int = 40) {
        emit(position: position, count: count, color: color, speed: 120, size: 5, lifetime: 0.5)
    }
    
    /// Emit asteroid debris.
    func emitAsteroidDebris(position: CGPoint, count: Int = 20) {
        emit(position: position, count: count, color: NSColor.systemGray, speed: 80, size: 3, lifetime: 0.4)
    }
    
    /// Emit projectile trail particle.
    func emitTrail(position: CGPoint, color: NSColor) {
        let particle = Particle(
            id: UUID(),
            position: position,
            velocity: CGPoint(x: 0, y: 0),
            color: color,
            size: 2,
            lifetime: 0.15
        )
        particles.append(particle)
        
        let circle = CGPath(ellipseIn: CGRect(
            x: -particle.size / 2,
            y: -particle.size / 2,
            width: particle.size,
            height: particle.size
        ), transform: nil)
        let node = SKShapeNode(path: circle)
        node.fillColor = particle.color
        node.strokeColor = NSColor.clear
        node.position = particle.position
        parent.addChild(node)
        particleNodes[particle.id] = node
    }
    
    /// Update all particles by dt seconds. Remove dead particles.
    func update(dt: CGFloat) {
        for i in stride(from: particles.count - 1, through: 0, by: -1) {
            var particle = particles[i]
            particle.age += dt
            
            if particle.age >= particle.lifetime {
                // Remove
                if let node = particleNodes.removeValue(forKey: particle.id) {
                    node.removeFromParent()
                }
                particles.remove(at: i)
                continue
            }
            
            // Update position
            let newX = particle.position.x + particle.velocity.x * dt
            let newY = particle.position.y + particle.velocity.y * dt
            particle.position = CGPoint(x: newX, y: newY)
            
            // Update visual
            if let node = particleNodes[particle.id] {
                node.position = particle.position
                node.alpha = 1 - (particle.age / particle.lifetime)
            }
            
            particles[i] = particle
        }
    }
    
    /// Clear all particles immediately. Call before scene transitions.
    @MainActor public func clear() {
        for node in particleNodes.values {
            node.removeFromParent()
        }
        particleNodes.removeAll()
        particles.removeAll()
    }
    
    var count: Int { particles.count }
}

/// Factory for particle effect nodes used in the melee arena.
@MainActor
enum ParticleEffects {
    /// Explosion burst — one-shot, radial, fades over ~0.6s.
    static func explosion(particles: ParticleManager, position: CGPoint, color: NSColor) {
        particles.emitExplosion(position: position, color: color, count: 50)
    }
    
    /// Asteroid debris — small particles for asteroid destruction effect.
    static func asteroidDebris(particles: ParticleManager, position: CGPoint) {
        particles.emitAsteroidDebris(position: position, count: 25)
    }
    
    /// Shield shimmer — rotating ring with pulsing alpha.
    static func shieldShimmer(radius: CGFloat) -> SKShapeNode {
        let ring = CGPath(ellipseIn: CGRect(
            x: -radius,
            y: -radius,
            width: radius * 2,
            height: radius * 2
        ), transform: nil)
        let node = SKShapeNode(path: ring)
        node.fillColor = NSColor.clear
        node.strokeColor = NSColor.cyan
        node.lineWidth = 1.5
        node.alpha = 0.4
        node.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 3)))
        node.run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 0.8),
                SKAction.fadeAlpha(to: 0.3, duration: 0.8)
            ])
        ))
        return node
    }
    
    /// Special ability glow — colored particles around a ship.
    static func specialGlow(particles: ParticleManager, position: CGPoint, color: NSColor) {
        particles.emit(position: position, count: 20, color: color, speed: 40, size: 3, lifetime: 0.4)
    }
}