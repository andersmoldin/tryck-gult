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

    @Test("Linjer som en rubrik tar bort går att visa")
    func borttagna() {
        #expect(removedRelations(after: 0).isEmpty)
        #expect(removedRelations(after: 1).map(\.pair) == [Pair(.SD, .L)])
        #expect(removedRelations(after: 2).isEmpty)
    }

    func settled(after h: Int, steps: Int = 900) -> GraphLayout {
        var layout = GraphLayout()
        let r = keyRelations(after: h)
        for _ in 0..<steps { layout.step(r) }
        return layout
    }

    @Test("När grafen har lagt sig står allierade närmare varandra än partier i konflikt")
    func avstand() {
        let layout = settled(after: 0)
        let r = keyRelations(after: 0)
        func mean(_ kind: RelationKind) -> Double {
            let d = r.filter { $0.kind == kind }.map { layout.distance($0.pair.a, $0.pair.b) }
            return d.reduce(0, +) / Double(d.count)
        }
        #expect(mean(.attraction) < mean(.conflict) * 0.6)
    }

    @Test("Efter rubrik 4 står C närmare S än M")
    func cFlyttar() {
        let layout = settled(after: 4)
        #expect(layout.distance(.C, .S) < layout.distance(.C, .M))
    }

    @Test("Grafen stannar inom ramen och står still när den lagt sig")
    func stabil() {
        var layout = settled(after: 6)
        let before = layout.positions
        layout.step(keyRelations(after: 6))
        for p in P.allCases {
            let pos = layout.positions[p]!
            #expect(abs(pos.x) <= 1 && abs(pos.y) <= 1)
            #expect(abs(pos.x - before[p]!.x) < 0.001 && abs(pos.y - before[p]!.y) < 0.001)
        }
    }
}

@Suite("Talmannens breda nätverk")
struct WideGraphTests {
    typealias M = WideGraphMetrics

    /// Grafen så som appen kör den: samma layout byggs vidare rubrik för rubrik, med en knuff vid varje ny rubrik.
    func replay(_ check: (Int, GraphLayout) -> Void) {
        var layout = GraphLayout(style: .wide)
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

    @Test("Emojin ligger på sin linje")
    func paLinjen() {
        replay { h, l in
            for line in keyRelations(after: h) {
                let a = l.positions[line.pair.a]!, b = l.positions[line.pair.b]!
                let e = emojiPositions(l, keyRelations(after: h))[line.pair]!
                let off = a.distance(to: e) + e.distance(to: b) - a.distance(to: b)
                #expect(off < 0.001, "rubrik \(h): \(line.pair)")
            }
        }
    }

    @Test("En knuff flyttar noderna mer än ett vanligt steg, och de lägger sig igen")
    func knuff() {
        var still = GraphLayout(style: .wide)
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
