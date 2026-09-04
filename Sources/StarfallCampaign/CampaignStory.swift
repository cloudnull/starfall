import StarfallCore
import StarfallData

/// A story event that fires during the campaign.
public struct StoryEvent: Sendable, Hashable {
    /// Unique event identifier.
    public let id: String
    
    /// Title shown at the top of the briefing screen.
    public let title: String
    
    /// Body text, split into paragraphs for page-by-page advance.
    public let paragraphs: [String]
    
    /// Speaker name (nil for narration).
    public let speaker: String?
    
    public init(id: String, title: String, paragraphs: [String], speaker: String? = nil) {
        self.id = id
        self.title = title
        self.paragraphs = paragraphs
        self.speaker = speaker
    }
}

/// Story event checker: examines campaign state and returns events
/// that should fire this turn.
public struct CampaignStory {
    
    /// All defined story events.
    public static let all: [StoryEvent] = [
        openingBriefing,
        firstLoss,
        firstBarrierWorld,
        keshVarrDefects,
        midCrisis,
        gloryRun,
        finalPush,
        compactVictory,
        dominionVictory
    ]
    
    /// Opening briefing: fires at turn 1 for the Compact player.
    private static let openingBriefing = StoryEvent(
        id: "opening_briefing",
        title: "The Gathering Storm",
        paragraphs: [
            "A Dominion fleet has just overwhelmed the Compact outpost at Epsilon-7. The last transmission showed little more than a slave-shield rising over the colony.",
            "Commander Jorin Vael has assigned you to lead a fleet. Orders: hold the line, gather resources, strike at Dominion supply nodes.",
            "The Ossari Harbinger Zzrr'tkal reminds us: the Vexari do not destroy. They absorb. Every system we lose becomes another weapon turned against us.",
            "Make every turn count."
        ],
        speaker: "Jorin Vael"
    )
    
    /// First colony falls: fires when an unowned system becomes enemy-owned.
    private static let firstLoss = StoryEvent(
        id: "first_loss",
        title: "System Lost",
        paragraphs: [
            "Another system has fallen under Dominion control. Slave shields are rising — the population will be Bonded within hours.",
            "The Compact is running out of systems to defend. We must push forward before the line collapses entirely."
        ],
        speaker: "Zzrr'tkal"
    )
    
    /// Barrier world cracked: fires around turn 8.
    private static let firstBarrierWorld = StoryEvent(
        id: "first_barrier_world",
        title: "The Barrier Cracks",
        paragraphs: [
            "Intelligence reports that a Barrier World's slave shield has been destabilized. Inside, the Synthari await liberation.",
            "But the Synthari — artificial beings created by a civilization long dead — may not welcome organic liberators. Their creator's programming makes them unable to trust.",
            "If they are freed, they may strike at the Dominion from another direction. Or they may vanish into deep space."
        ],
        speaker: "Elara Moss"
    )
    
    /// Kesh-Varr defector: fires around turn 5.
    private static let keshVarrDefects = StoryEvent(
        id: "keshvarr_defects",
        title: "A Defector",
        paragraphs: [
            "A Kesha pilot has defected mid-battle, breaking away from a Dominion fleet and coming to our side. The pilot — Kesh-Varr — brings intelligence about a Dominion weakness.",
            "Kesh-Varr was trembling during the debriefing. Fearful. But intelligence confirms the reports: there are cracks in the Dominion's supply lines.",
            "The Vexari overextend. For all their power, they cannot be everywhere at once."
        ],
        speaker: "Jorin Vael"
    )
    
    /// Mid-campaign crisis: fires around turn 12.
    private static let midCrisis = StoryEvent(
        id: "mid_crisis",
        title: "Crisis at the Starbase",
        paragraphs: [
            "The Dominion has massed fleets near our Starbase. A decisive blow is coming.",
            "Elara Moss was wounded during a reconnaissance mission. Her last letter: 'I may not make it home, but I want you to know — it matters. What we're doing here. It matters.'",
            "We hold. We cannot afford to lose the Starbase."
        ],
        speaker: "Zzrr'tkal"
    )
    
    /// Glory Run: fires around turn 18.
    private static let gloryRun = StoryEvent(
        id: "glory_run",
        title: "The Glory Run",
        paragraphs: [
            "The Xhofi have volunteered for a Glory Run. Entire squadrons, racing toward Dominion fortifications at full burn — no return.",
            "It is the most feared — and most tragic — weapon in the Compact arsenal. The Xhofi understand what they are sacrificing.",
            "The fortifications crack. The way forward opens. We owe them everything."
        ],
        speaker: "Jorin Vael"
    )
    
    /// Final push: fires around turn 20.
    private static let finalPush = StoryEvent(
        id: "final_push",
        title: "The Final Push",
        paragraphs: [
            "Zzrr'tkal has revealed the location of the Vexari command nexus — a massive structure at the heart of Dominion space.",
            "The Vexari Overmind is pulling Bonded fleets from distant systems to crush us. This is the last battle.",
            "This is the last fleet. If it fails, the Compact falls. If it succeeds, the galaxy is free.",
            "Godspeed."
        ],
        speaker: "Zzrr'tkal"
    )
    
    /// Victory epilogue (Compact wins).
    private static let compactVictory = StoryEvent(
        id: "compact_victory",
        title: "Victory",
        paragraphs: [
            "The command nexus burns. Slave shields over Barrier Worlds collapse. Across the Reach, Bonded species rise up against their captors.",
            "The Chorus — the Vexari Overmind's voice — issues one final broadcast. Not of anger. Something almost like relief.",
            "The war is over.",
            "Elara Moss writes: 'We made it home.'",
            "Jorin Vael stands at the ruined nexus: 'Tell them it was worth it.'"
        ],
        speaker: nil
    )
    
    /// Victory epilogue (Dominion wins).
    private static let dominionVictory = StoryEvent(
        id: "dominion_victory",
        title: "Defeat",
        paragraphs: [
            "The Compact's last fleet is destroyed. The final free systems fall. Slave shields close over the remaining Barrier Worlds.",
            "The Chorus broadcasts a message of 'salvation' to the galaxy.",
            "But in the void beyond the front lines, a single Compact ship — badly damaged, crew reduced to a handful — slips into uncharted space.",
            "It carries a data core: everything the Compact learned about the Vexari. Their tactics. Their weaknesses.",
            "The ship's final transmission: 'We are not gone. We are seeding. Wait for us.'"
        ],
        speaker: nil
    )
    
    /// Check campaign state and return events that should fire this turn.
    /// firedEvents is the set of event IDs already shown.
    public static func checkEvents(
        turn: Int,
        faction: Faction,
        firedEvents: Set<String>,
        isVictory: Bool,
        winner: Faction?
    ) -> [StoryEvent] {
        var events: [StoryEvent] = []
        
        for event in all {
            guard !firedEvents.contains(event.id) else { continue }
            
            let shouldFire: Bool
            switch event.id {
            case "opening_briefing":
                shouldFire = turn == 1 && faction == .compact
            case "first_loss":
                shouldFire = turn >= 3 && turn <= 6
            case "keshvarr_defects":
                shouldFire = turn == 5
            case "first_barrier_world":
                shouldFire = turn == 8
            case "mid_crisis":
                shouldFire = turn == 12
            case "glory_run":
                shouldFire = turn == 18
            case "final_push":
                shouldFire = turn == 20
            case "compact_victory":
                shouldFire = isVictory && winner == .compact
            case "dominion_victory":
                shouldFire = isVictory && winner == .dominion
            default:
                shouldFire = false
            }
            
            if shouldFire {
                events.append(event)
            }
        }
        
        return events
    }
}