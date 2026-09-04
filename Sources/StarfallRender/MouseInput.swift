import AppKit
import SpriteKit

/// Coordinate conversion helpers for SpriteKit on macOS.
///
/// macOS SpriteKit has unreliable frame computation and `nodes(at:)`
/// returns empty before the first render pass.
/// This module provides correct mouse coordinate conversion and hit-testing.
public extension SKScene {
    
    /// Convert an NSEvent's window location to scene coordinates.
    func convertMouseLocation(_ event: NSEvent) -> CGPoint? {
        guard let skView = self.view else { return nil }
        let winPt = event.locationInWindow
        let viewPt = skView.convert(winPt, from: nil)
        return self.convertPoint(fromView: viewPt)
    }
    
    /// Check if a scene-space point is inside an SKSpriteNode.
    static func pointInSprite(_ point: CGPoint, sprite: SKSpriteNode) -> Bool {
        let halfW = sprite.size.width / 2
        let halfH = sprite.size.height / 2
        let bounds = CGRect(x: sprite.position.x - halfW, y: sprite.position.y - halfH, width: sprite.size.width, height: sprite.size.height)
        return bounds.contains(point)
    }
}

/// Compute bounding box for a node in its parent's coordinate space.
/// Uses node-specific size information rather than `frame` which may
/// return zero on macOS SpriteKit before the first render pass.
@MainActor
public func nodeBounds(in node: SKNode) -> CGRect {
    if let sprite = node as? SKSpriteNode {
        return CGRect(x: node.position.x - sprite.size.width / 2,
                      y: node.position.y - sprite.size.height / 2,
                      width: sprite.size.width, height: sprite.size.height)
    }
    if let label = node as? SKLabelNode {
        let fs = CGFloat(label.fontSize)
        let estW = fs * 5
        let estH = fs
        return CGRect(x: node.position.x - estW / 2,
                      y: node.position.y - estH / 2,
                      width: estW, height: estH)
    }
    if let shape = node as? SKShapeNode {
        let f = shape.frame
        if f.width > 0 && f.height > 0 { return f }
        if let bb = shape.path?.boundingBox {
            return CGRect(x: node.position.x + bb.minX - bb.midX,
                          y: node.position.y + bb.minY - bb.midY,
                          width: bb.width, height: bb.height)
        }
        return CGRect(x: node.position.x, y: node.position.y, width: 0, height: 0)
    }
    var bounds: CGRect?
    for child in node.children {
        let childBox = nodeBounds(in: child)
        bounds = bounds.map { $0.union(childBox) } ?? childBox
    }
    return bounds ?? CGRect(x: node.position.x, y: node.position.y, width: 0, height: 0)
}

/// Recursively find the deepest named node at the given position.
/// `point` is in `rootNode`'s coordinate space.
@MainActor
public func findNamedNode(at point: CGPoint, in rootNode: SKNode) -> SKNode? {
    return _searchHierarchy(rootNode, at: point)
}

@MainActor
private func _searchHierarchy(_ node: SKNode, at point: CGPoint) -> SKNode? {
    var bestMatch: SKNode? = nil
    
    for child in node.children {
        let dx = point.x - child.position.x
        let dy = point.y - child.position.y
        let cosR = cos(-child.zRotation)
        let sinR = sin(-child.zRotation)
        let localPoint = CGPoint(x: dx * cosR - dy * sinR, y: dx * sinR + dy * cosR)
        
        let box = nodeBounds(in: child)
        if box.contains(localPoint) {
            if let found = _searchHierarchy(child, at: localPoint) {
                return found
            }
            if child.name != nil {
                bestMatch = child
            }
        }
    }
    return bestMatch
}