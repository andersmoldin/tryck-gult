import Testing
@testable import BrytareModell

@Suite("Vågmästarpartiet")
struct KingmakerGameTests {
    @Test("På valnatten går båda kandidaterna att släppa fram – men båda bryter ett löfte")
    func start() {
        let g = KingmakerGame()
        #expect(g.choices.map(\.id) == ["andersson", "kristersson", "demand"])
        #expect(g.choices[0].cost == "176 av 175 – går igenom, men V kommer in i regeringen: löfte brutet")
        #expect(g.choices[1].cost == "179 av 175 – går igenom, men SD får ministrar: löfte brutet")
        #expect(g.choices[2].cost == "Ingen omröstning. Krav +1. Nästa rubrik slår ner.")
        #expect(g.meters.map(\.value).prefix(2) == ["3 av 3", "0"])
    }

    @Test("Att släppa fram Kristersson när SD trycker gult undviker extraval men kostar ett löfte")
    func vinnaMedBrutetLofte() {
        var g = KingmakerGame()
        g.choose("demand"); g.proceed()                // rubrik 1, krav 1
        #expect(g.choices[1].cost == "198 av 175 – går igenom, men SD släpper fram regeringen: löfte brutet")
        g.choose("kristersson")
        #expect(g.promisesKept == 1)
        g.proceed()
        #expect(g.ending?.isExtraval == false)
        #expect(g.ending?.title == "REGERING BILDAD")
        #expect(g.ending?.text == "Kristersson (M) blev statsminister. Du fick igenom 1 krav – men bröt löftet om inget SD-inflytande. Löften kvar: 1 av 3.")
    }

    @Test("När V hålls utanför faller Andersson utan att något löfte bryts")
    func anderssonUtanV() {
        var g = KingmakerGame()
        for _ in 0..<3 { g.choose("demand"); g.proceed() }   // rubrik 3
        #expect(g.choices[0].cost == "146 av 175 – faller, kostar ett försök")
        g.choose("andersson")
        #expect(g.promisesKept == 3)
        #expect(g.attemptsLeft == 3)
        #expect(g.outcome == "Omröstningen faller: 146 stöd, 203 nej. V röstade nej – V kräver ministerposter.")
    }

    @Test("Håller du alla löften blir det extraval")
    func hallaLoftena() {
        var g = KingmakerGame()
        for _ in 0..<6 { g.choose("demand"); g.proceed() }
        #expect(g.demandsWon == 6)
        #expect(g.choices.map(\.id) == ["andersson", "kristersson"])
        for _ in 0..<4 {
            if g.ending != nil { break }
            g.choose("andersson"); g.proceed()
        }
        #expect(g.ending?.isExtraval == true)
        #expect(g.ending?.text == "Du höll alla löften och fick igenom 6 krav – men ingen fick ihop 175.")
    }
}
