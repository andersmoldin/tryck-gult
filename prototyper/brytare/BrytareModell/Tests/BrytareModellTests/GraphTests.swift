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
    func settled(after h: Int) -> GraphLayout {
        var layout = GraphLayout(style: .wide)
        let r = keyRelations(after: h)
        for _ in 0..<1500 { layout.step(r) }
        return layout
    }

    func midpoint(_ l: GraphLayout, _ pair: Pair) -> Point {
        let a = l.positions[pair.a]!, b = l.positions[pair.b]!
        return Point(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    func dist(_ a: Point, _ b: Point) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }

    @Test("Partierna står långt isär efter varje rubrik")
    func isar() {
        for h in 0...timelineEnd {
            let l = settled(after: h)
            for (i, a) in P.allCases.enumerated() {
                for b in P.allCases.dropFirst(i + 1) {
                    #expect(l.distance(a, b) >= 0.5, "rubrik \(h): \(a.rawValue)–\(b.rawValue) \(l.distance(a, b))")
                }
            }
        }
    }

    @Test("Emojin mitt på en linje krockar varken med partierna eller med andra emojier")
    func emojier() {
        for h in 0...timelineEnd {
            let l = settled(after: h)
            let lines = keyRelations(after: h)
            let mids = lines.map { midpoint(l, $0.pair) }
            for (m, line) in zip(mids, lines) {
                for p in P.allCases where p != line.pair.a && p != line.pair.b {
                    #expect(dist(m, l.positions[p]!) >= 0.26, "rubrik \(h): \(line.pair) mot \(p.rawValue)")
                }
            }
            for i in mids.indices {
                for j in mids.indices where j > i {
                    #expect(dist(mids[i], mids[j]) >= 0.16, "rubrik \(h): \(lines[i].pair) mot \(lines[j].pair)")
                }
            }
        }
    }

    @Test("En knuff flyttar noderna, och de lägger sig igen")
    func knuff() {
        var l = settled(after: 3)
        let before = l.positions
        l.nudge()
        l.step(keyRelations(after: 3))
        #expect(P.allCases.contains { dist(l.positions[$0]!, before[$0]!) > 0.005 })
    }
}
