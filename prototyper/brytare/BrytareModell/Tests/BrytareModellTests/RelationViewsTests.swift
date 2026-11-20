import Testing
@testable import BrytareModell

@Suite("Halvcirkeln och partivyn")
struct RelationViewsTests {
    @Test("Halvcirkeln har 349 säten och varje parti får sina mandat")
    func saten() {
        let seats = hemicycleSeats()
        #expect(seats.count == 349)
        for p in P.allCases {
            #expect(seats.filter { $0.party == p }.count == p.seats, "\(p.rawValue)")
        }
        #expect(seats.allSatisfy { abs($0.x) <= 1 && $0.y >= 0 && $0.y <= 1 })
    }

    @Test("Partierna sitter från vänster till höger: V, S, MP, C, L, KD, M, SD")
    func ordning() {
        let seats = hemicycleSeats()
        let angles = leftToRight.map { p -> Double in
            let mine = seats.filter { $0.party == p }
            return mine.map(\.angle).reduce(0, +) / Double(mine.count)
        }
        #expect(angles == angles.sorted(by: >))   // vinkeln går från π (vänster) mot 0 (höger)
    }

    @Test("Ett parti i klartext: C efter rubrik 4")
    func ettParti() {
        let c = partyRelations(.C, after: 4)
        #expect(c.attraction.map(\.party) == [.S])
        #expect(c.attraction.first?.label == "C valde S:s totalpaket")
        #expect(c.attraction.first?.isNew == true)
        #expect(Set(c.conflict.map(\.party)) == [.V, .SD, .M])
        #expect(c.negotiating.isEmpty)
        #expect(Set(c.none) == [.MP, .L, .KD])
        #expect(c.removed.isEmpty)
    }

    @Test("Ett parti i klartext visar det som rubriken tog bort")
    func borta() {
        let l = partyRelations(.L, after: 1)
        #expect(l.removed.map(\.party) == [.SD])
        #expect(l.conflict.isEmpty)
    }
}
