import XCTest
@testable import StarfallCampaign
import StarfallData

final class CampaignStoryTests: XCTestCase {
    
    func testOpeningBriefingExists() {
        let opening = CampaignStory.all.first(where: { $0.id == "opening_briefing" })
        XCTAssertNotNil(opening)
        XCTAssertEqual(opening?.speaker, "Jorin Vael")
        XCTAssertGreaterThan(opening!.paragraphs.count, 0)
    }
    
    func testVictoryEventsExist() {
        let compactV = CampaignStory.all.first(where: { $0.id == "compact_victory" })
        let dominionV = CampaignStory.all.first(where: { $0.id == "dominion_victory" })
        XCTAssertNotNil(compactV)
        XCTAssertNotNil(dominionV)
        XCTAssertNotNil(compactV?.title)
        XCTAssertNotNil(dominionV?.title)
    }
    
    func testAllEventsHaveParagraphs() {
        for event in CampaignStory.all {
            XCTAssertGreaterThan(event.paragraphs.count, 0,
                                  "Event \(event.id) has no paragraphs")
            XCTAssertFalse(event.title.isEmpty,
                           "Event \(event.id) has no title")
        }
    }
    
    func testNoDuplicateEventIds() {
        let ids = CampaignStory.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate event IDs found")
    }
    
    func testCheckEventsFiresOpeningAtTurn1() {
        let events = CampaignStory.checkEvents(
            turn: 1,
            faction: .compact,
            firedEvents: [],
            isVictory: false,
            winner: nil
        )
        
        XCTAssert(events.contains { $0.id == "opening_briefing" })
    }
    
    func testCheckEventsDoesNotFireOpeningForDominion() {
        let events = CampaignStory.checkEvents(
            turn: 1,
            faction: .dominion,
            firedEvents: [],
            isVictory: false,
            winner: nil
        )
        
        XCTAssertFalse(events.contains { $0.id == "opening_briefing" })
    }
    
    func testFiredEventsAreSkipped() {
        let events = CampaignStory.checkEvents(
            turn: 1,
            faction: .compact,
            firedEvents: ["opening_briefing"],
            isVictory: false,
            winner: nil
        )
        
        XCTAssertFalse(events.contains { $0.id == "opening_briefing" })
    }
    
    func testVictoryEventFiresOnGameOver() {
        let events = CampaignStory.checkEvents(
            turn: 25,
            faction: .compact,
            firedEvents: [],
            isVictory: true,
            winner: .compact
        )
        
        XCTAssert(events.contains { $0.id == "compact_victory" })
    }
    
    func testDefeatEventFiresOnGameOver() {
        let events = CampaignStory.checkEvents(
            turn: 25,
            faction: .compact,
            firedEvents: [],
            isVictory: true,
            winner: .dominion
        )
        
        XCTAssert(events.contains { $0.id == "dominion_victory" })
    }
    
    func testTurnBasedEventsFireAtCorrectTurn() {
        // Kesh-Varr at turn 5.
        let t5 = CampaignStory.checkEvents(
            turn: 5, faction: .compact, firedEvents: [],
            isVictory: false, winner: nil
        )
        XCTAssert(t5.contains { $0.id == "keshvarr_defects" })
        
        // Barrier world at turn 8.
        let t8 = CampaignStory.checkEvents(
            turn: 8, faction: .compact, firedEvents: [],
            isVictory: false, winner: nil
        )
        XCTAssert(t8.contains { $0.id == "first_barrier_world" })
        
        // Mid-crisis at turn 12.
        let t12 = CampaignStory.checkEvents(
            turn: 12, faction: .compact, firedEvents: [],
            isVictory: false, winner: nil
        )
        XCTAssert(t12.contains { $0.id == "mid_crisis" })
        
        // Glory run at turn 18.
        let t18 = CampaignStory.checkEvents(
            turn: 18, faction: .compact, firedEvents: [],
            isVictory: false, winner: nil
        )
        XCTAssert(t18.contains { $0.id == "glory_run" })
        
        // Final push at turn 20.
        let t20 = CampaignStory.checkEvents(
            turn: 20, faction: .compact, firedEvents: [],
            isVictory: false, winner: nil
        )
        XCTAssert(t20.contains { $0.id == "final_push" })
    }
    
    func testEventCount() {
        // We defined 9 story events total.
        XCTAssertEqual(CampaignStory.all.count, 9)
    }
}