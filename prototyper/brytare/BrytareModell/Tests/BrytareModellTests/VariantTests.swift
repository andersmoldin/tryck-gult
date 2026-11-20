import Testing
@testable import BrytareModell

/// Kör klockan tills en nyhet visas eller spelet tar slut, och läs bort alla nyheter som väntar.
func advance<G: ClockGame>(_ g: inout G, days: Int = 1) {
    g.tick(days: days)
    readNews(&g)
}

func readNews<G: ClockGame>(_ g: inout G) {
    while g.world.paused != nil && g.ending == nil { g.resume() }
}

@Suite("Knuten")
struct KnutenTests {
    @Test("Gör man ingenting hinner Uppgörelsen före – en påhittad regering, märkt Tänk om")
    func passiv() {
        var g = KnutenGame(rumors: .ownMovesOnly)
        for _ in 0..<200 where g.ending == nil { advance(&g, days: 3) }
        #expect(g.ending?.title == "TÄNK OM: EN REGERING")
        #expect(g.ending?.isExtraval == false)
    }

    @Test("Låsande verkliga nyheter är gåvor: Prestige utan att spelaren gör något")
    func gava() {
        var g = KnutenGame(rumors: .ownMovesOnly)
        let before = g.prestige
        g.tick(days: 1)                          // dag 1: V–C låses
        #expect(g.world.paused?.tag == .locks)
        #expect(g.prestige == before + 3)
    }

    @Test("Röd linje gör en bro till konflikt och kostar Prestige")
    func rodLinje() {
        var g = KnutenGame(rumors: .ownMovesOnly)
        while g.world.relation(.C, .S)?.kind != .negotiating { advance(&g) }   // C öppnar för S, 15 okt
        readNews(&g)
        let card = g.cards.first { $0.id.hasPrefix("redline") }!
        let p = g.prestige
        g.play(card.id)
        #expect(g.world.relation(.C, .S)?.kind == .conflict)
        #expect(g.prestige == p - KnutenGame.redLineCost)
        #expect(g.effect?.title == "RÖD LINJE")
    }

    @Test("Utspel sänker Uppgörelsen, Sega stoppar den några dagar")
    func utspelOchSega() {
        var g = KnutenGame(rumors: .ownMovesOnly)
        while g.settlement < 20 { advance(&g) }
        readNews(&g)
        var withSega = g
        var without = g
        let s = g.settlement
        g.play("utspel")
        #expect(g.settlement == max(0, s - Double(KnutenGame.utspelDrop)))
        withSega.play("sega")
        for _ in 0..<3 { advance(&withSega); advance(&without) }
        #expect(withSega.settlement < without.settlement)
    }

    @Test("Spelar man aktivt kan knuten hålla till extraval, och domen räknar partiledarnas hjälp")
    func vinst() {
        var g = KnutenGame(rumors: .ownMovesOnly)
        for _ in 0..<400 where g.ending == nil {
            if let c = g.cards.first(where: { $0.id.hasPrefix("redline") }) ?? g.cards.first(where: { $0.id == "sega" }) ?? g.cards.first(where: { $0.id == "utspel" }) {
                g.play(c.id)
            }
            advance(&g)
        }
        #expect(g.ending?.isExtraval == true)
        #expect(g.ending?.text.contains("Partiledarna gjorde") == true)
    }
}

@Suite("Hamna i regering")
struct RegeringTests {
    @Test("Regeringsberäkningen: S med V och MP har 151 och faller mot 198 nej")
    func berakning() {
        let g = RegeringGame(party: .S, rumors: .ownMovesOnly)
        let r = g.prospect
        #expect(Set(r.government) == [.S, .V, .MP])
        #expect(r.result.supportSeats == 151)
        #expect(!r.result.passed)
    }

    @Test("Ett erbjudande om ministerposter kostar röda linjer mot erbjudandets fiender")
    func erbjudande() {
        var g = RegeringGame(party: .M, rumors: .ownMovesOnly)
        while g.world.day < 54 && g.ending == nil { advance(&g) }
        g.kapital = 10
        g.play("ring.C")
        g.play("offer.C")
        #expect(g.world.relation(.M, .C)?.kind == .attraction)
        #expect(g.world.relation(.M, .V)?.kind == .conflict)        // V krockar med C
    }

    @Test("En verklig nyhet kan stänga en väg")
    func stanger() {
        var g = RegeringGame(party: .C, rumors: .ownMovesOnly)
        g.kapital = 10
        g.play("ring.V")
        #expect(g.world.relation(.C, .V)?.kind == .negotiating)
        g.tick(days: 1)
        #expect(g.world.relation(.C, .V)?.kind == .conflict)
    }

    @Test("Går omröstningen igenom vinner man – märkt Tänk om")
    func vinst() {
        var g = RegeringGame(party: .M, rumors: .ownMovesOnly)
        while g.world.day < 54 && g.ending == nil { advance(&g) }     // SD tolererar
        g.kapital = 20
        g.play("ring.C"); g.play("offer.C")
        g.play("vote")
        #expect(g.ending?.title == "TÄNK OM: M I REGERING")
        #expect(g.ending?.text.contains("Det hände inte i verkligheten.") == true)
    }

    @Test("Fallna omröstningar släcker lampor; utan lampor blir det extraval")
    func lampor() {
        var g = RegeringGame(party: .V, rumors: .ownMovesOnly)
        for _ in 0..<4 { g.play("vote") }
        #expect(g.lamps == 0)
        #expect(g.ending?.isExtraval == true)
    }

    @Test("Alla partier går att välja och spelet tar alltid slut")
    func allaPartier() {
        for p in P.allCases {
            var g = RegeringGame(party: p, rumors: .alsoRealPartyMeetings)
            for _ in 0..<300 where g.ending == nil { advance(&g, days: 2) }
            #expect(g.ending != nil, "\(p.rawValue)")
        }
    }
}
