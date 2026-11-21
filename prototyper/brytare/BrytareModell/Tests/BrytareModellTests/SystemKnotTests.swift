import Testing
@testable import BrytareModell

/// Rapportens testspelare (Bilaga B): passiv och vaken.
enum SystemBot { case passive, awake }

func awakeMove(_ g: inout SystemKnotGame) {
    for t in g.tracks.values.filter(\.active).sorted(by: { g.meter($0).solid > g.meter($1).solid }) {
        let (solid, soon) = g.wouldLockSoon(t)
        let voteSoon = g.votes.contains { $0.track == t.name && $0.day - g.day <= 1 }
        guard solid >= 175 || soon >= 175 else { continue }
        let opts = g.swingOptions(t).filter { $0.risk > 18 }.sorted { ($0.seats, $0.risk) > ($1.seats, $1.risk) }
        if let o = opts.first, g.charges[.leak]! > 0 { g.leak(o.x, o.y); return }
        if voteSoon && g.charges[.delay]! > 0 { g.delay(); return }
        if solid >= 175 && g.charges[.delay]! > 0 { g.delay(); return }
    }
    // Säkring: ett parti med nästan tom stubin vars eftergift skulle ge ett spår 175.
    for x in P.allCases.sorted(by: { g.patience[$0]! < g.patience[$1]! }) {
        if g.patience[x]! > 14 || g.charges[.demand]! == 0 { break }
        let mine = g.constraints.filter { $0.party == x && !$0.player }.sorted { !$0.hard && $1.hard }
        guard let first = mine.first, !g.constraints.contains(where: { $0.player && $0.party == x && g.day <= $0.until }) else { continue }
        var probe = g
        probe.constraints.removeAll { $0.id == first.id }
        if probe.tracks.values.filter(\.active).contains(where: { probe.wouldLockSoon($0).soon >= 175 }) {
            g.demand(x); return
        }
    }
}

func playRound(seed: UInt64, bot: SystemBot) -> SystemKnotGame {
    var g = SystemKnotGame(seed: seed)
    for _ in 0..<200 where g.ending == nil {
        if g.paused != nil { g.resume() }
        if bot == .awake { awakeMove(&g) }
        g.tick(days: 1)
    }
    return g
}

@Suite("Systemknuten")
struct SystemKnotTests {
    @Test("Aritmetiken: Blått M+KD+L är 111 på valnatten och Ribban startar under 175")
    func start() {
        let g = SystemKnotGame(seed: 1)
        #expect(g.meter(g.tracks["Blått"]!).solid == 111)
        #expect(g.bars.allSatisfy { $0.value < 175 })
        #expect(g.charges[.leak] == 1)          // LÄCKA upplåst dag 0
    }

    @Test("Samma seed ger samma runda")
    func deterministisk() {
        let a = playRound(seed: 42, bot: .passive), b = playRound(seed: 42, bot: .passive)
        #expect(a.ending == b.ending)
        #expect(a.day == b.day)
    }

    @Test("Klockan stannar vid verkliga nyheter och gåvor laddar stämplar")
    func nyheter() {
        var g = SystemKnotGame(seed: 3)
        while g.day < 5 { if g.paused != nil { g.resume() }; g.tick(days: 1) }
        #expect(g.paused?.kind == .real)
        #expect(g.paused?.source.contains("#4") == true)
    }

    @Test("Läckan sänker tråden, ett färskt handslag hårdare")
    func lacka() {
        var g = SystemKnotGame(seed: 5)
        let before = g.rel[Pair(.S, .MP)]!
        g.leak(.S, .MP)
        #expect(g.rel[Pair(.S, .MP)]! == max(-100, before - 40))
        #expect(g.moves == 1)
        #expect(g.charges[.leak] == 0)
    }

    @Test("Två krav på samma parti får det att spricka och släppa sina mjuka krav")
    func spricker() {
        var g = SystemKnotGame(seed: 6)
        while g.day < 14 { if g.paused != nil { g.resume() }; g.tick(days: 1) }   // KRAV laddas igen dag 14
        g.demand(.L)
        #expect(g.constraints.contains { $0.player && $0.party == .L })
        while g.charges[.demand]! == 0 { if g.paused != nil { g.resume() }; g.tick(days: 1) }
        g.demand(.L)
        #expect(!g.constraints.contains { $0.party == .L && !$0.hard })
    }

    @Test("Simuleringen: utan drag vinner man ibland, med vaken läsning oftast (rapportens spann)")
    func vinstandel() {
        let n = 200
        let passive = (0..<n).filter { playRound(seed: UInt64($0), bot: .passive).ending?.isExtraval == true }.count
        let awake = (0..<n).filter { playRound(seed: UInt64($0), bot: .awake).ending?.isExtraval == true }.count
        #expect((Double(passive) / Double(n)) >= 0.10 && (Double(passive) / Double(n)) <= 0.45, "passiv \(passive)/\(n)")
        #expect(Double(awake) / Double(n) >= 0.70, "vaken \(awake)/\(n)")
        #expect(awake > passive)
    }

    @Test("Hårda röda linjer faller inte av tålamod i förvalet")
    func hardaLinjer() {
        for seed in 0..<30 {
            let g = playRound(seed: UInt64(seed), bot: .passive)
            #expect(g.constraints.contains { $0.id == "C-inteV" }, "seed \(seed)")
        }
    }
}
