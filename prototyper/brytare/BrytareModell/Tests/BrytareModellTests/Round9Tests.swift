import Testing
@testable import BrytareModell

@Suite("Omgång 9: läsbarhet och två nyhetsnivåer")
struct Round9Tests {
    @Test("Nyhetsknuten: rykten stoppar inte tiden utan blir aviseringar")
    func ryktenAviseras() {
        var s = NewsKnotSettings(); s.rumors = .alsoRealPartyMeetings
        var g = NewsKnotGame(settings: s)
        var pausedOnRumor = false
        while g.day < 40 && g.ending == nil {
            if let n = g.paused { if n.kind == .rumor { pausedOnRumor = true }; g.play(g.newsChoices.last!.id) }
            g.tick(days: 1)
        }
        #expect(!pausedOnRumor)
        #expect(g.notices.contains { $0.kind == .rumor && $0.text.contains("C och S har setts äta lunch") })
    }

    @Test("Nyhetsknuten: varje knapp visar riktning, storlek och kostnad före valet")
    func forhandsvisning() {
        var g = NewsKnotGame(settings: .init())
        toReactableNews(&g)
        #expect(g.newsChoices.allSatisfy { ($0.preview ?? "").isEmpty == false })
        let remind = g.newsChoices.first { $0.id.hasPrefix("remind") }!
        #expect(remind.preview!.contains("1 spaltmeter"))
        #expect(remind.preview!.contains("▼") || remind.preview!.contains("ingen effekt"))
        g.play(remind.id)
        #expect(g.effect?.reason != nil)
        while g.cards.isEmpty && g.ending == nil { if g.paused != nil { g.play(g.newsChoices.last!.id) }; g.tick(days: 1) }
        #expect(g.cards.allSatisfy { ($0.preview ?? "").isEmpty == false })
    }

    @Test("Systemknuten: förhandsvisningen av en läcka stämmer med vad som händer")
    func systemForhandsvisning() {
        var g = SystemKnotGame(seed: 11)
        while g.cards.first(where: { $0.id.hasPrefix("leak") }) == nil { if g.paused != nil { g.resume() }; g.tick(days: 1) }
        let leak = g.cards.first { $0.id.hasPrefix("leak") }!
        let lead = g.leading.name
        var copy = g
        copy.play(leak.id)
        let after = Int(copy.meter(copy.tracks[lead]!).solid)
        #expect(leak.preview!.contains("Ribban \(lead)"))
        #expect(leak.preview!.contains("→ \(after)"))
        g.play(leak.id)
        #expect(g.effect?.reason != nil)
    }

    @Test("Systemknuten: simuleringens påhitt blir aviseringar, inte nyhetskort")
    func systemAviseringar() {
        var g = SystemKnotGame(seed: 2)
        for _ in 0..<70 where g.ending == nil { if g.paused != nil { #expect(g.paused?.kind == .real); g.resume() }; g.tick(days: 1) }
        #expect(g.notices.allSatisfy { $0.kind != .real })
    }
}
