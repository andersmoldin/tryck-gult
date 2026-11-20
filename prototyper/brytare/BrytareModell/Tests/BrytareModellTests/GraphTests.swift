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
