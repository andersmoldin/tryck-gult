import Testing
@testable import BrytareModell

@Suite("Talmannen")
struct SpeakerGameTests {
    @Test("Varje kandidat visar sitt stöd innan du väljer")
    func start() {
        let g = SpeakerGame()
        #expect(g.choices.map(\.id) == ["andersson", "kristersson", "wait"])
        #expect(g.choices[0].cost == "151 av 175 – faller, kostar ett försök")
        #expect(g.choices[1].cost == "111 av 175 – faller, kostar ett försök")
        #expect(g.choices[2].cost == "Tålamod −1 (3 kvar). Nästa rubrik slår ner.")
    }

    @Test("Att vänta kostar tålamod, och utan tålamod måste du hålla omröstning")
    func talamod() {
        var g = SpeakerGame()
        for _ in 0..<3 { g.choose("wait"); g.proceed() }
        #expect(g.patience == 0)
        #expect(g.headlineIndex == 3)
        #expect(g.choices.map(\.id) == ["andersson", "kristersson"])
    }

    @Test("Kristersson kommer närmast när SD trycker gult")
    func narmast() {
        var g = SpeakerGame()
        g.choose("wait"); g.proceed()                 // rubrik 1
        g.choose("kristersson")
        #expect(g.attemptsLeft == 3)
        #expect(g.outcome == "Omröstningen faller: 173 stöd, 176 nej. Kristersson (M) saknade 2 mandat.")
        g.proceed()
        #expect(g.headlineIndex == 2)
    }

    @Test("Fyra fallna omröstningar ger extraval och visar närmaste försöket")
    func extraval() {
        var g = SpeakerGame()
        g.choose("andersson"); g.proceed()            // 151
        g.choose("kristersson"); g.proceed()          // 173 (rubrik 1)
        g.choose("andersson"); g.proceed()            // 151 (rubrik 2)
        g.choose("andersson")                         // 121 (rubrik 3)
        g.proceed()
        #expect(g.ending?.isExtraval == true)
        #expect(g.ending?.text == "Ingen fick ihop 175. Närmast kom Kristersson (M) med 173 – 2 mandat för lite.")
    }
}
