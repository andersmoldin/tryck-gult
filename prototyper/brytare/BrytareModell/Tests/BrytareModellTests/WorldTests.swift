import Testing
@testable import BrytareModell

@Suite("Klockan och nyheterna")
struct WorldTests {
    @Test("Dag 0 är valdagen 13 sep, dag 66 är 18 nov")
    func datum() {
        #expect(dateText(day: 0) == "13 sep")
        #expect(dateText(day: 18) == "1 okt")
        #expect(dateText(day: 32) == "15 okt")
        #expect(dateText(day: lastDay) == "18 nov")
    }

    @Test("Tiden går tills en nyhet kommer, stannar, och går vidare när spelaren fortsätter")
    func pausVidNyhet() {
        var w = World(rumors: .ownMovesOnly)
        w.tick(days: 10)
        #expect(w.day == 1)
        #expect(w.paused?.kind == .real)
        #expect(w.paused?.day == 1)
        let before = w.day
        w.tick(days: 3)
        #expect(w.day == before)                 // står still medan nyheten visas
        w.resume()
        #expect(w.paused == nil)
        w.tick(days: 2)
        #expect(w.day == 3)
    }

    @Test("En verklig nyhet ändrar förutsättningarna")
    func nyhetAndrar() {
        var w = World(rumors: .ownMovesOnly)
        #expect(w.relation(.V, .C)?.kind != .conflict)
        w.tick(days: 1)
        #expect(w.relation(.V, .C)?.kind == .conflict)
    }

    @Test("Verkliga nyheter kommer i datumordning och slutar sista dagen")
    func ordning() {
        let days = realNews.map(\.day)
        #expect(days == days.sorted())
        #expect(days.allSatisfy { (0...lastDay).contains($0) })
        var w = World(rumors: .ownMovesOnly)
        var seen = 0
        while !w.isOver {
            w.tick(days: 100)
            if w.paused != nil { seen += 1; w.resume() }
        }
        #expect(seen == realNews.count)
        #expect(w.day == lastDay)
    }

    @Test("Ryktesläget: bara egna drag ger inga påhittade partimöten, det andra läget gör det")
    func ryktesLage() {
        func rumors(_ mode: RumorMode) -> [NewsItem] {
            var w = World(rumors: mode)
            var out: [NewsItem] = []
            while !w.isOver {
                w.tick(days: 100)
                if let n = w.paused { if n.kind == .rumor { out.append(n) }; w.resume() }
            }
            return out
        }
        #expect(rumors(.ownMovesOnly).isEmpty)
        let meetings = rumors(.alsoRealPartyMeetings)
        #expect(meetings.count >= 4)
        #expect(meetings.allSatisfy { !$0.changes.isEmpty })
    }

    @Test("Ett eget drag kan ge ett rykte i båda lägena")
    func egetDrag() {
        for mode in [RumorMode.ownMovesOnly, .alsoRealPartyMeetings] {
            var w = World(rumors: mode)
            w.scheduleRumor("Ditt utspel har läckt.", changes: [])
            w.tick(days: 1)
            #expect(w.paused?.kind == .rumor)
            #expect(w.paused?.title == "Ditt utspel har läckt.")
        }
    }
}
