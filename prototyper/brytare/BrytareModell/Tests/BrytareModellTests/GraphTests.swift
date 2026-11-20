import Testing
@testable import BrytareModell

@Suite("Grafen")
struct GraphTests {
    @Test("På valnatten drar blocken ihop sig och krockar med varandra")
    func valnatten() {
        let r = relations(after: 0)
        #expect(r[Pair(.S, .V)] == .attraction)
        #expect(r[Pair(.M, .SD)] == .attraction)
        #expect(r[Pair(.S, .M)] == .conflict)
        #expect(r[Pair(.SD, .C)] == .conflict)
        #expect(r[Pair(.C, .S)] == nil)
    }

    @Test("Rubrikerna ändrar linjerna: S–V blir konflikt, C dras mot S")
    func rubriker() {
        #expect(relations(after: 1)[Pair(.SD, .C)] == nil)
        #expect(relations(after: 3)[Pair(.S, .V)] == .conflict)
        #expect(relations(after: 4)[Pair(.C, .S)] == .attraction)
        #expect(relations(after: 4)[Pair(.C, .M)] == .conflict)
    }

    func settled(after h: Int, steps: Int = 900) -> GraphLayout {
        var layout = GraphLayout()
        let r = relations(after: h)
        for _ in 0..<steps { layout.step(r) }
        return layout
    }

    @Test("När grafen har lagt sig står allierade närmare varandra än partier i konflikt")
    func avstand() {
        let layout = settled(after: 0)
        let r = relations(after: 0)
        func mean(_ kind: Relation) -> Double {
            let d = r.filter { $0.value == kind }.map { layout.distance($0.key.a, $0.key.b) }
            return d.reduce(0, +) / Double(d.count)
        }
        #expect(mean(.attraction) < mean(.conflict) * 0.6)
    }

    @Test("Efter rubrik 4 står C närmare S än M")
    func cFlyttar() {
        let layout = settled(after: 4)
        #expect(layout.distance(.C, .S) < layout.distance(.C, .M))
    }

    @Test("Grafen stannar inom ramen och lugnar ner sig")
    func stabil() {
        var layout = settled(after: 6)
        let before = layout.positions
        layout.step(relations(after: 6))
        for p in P.allCases {
            let pos = layout.positions[p]!
            #expect(abs(pos.x) <= 1 && abs(pos.y) <= 1)
            #expect(abs(pos.x - before[p]!.x) < 0.001 && abs(pos.y - before[p]!.y) < 0.001)
        }
    }
}
