import Testing
@testable import BrytareModell

@Suite("Grafen")
struct GraphTests {
    func rel(_ h: Int, _ a: P, _ b: P) -> KeyRelation? {
        keyRelations(after: h).first { $0.pair == Pair(a, b) }
    }

    @Test("Få, tydliga linjer med etikett i varje läge")
    func fa() {
        for h in 0...timelineEnd {
            let r = keyRelations(after: h)
            #expect((6...10).contains(r.count), "rubrik \(h): \(r.count) linjer")
            #expect(r.allSatisfy { !$0.label.isEmpty })
        }
    }

    @Test("Valnatten: blocken och C:s två nej")
    func valnatten() {
        #expect(rel(0, .S, .V)?.kind == .attraction)
        #expect(rel(0, .V, .C)?.kind == .conflict)
        #expect(rel(0, .V, .C)?.label == "C: inget V i regeringen")
        #expect(rel(0, .SD, .L)?.kind == .conflict)
        #expect(keyRelations(after: 0).allSatisfy { !$0.isNew })
    }

    @Test("Rubrikerna ändrar linjerna och det nya märks")
    func rubriker() {
        #expect(rel(1, .SD, .L) == nil)
        #expect(rel(2, .C, .S)?.kind == .negotiating)
        #expect(rel(2, .C, .S)?.label != rel(2, .C, .M)?.label)
        #expect(rel(0, .S, .M)?.kind == .conflict)
        #expect(rel(3, .S, .V)?.kind == .conflict)
        #expect(rel(3, .S, .V)?.isNew == true)
        #expect(rel(4, .C, .S)?.kind == .attraction)
        #expect(rel(4, .C, .M)?.kind == .conflict)
        #expect(rel(4, .V, .C)?.isNew == false)
        #expect(rel(6, .V, .C)?.isNew == true)
    }

    @Test("Moln: samarbetsgrupper utan röd linje inuti, och varje samarbete ligger i ett moln")
    func moln() {
        for h in 0...timelineEnd {
            let lines = keyRelations(after: h)
            let groups = clusters(lines)
            let conflicts = Set(lines.filter { $0.kind == .conflict }.map(\.pair))
            for g in groups {
                for (i, a) in g.enumerated() { for b in g.dropFirst(i + 1) { #expect(!conflicts.contains(Pair(a, b)), "rubrik \(h)") } }
            }
            for l in lines where l.kind == .attraction {
                #expect(groups.contains { $0.contains(l.pair.a) && $0.contains(l.pair.b) }, "rubrik \(h): \(l.pair)")
            }
        }
        let h0 = clusters(keyRelations(after: 0)).map(Set.init)
        #expect(h0.contains([.M, .KD, .L]) && h0.contains([.M, .SD]) && h0.contains([.V, .S, .MP]))
    }

    @Test("Grupperingarna syns: varje parti står närmare sitt eget blocks mitt än något annat blocks")
    func blockSyns() {
        var l = GraphLayout()
        for h in 0...timelineEnd {
            if h > 0 { l.nudge() }
            let lines = keyRelations(after: h)
            for _ in 0..<900 { l.step(lines) }
            let blocks = clusters(lines)
            let centers = blocks.map { b -> Point in
                Point(x: b.map { l.positions[$0]!.x }.reduce(0, +) / Double(b.count),
                      y: b.map { l.positions[$0]!.y }.reduce(0, +) / Double(b.count))
            }
            for (i, b) in blocks.enumerated() {
                // Partier som sitter i två moln (t.ex. M mellan L och SD) står med flit mittemellan.
                for p in b where blocks.filter({ $0.contains(p) }).count == 1 {
                    let own = l.positions[p]!.distance(to: centers[i])
                    for (j, c) in centers.enumerated() where j != i {
                        #expect(own < l.positions[p]!.distance(to: c), "rubrik \(h): \(p.rawValue)")
                    }
                }
            }
        }
    }
}

@Suite("Talmannens breda nätverk")
struct WideGraphTests {
    typealias M = WideGraphMetrics

    /// Grafen så som appen kör den: samma layout byggs vidare rubrik för rubrik, med en knuff vid varje ny rubrik.
    func replay(_ check: (Int, GraphLayout) -> Void) {
        var layout = GraphLayout()
        for h in 0...timelineEnd {
            if h > 0 { layout.nudge() }
            let lines = keyRelations(after: h)
            for _ in 0..<900 { layout.step(lines) }
            check(h, layout)
        }
    }

    @Test("Partierna överlappar aldrig, med marginal")
    func isar() {
        replay { h, l in
            for (i, a) in P.allCases.enumerated() {
                for b in P.allCases.dropFirst(i + 1) {
                    let need = M.nodeRadius(a) + M.nodeRadius(b) + M.margin
                    #expect(l.distance(a, b) >= need, "rubrik \(h): \(a.rawValue)–\(b.rawValue)")
                }
            }
        }
    }

    @Test("Emojierna krockar varken med partierna eller med varandra")
    func emojier() {
        replay { h, l in
            let lines = keyRelations(after: h)
            let spots = emojiPositions(l, lines)
            #expect(spots.count == lines.count)
            for line in lines {
                let e = spots[line.pair]!
                for p in P.allCases {
                    let need = M.nodeRadius(p) + M.emojiRadius + M.margin
                    #expect(e.distance(to: l.positions[p]!) >= need, "rubrik \(h): \(line.pair) mot \(p.rawValue)")
                }
            }
            let all = Array(spots.values)
            for i in all.indices {
                for j in all.indices where j > i {
                    #expect(all[i].distance(to: all[j]) >= 2 * M.emojiRadius + M.margin, "rubrik \(h)")
                }
            }
        }
    }

    @Test("Partierna och emojierna ryms inom ramen")
    func inomRamen() {
        replay { h, l in
            for p in P.allCases {
                let pos = l.positions[p]!, r = M.nodeRadius(p)
                #expect(abs(pos.x) + r <= 1 && abs(pos.y) + r <= 1, "rubrik \(h): \(p.rawValue)")
            }
            for e in emojiPositions(l, keyRelations(after: h)).values {
                #expect(abs(e.x) + M.emojiRadius <= 1 && abs(e.y) + M.emojiRadius <= 1, "rubrik \(h)")
            }
        }
    }

    @Test("Emojin sitter vid sin linje")
    func paLinjen() {
        replay { h, l in
            for line in keyRelations(after: h) {
                let a = l.positions[line.pair.a]!, b = l.positions[line.pair.b]!
                let e = emojiPositions(l, keyRelations(after: h))[line.pair]!
                // Avstånd från emojin till linjen (vinkelrätt), högst 0,18 enligt placeringsregeln.
                let len = a.distance(to: b)
                let cross = abs((b.x - a.x) * (a.y - e.y) - (a.x - e.x) * (b.y - a.y)) / len
                #expect(cross <= 0.18 + 1e-9, "rubrik \(h): \(line.pair)")
            }
        }
    }

    @Test("En knuff flyttar noderna mer än ett vanligt steg, och de lägger sig igen")
    func knuff() {
        var still = GraphLayout()
        let lines = keyRelations(after: 3)
        for _ in 0..<900 { still.step(lines) }
        var nudged = still
        var plain = still
        nudged.nudge(); nudged.step(lines)
        plain.step(lines)
        #expect(P.allCases.contains { nudged.positions[$0]!.distance(to: plain.positions[$0]!) > 0.01 })
        // Krafterna bryr sig inte om rotation, så grafen kan lägga sig vriden – men den ska komma till vila.
        for _ in 0..<900 { nudged.step(lines) }
        let rested = nudged.positions
        nudged.step(lines)
        for p in P.allCases { #expect(nudged.positions[p]!.distance(to: rested[p]!) < 0.001) }
    }
}

@Suite("Nätverket med rykten")
struct RumorGraphTests {
    typealias M = WideGraphMetrics

    /// Spela talmannen längs en tråd och kontrollera nätverket efter varje rykte och varje vecka.
    func play(preferring prefix: String) {
        var g = SpeakerGame()
        var layout = GraphLayout()
        var last = g.relations
        for _ in 0..<40 where g.ending == nil {
            if g.phase == .choosing {
                let c = g.choices
                g.choose((c.first { $0.id.hasSuffix(prefix) } ?? c[0]).id)
            }
            g.proceed()
            if g.relations != last { layout.nudge(); last = g.relations }
            for _ in 0..<900 { layout.step(g.relations) }
            let spots = emojiPositions(layout, g.relations)
            for (pair, e) in spots {
                for p in P.allCases {
                    #expect(e.distance(to: layout.positions[p]!) >= M.nodeRadius(p) + M.emojiRadius + M.margin,
                            "\(prefix) vecka \(g.headlineIndex): \(pair) mot \(p.rawValue)")
                }
            }
            let all = Array(spots.values)
            for i in all.indices {
                for j in all.indices where j > i {
                    #expect(all[i].distance(to: all[j]) >= 2 * M.emojiRadius + M.margin, "\(prefix) vecka \(g.headlineIndex)")
                }
            }
        }
    }

    @Test("Vänstertråden") func vanster() { play(preferring: "andersson") }
    @Test("Högertråden") func hoger() { play(preferring: "kristersson") }
    @Test("Processtråden") func process() { play(preferring: "probe") }
}
