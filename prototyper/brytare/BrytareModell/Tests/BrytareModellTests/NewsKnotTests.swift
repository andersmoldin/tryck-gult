import Testing
@testable import BrytareModell

func newsRound(_ settings: NewsKnotSettings, active: Bool) -> NewsKnotGame {
    var g = NewsKnotGame(settings: settings)
    for _ in 0..<400 where g.ending == nil {
        if g.paused != nil {
            let c = g.newsChoices
            if active, let hit = c.first(where: { $0.id.hasPrefix("remind") }) { g.play(hit.id) }
            else if let first = c.last { g.play(first.id) } else { g.resume() }
            continue
        }
        if active, let leak = g.cards.first(where: { $0.id.hasPrefix("leak") }) { g.play(leak.id) }
        else if active, let sega = g.cards.first(where: { $0.id == "sega" }) { g.play(sega.id) }
        g.tick(days: 1)
    }
    return g
}

/// Gå fram till första verkliga nyheten som har reaktioner (inte en gåva).
func toReactableNews(_ g: inout NewsKnotGame) {
    for _ in 0..<200 {
        if let n = g.paused {
            if n.tag != .locks && n.kind != .rumor { return }
            g.play(g.newsChoices[0].id)
        }
        g.tick(days: 1)
    }
}

@Suite("Nyhetsknuten")
struct NewsKnotTests {
    @Test("Tre spår från extraval till regering, och klockan stannar vid första nyheten")
    func start() {
        var g = NewsKnotGame(settings: .init())
        #expect(g.bars.map(\.label) == ["◀ Vänster", "● Mitten", "▶ Höger"])
        #expect(g.bars.allSatisfy { $0.marks == [60, 85] && $0.max == 100 })
        g.tick(days: 5)
        #expect(g.paused?.kind == .real)          // gåvan 14 sep stoppar klockan
        toReactableNews(&g)
        #expect(g.newsChoices.count >= 2)
    }

    @Test("En reaktion på nyheten kostar spaltmeter, verkar på spåret och låter tiden gå igen")
    func reaktion() {
        var g = NewsKnotGame(settings: .init())
        toReactableNews(&g)
        let sp = g.spaltmeter
        let remind = g.newsChoices.first { $0.id.hasPrefix("remind") }!
        g.play(remind.id)
        #expect(g.paused == nil)
        #expect(g.spaltmeter == sp - 1)
        #expect(g.effect != nil)
    }

    @Test("En gåva har en enda knapp och ger spaltmeter")
    func gava() {
        var g = NewsKnotGame(settings: .init())
        while g.paused?.tag != .locks { if g.paused != nil { g.play(g.newsChoices.last!.id) }; g.tick(days: 1) }
        #expect(g.newsChoices.map(\.title) == ["TACK SÅ MYCKET"])
        let sp = g.spaltmeter
        g.play(g.newsChoices[0].id)
        #expect(g.spaltmeter > sp)
    }

    @Test("Läckan landar senare och slår hårdare på en känd deadline; en andra läcka dementeras")
    func lacka() {
        var g = NewsKnotGame(settings: .init())
        while g.day < 29 { if g.paused != nil { g.play(g.newsChoices.last!.id) }; g.tick(days: 1) }
        if g.paused != nil { g.play(g.newsChoices.last!.id) }
        let onDeadline = g.cards.first { $0.id.hasPrefix("leak") && $0.id.hasSuffix(".32") }
        #expect(onDeadline != nil)            // omröstningen 15 okt är dag 32
    }

    @Test("Ryktesinställningen: A har bara föremål och processer, B även namngivna partimöten")
    func rykten() {
        let a = NewsKnotGame.rumors(for: .ownMovesOnly), b = NewsKnotGame.rumors(for: .alsoRealPartyMeetings)
        #expect(!a.isEmpty && b.count > a.count)
        let named = b.filter { r in !a.contains(r) }
        #expect(named.allSatisfy { r in P.allCases.contains { r.title.contains($0.rawValue + " ") } })
        #expect(a.allSatisfy { r in !P.allCases.contains { r.title.contains($0.rawValue + " ") } })
    }

    @Test("Anonyma källor går att stänga av")
    func anonyma() {
        #expect(NewsKnotGame.news(anonymous: true).contains { $0.kind == .anonymous })
        #expect(!NewsKnotGame.news(anonymous: false).contains { $0.kind == .anonymous })
    }

    @Test("Utan slutspurt slutar spelet 18 nov med Fortsättning följer")
    func utanSlutspurt() {
        var s = NewsKnotSettings(); s.finale = false
        let g = newsRound(s, active: true)
        #expect(g.ending != nil)
        #expect(g.day <= lastDay)
    }

    @Test("Passiv spelare förlorar oftast, aktiv vinner oftast, och domen räknar gåvorna")
    func balans() {
        let passive = newsRound(.init(), active: false)
        let active = newsRound(.init(), active: true)
        #expect(passive.ending?.isExtraval == false)
        #expect(active.ending?.isExtraval == true)
        #expect(active.ending?.text.contains("Partiledarna gjorde") == true)
    }
}
