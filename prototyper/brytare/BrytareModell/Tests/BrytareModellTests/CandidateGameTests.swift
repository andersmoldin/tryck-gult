import Testing
@testable import BrytareModell

@Suite("Statsministerkandidaten")
struct CandidateGameTests {
    @Test("Tre val på valnatten, och varje val visar vad det kostar")
    func start() {
        let g = CandidateGame()
        #expect(g.headlineIndex == 0)
        #expect(g.choices.map(\.id) == ["promiseV", "promiseC", "wait"])
        #expect(g.choices[0].cost == "V röstar ja, C röstar nej → 151 av 175")
        #expect(g.choices[1].cost == "C röstar ja, V röstar nej → 146 av 175")
        #expect(g.meters.first == Meter(name: "Försök kvar", value: "4 av 4"))
        #expect(g.outcome == nil)
        #expect(g.ending == nil)
    }

    @Test("Ett löfte till V leder till omröstning som faller, och C:s nej förklaras")
    func lovaV() {
        var g = CandidateGame()
        g.choose("promiseV")
        #expect(g.attemptsLeft == 3)
        #expect(g.outcome == "Omröstningen faller: 151 stöd, 198 nej. C röstade nej – C vill inte ha V i regeringen.")
        #expect(g.choices.isEmpty)          // en sak i taget: läs utfallet först
        g.proceed()
        #expect(g.outcome == nil)
        #expect(g.headlineIndex == 1)
    }

    @Test("Att vänta kostar ingen omröstning men nästa rubrik slår ner")
    func vanta() {
        var g = CandidateGame()
        g.choose("wait")
        #expect(g.attemptsLeft == 4)
        g.proceed()
        #expect(g.headlineIndex == 1)
    }

    @Test("Vid sista rubriken går det inte att vänta längre")
    func sistaRubriken() {
        var g = CandidateGame()
        for _ in 0..<6 { g.choose("wait"); g.proceed() }
        #expect(g.headlineIndex == 6)
        #expect(g.choices.map(\.id) == ["promiseV", "promiseC"])
    }

    @Test("Fyra fallna omröstningar ger extraval som förklarar varför")
    func extraval() {
        var g = CandidateGame()
        for _ in 0..<3 { g.choose("promiseC"); g.proceed() }
        g.choose("promiseV")
        #expect(g.ending == nil)            // utfallet visas först
        g.proceed()
        #expect(g.ending?.isExtraval == true)
        #expect(g.ending?.text.contains("både V (30) och C (25)") == true)
        #expect(g.choices.isEmpty)
    }

    @Test("Ett okänt val eller ett val medan utfallet visas ignoreras")
    func ogiltigt() {
        var g = CandidateGame()
        g.choose("bluff")
        #expect(g.outcome == nil)
        g.choose("promiseV")
        g.choose("promiseV")
        #expect(g.attemptsLeft == 3)
    }
}
