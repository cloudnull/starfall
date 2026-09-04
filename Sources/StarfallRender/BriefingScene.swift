import AppKit
import SpriteKit
import StarfallCore
import StarfallCampaign

/// A SpriteKit scene for displaying story briefings, victory, and defeat
/// epilogues. Text advances on click.
@MainActor
public final class BriefingScene: SKScene {
    
    public var onClose: (() -> Void)?
    
    public var onKeyEvent: ((UInt16, Bool) -> Void)? = nil

    public override func keyDown(with event: NSEvent) {
        onKeyEvent?(event.keyCode, true)
    }

    public override func keyUp(with event: NSEvent) {
        onKeyEvent?(event.keyCode, false)
    }
    
    private let event: StoryEvent
    private var page: Int = 0
    
    private let bgLayer = SKNode()
    private let contentLayer = SKNode()
    private let controlsLayer = SKNode()
    
    private let titleLabel = SKLabelNode()
    private let speakerLabel = SKLabelNode()
    private let bodyLabel = SKLabelNode()
    private let pageLabel = SKLabelNode()
    private let closeLabel = SKLabelNode()
    
    // For closing after victory/defeat epilogue: return to main menu.
    public var isEpilogue: Bool = false
    
    public init(event: StoryEvent, size: CGSize) {
        self.event = event
        super.init(size: size)
        backgroundColor = NSColor.black
        page = 0
        setupScene()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupScene() {
        bgLayer.zPosition = 0
        addChild(bgLayer)
        
        // Dim overlay.
        let overlay = SKSpriteNode(
            color: NSColor.black.withAlphaComponent(0.85),
            size: size
        )
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bgLayer.addChild(overlay)
        
        contentLayer.zPosition = 10
        addChild(contentLayer)
        
        controlsLayer.zPosition = 100
        addChild(controlsLayer)
        
        let centerX = size.width / 2
        let startY: CGFloat = CGFloat(size.height) * 0.72
        let maxWidth: CGFloat = size.width * 0.7
        
        // Title.
        titleLabel.fontName = "Helvetica Neue"
        titleLabel.fontSize = 24
        titleLabel.fontColor = NSColor.white
        titleLabel.text = event.title
        titleLabel.position = CGPoint(x: centerX, y: startY)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.preferredMaxLayoutWidth = maxWidth
        contentLayer.addChild(titleLabel)
        
        // Speaker.
        if let speaker = event.speaker {
            speakerLabel.fontName = "Helvetica Neue"
            speakerLabel.fontSize = 14
            speakerLabel.fontColor = NSColor.systemBlue
            speakerLabel.text = "— \(speaker)"
            speakerLabel.position = CGPoint(x: centerX, y: startY - 35)
            speakerLabel.horizontalAlignmentMode = .center
            contentLayer.addChild(speakerLabel)
        }
        
        // Divider line.
        let divider = SKShapeNode(
            rect: CGRect(x: centerX - maxWidth / 2, y: startY - 55, width: maxWidth, height: 1)
        )
        divider.fillColor = .clear
        divider.strokeColor = NSColor.darkGray.withAlphaComponent(0.5)
        divider.lineWidth = 1
        contentLayer.addChild(divider)
        
        // Body text.
        bodyLabel.fontName = "Helvetica Neue"
        bodyLabel.fontSize = 14
        bodyLabel.fontColor = NSColor.white.withAlphaComponent(0.9)
        bodyLabel.position = CGPoint(x: centerX, y: startY - 80)
        bodyLabel.horizontalAlignmentMode = .center
        bodyLabel.preferredMaxLayoutWidth = maxWidth
        bodyLabel.numberOfLines = 0
        contentLayer.addChild(bodyLabel)
        
        // Page indicator.
        pageLabel.fontName = "Helvetica Neue"
        pageLabel.fontSize = 11
        pageLabel.fontColor = NSColor.darkGray
        pageLabel.position = CGPoint(x: centerX, y: 40)
        pageLabel.horizontalAlignmentMode = .center
        contentLayer.addChild(pageLabel)
        
        // Close/continue hint.
        closeLabel.fontName = "Helvetica Neue"
        closeLabel.fontSize = 12
        closeLabel.fontColor = NSColor.gray.withAlphaComponent(0.6)
        closeLabel.position = CGPoint(x: centerX, y: 65)
        closeLabel.horizontalAlignmentMode = .center
        controlsLayer.addChild(closeLabel)
        
        updatePage()
    }
    
    private func updatePage() {
        let total = event.paragraphs.count
        
        if page < total {
            bodyLabel.text = event.paragraphs[page]
            pageLabel.text = "\(page + 1) / \(total)"
            closeLabel.text = "Click to continue"
        } else {
            // End of briefing.
            bodyLabel.text = event.paragraphs.last
            if isEpilogue {
                pageLabel.text = ""
                closeLabel.text = "Click to return to main menu"
            } else {
                pageLabel.text = ""
                closeLabel.text = "Click to continue"
            }
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        let total = self.event.paragraphs.count
        
        if page < total {
            page += 1
            updatePage()
        } else {
            // Briefing complete.
            onClose?()
        }
    }
}