// Generator för webbversionens gyllene spår (prototyper/webb/test/spar/).
// Körs mot BrytareModell från grenen fm/tg-proto-brytare (omgång 9):
//   SPAR_UT=/tmp/spar.json swift test --filter Spar
// Skriver ett JSON-dokument där varje runda är en följd av ögonblicksbilder efter varje steg.
// Flyttal skrivs med Swifts kortaste exakta form, så att JS kan jämföra exakt efter JSON.parse.

import Foundation
import Testing
@testable import BrytareModell

private func q(_ s: String) -> String {
    var out = "\""
    for u in s.unicodeScalars {
        switch u {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        default:
            if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
        }
    }
    return out + "\""
}
private func q(_ s: String?) -> String { s.map { q($0) } ?? "null" }
private func num(_ x: Double) -> String { "\(x)" }
private func arr(_ xs: [String]) -> String { "[" + xs.joined(separator: ",") + "]" }

private func kindName(_ k: NewsItem.Kind) -> String {
    switch k { case .real: return "real"; case .rumor: return "rumor"; case .anonymous: return "anonymous" }
}
private func tagName(_ t: NewsItem.Tag) -> String {
    switch t { case .opens: return "opens"; case .locks: return "locks"; case .lampOut: return "lampOut"; case .none: return "none" }
}
private func noticeName(_ k: Notice.Kind) -> String {
    switch k { case .rumor: return "rumor"; case .whatIf: return "whatIf"; case .info: return "info"; case .real: return "real" }
}
private func toneName(_ t: Effect.Tone) -> String {
    switch t { case .bad: return "bad"; case .neutral: return "neutral"; case .good: return "good" }
}
private func relName(_ k: RelationKind) -> String {
    switch k { case .attraction: return "attraction"; case .negotiating: return "negotiating"; case .conflict: return "conflict" }
}

private func choices(_ cs: [Choice]) -> String {
    arr(cs.map { arr([q($0.id), q($0.title), q($0.quip), q($0.icon), q($0.preview)]) })
}

private func snap<G: ClockGame>(_ g: G, extra: String) -> String {
    let p = g.paused.map { arr([String($0.day), q(kindName($0.kind)), q($0.title), q($0.source), q(tagName($0.tag))]) } ?? "null"
    let m = arr(g.meters.map { arr([q($0.name), q($0.value), q($0.caption)]) })
    let b = arr(g.bars.map { arr([q($0.label), num($0.value), num($0.ghost), num($0.max), arr($0.marks.map(num)), $0.isLeading ? "true" : "false"]) })
    let n = arr(g.notices.map { arr([String($0.day), q(noticeName($0.kind)), q($0.text)]) })
    let e = g.effect.map { arr([q($0.title), q(toneName($0.tone)), arr($0.chips.map { q($0) }), q($0.reason)]) } ?? "null"
    let end = g.ending.map { arr([q($0.title), q($0.text), $0.isExtraval ? "true" : "false", q($0.footnote)]) } ?? "null"
    let r = arr(g.relations.map { arr([q($0.pair.a.rawValue), q($0.pair.b.rawValue), q(relName($0.kind)), q($0.label), $0.isNew ? "true" : "false", $0.isRumor ? "true" : "false"]) })
    return "{\"d\":\(g.day),\"p\":\(p),\"m\":\(m),\"b\":\(b),\"nc\":\(choices(g.newsChoices)),\"c\":\(choices(g.cards)),\"n\":\(n),\"e\":\(e),\"end\":\(end),\"r\":\(r),\"x\":\(extra)}"
}

private func newsExtra(_ g: NewsKnotGame) -> String {
    "[\(g.spaltmeter),\(g.lamps),\(g.moves),\(g.gifts)]"
}

private func systemExtra(_ g: SystemKnotGame) -> String {
    let pat = arr(P.allCases.map { num(g.patience[$0]!) })
    let ch = arr(Stamp.allCases.map { String(g.charges[$0]!) })
    return "[\(pat),\(ch),\(g.lamps),\(g.moves),\(g.gifts)]"
}

/// Bottarna. "passive" och "active"/"awake" är testernas egna; "varied" går igenom knapparna i tur.
private func newsTrace(_ s: NewsKnotSettings, bot: String) -> [String] {
    var g = NewsKnotGame(settings: s)
    var out = [snap(g, extra: newsExtra(g))]
    for k in 0..<400 where g.ending == nil {
        if g.paused != nil {
            let c = g.newsChoices
            if bot == "active", let hit = c.first(where: { $0.id.hasPrefix("remind") }) { g.play(hit.id) }
            else if bot == "varied", !c.isEmpty { g.play(c[k % c.count].id) }
            else if let last = c.last { g.play(last.id) } else { g.resume() }
            out.append(snap(g, extra: newsExtra(g)))
            continue
        }
        if bot == "active", let leak = g.cards.first(where: { $0.id.hasPrefix("leak") }) { g.play(leak.id) }
        else if bot == "active", let sega = g.cards.first(where: { $0.id == "sega" }) { g.play(sega.id) }
        else if bot == "varied", !g.cards.isEmpty, k % 3 != 2 { g.play(g.cards[k % g.cards.count].id) }
        g.tick(days: 1)
        out.append(snap(g, extra: newsExtra(g)))
    }
    return out
}

private func systemTrace(seed: UInt64, hard: Bool, bot: String) -> [String] {
    var g = SystemKnotGame(seed: seed, hardLinesCanFall: hard)
    var out = [snap(g, extra: systemExtra(g))]
    for k in 0..<200 where g.ending == nil {
        if g.paused != nil { g.resume() }
        if bot == "awake" { awakeMove(&g) }
        if bot == "varied", k % 4 == 0, !g.cards.isEmpty { g.play(g.cards[(k / 4) % g.cards.count].id) }
        // "krav": KRAV på L så fort stämpeln är laddad, så att två krav i rad får L att spricka.
        if bot == "krav", g.charges[.demand]! > 0 { g.demand(.L) }
        g.tick(days: 1)
        out.append(snap(g, extra: systemExtra(g)))
    }
    return out
}

private func systemSummary(seed: UInt64, hard: Bool, bot: SystemBot) -> String {
    var g = SystemKnotGame(seed: seed, hardLinesCanFall: hard)
    for _ in 0..<200 where g.ending == nil {
        if g.paused != nil { g.resume() }
        if bot == .awake { awakeMove(&g) }
        g.tick(days: 1)
    }
    return arr([q(g.ending?.title), String(g.day), String(g.lamps), String(g.moves), String(g.gifts)])
}

@Suite("Spår för webbversionen")
struct SparTests {
    @Test("Skriv spåren")
    func skriv() throws {
        guard let path = ProcessInfo.processInfo.environment["SPAR_UT"] else { return }
        var rounds: [String] = []
        let base = NewsKnotSettings()
        var settings: [(String, NewsKnotSettings)] = [("forval", base)]
        var s = base; s.rumors = .alsoRealPartyMeetings; settings.append(("partimoten", s))
        s = base; s.leakWhileRunning = false; settings.append(("ingenLacka", s))
        s = base; s.anonymousSources = false; settings.append(("ingaAnonyma", s))
        s = base; s.finale = false; settings.append(("ingenSlutspurt", s))
        s = NewsKnotSettings(); s.rumors = .alsoRealPartyMeetings; s.leakWhileRunning = false; s.anonymousSources = false; s.finale = false
        settings.append(("allaB", s))
        for (name, st) in settings {
            for bot in ["passive", "active", "varied"] {
                let meta = "{\"rumors\":\(q(st.rumors.rawValue)),\"leakWhileRunning\":\(st.leakWhileRunning),\"anonymousSources\":\(st.anonymousSources),\"finale\":\(st.finale)}"
                rounds.append("{\"game\":\"news\",\"name\":\(q(name)),\"bot\":\(q(bot)),\"settings\":\(meta),\"steps\":\(arr(newsTrace(st, bot: bot)))}")
            }
        }
        for hard in [false, true] {
            for seed: UInt64 in [0, 7, 42] {
                for bot in ["passive", "awake", "varied"] {
                    rounds.append("{\"game\":\"system\",\"seed\":\"\(seed)\",\"hard\":\(hard),\"bot\":\(q(bot)),\"steps\":\(arr(systemTrace(seed: seed, hard: hard, bot: bot)))}")
                }
            }
        }
        for seed: UInt64 in [0, 7] {
            rounds.append("{\"game\":\"system\",\"seed\":\"\(seed)\",\"hard\":false,\"bot\":\"krav\",\"steps\":\(arr(systemTrace(seed: seed, hard: false, bot: "krav")))}")
        }
        // Stora seeds (över 2^53) prövar att 64-bitarsaritmetiken stämmer.
        for seed: UInt64 in [UInt64.max, 0x9E37_79B9_7F4A_7C15, 1 << 63] {
            rounds.append("{\"game\":\"system\",\"seed\":\"\(seed)\",\"hard\":false,\"bot\":\"varied\",\"steps\":\(arr(systemTrace(seed: seed, hard: false, bot: "varied")))}")
        }
        var summary: [String] = []
        for hard in [false, true] {
            for bot in [SystemBot.passive, .awake] {
                let rows = (0..<200).map { systemSummary(seed: UInt64($0), hard: hard, bot: bot) }
                summary.append("{\"hard\":\(hard),\"bot\":\(q(bot == .passive ? "passive" : "awake")),\"rows\":\(arr(rows))}")
            }
        }
        let dates = arr((0...80).map { q(dateText(day: $0)) })
        var rng = SeededRandom(seed: 12345)
        let random = arr((0..<20).map { _ in q(String(rng.next())) })
        let doc = "{\"source\":\"BrytareModell, fm/tg-proto-brytare 2d297ff\",\"dates\":\(dates),\"random\":\(random),\"rounds\":\(arr(rounds)),\"summary\":\(arr(summary))}"
        try doc.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
