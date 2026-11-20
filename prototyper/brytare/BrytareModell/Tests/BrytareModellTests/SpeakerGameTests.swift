import Testing
@testable import BrytareModell

@Suite("Talmannen")
struct SpeakerGameTests {
    @Test("Valnatten: sondera eller rösta blint, och varje kort har en kvickhet och en följd")
    func start() {
        let g = SpeakerGame()
        #expect(g.choices.map(\.id) == ["probe", "vote.andersson", "vote.kristersson"])
        #expect(g.choices[0].cost == "Tålamod −1 (2 kvar). Du får veta exakt stöd för båda.")
        #expect(g.choices[1].cost == "Omröstning. Stöd okänt – faller den går ett av fyra försök.")
        #expect(g.choices.allSatisfy { ($0.quip ?? "").isEmpty == false })
        let patience = g.meters.first { $0.name == "Riksdagens tålamod" }
        #expect(patience?.value == "■■■")
        #expect(patience?.caption == "Hur länge riksdagen står ut med att du inte röstar.")
    }

    @Test("Sonderingen tar en vecka och visar sedan exakt stöd")
    func sondering() {
        var g = SpeakerGame()
        g.choose("probe")
        #expect(g.patience == 2)
        #expect(g.talksContinue == 1)
        #expect(g.outcome == "Sonderingen tog en vecka. Under tiden kom en ny rubrik. Sedan visste du: Andersson (S) 151, Kristersson (M) 173.")
        g.proceed()
        #expect(g.headlineIndex == 1)
        let k = g.choices.first { $0.id == "vote.kristersson" }
        #expect(k?.cost == "Omröstning. 173 av 175 enligt sonderingen – faller den går ett av fyra försök.")
    }

    @Test("Gammal sondering märks som osäker när en ny rubrik har kommit")
    func gammalKunskap() {
        var g = SpeakerGame()
        g.choose("probe"); g.proceed()                       // vet båda vid rubrik 1
        g.choose("mission.kristersson"); g.proceed()         // rubrik 2, bara Kristersson uppdaterad
        let a = g.choices.first { $0.id == "vote.andersson" }
        #expect(a?.cost == "Omröstning. 151 vid sonderingen 6 nov – kan ha ändrats. Faller den går ett av fyra försök.")
    }

    @Test("När tålamodet är slut finns bara omröstningar kvar")
    func talamodSlut() {
        var g = SpeakerGame()
        g.choose("probe"); g.proceed()
        g.choose("mission.kristersson"); g.proceed()
        g.choose("probe"); g.proceed()
        #expect(g.patience == 0)
        #expect(g.choices.map(\.id) == ["vote.andersson", "vote.kristersson"])
        #expect(g.question.hasPrefix("Tålamodet är slut. Riksdagen kräver omröstning – nu."))
    }

    @Test("En egen deadline ger tålamod men tvingar fram en omröstning nästa vecka")
    func deadline() {
        var g = SpeakerGame()
        g.choose("probe"); g.proceed()                       // tålamod 2
        g.choose("mission.kristersson"); g.proceed()         // tålamod 1, rubrik 2
        #expect(g.choices.map(\.id).contains("deadline"))
        g.choose("deadline")
        #expect(g.patience == 2)
        g.proceed()
        #expect(g.choices.map(\.id) == ["vote.andersson", "vote.kristersson"])
        #expect(g.question.hasPrefix("Din deadline har gått ut."))
    }

    @Test("En fallen omröstning förklarar vem som fällde kandidaten")
    func fall() {
        var g = SpeakerGame()
        g.choose("vote.andersson")
        #expect(g.attemptsLeft == 3)
        #expect(g.outcome == "Omröstningen faller: 151 stöd, 198 nej. Andersson (S) saknade 24 mandat. C röstade nej – C vill inte ha V i regeringen.")
    }

    @Test("Extraval: närmaste försöket, samtalen som fortsatte och en torr dom")
    func extraval() {
        var g = SpeakerGame()
        g.choose("probe"); g.proceed()
        g.choose("vote.kristersson"); g.proceed()
        g.choose("vote.andersson"); g.proceed()
        g.choose("vote.andersson"); g.proceed()
        g.choose("vote.kristersson"); g.proceed()
        #expect(g.ending?.isExtraval == true)
        #expect(g.ending?.text == "Ingen fick ihop 175. Närmast kom Kristersson (M) med 173 – 2 mandat för lite. Du sa ”samtalen fortsätter” 1 gång. Omdöme: handlingskraftig. Det hjälpte inte.")
    }

    @Test("Reta alla lika mycket: varje parti får en kvickhet")
    func retaAlla() {
        let quips = speakerScript.flatMap { $0.cards.map(\.quip) }.joined(separator: " ")
        for p in P.allCases {
            #expect(quips.contains(p.rawValue + " ") || quips.contains(p.rawValue + ".") || quips.contains(p.rawValue + ","), "\(p.rawValue) saknas")
        }
    }

    @Test("Spelet tar alltid slut, hur man än väljer")
    func tarSlut() {
        for seed in 0..<200 {
            var g = SpeakerGame()
            var steps = 0
            while g.ending == nil && steps < 100 {
                let c = g.choices
                if !c.isEmpty { g.choose(c[(seed + steps) % c.count].id) }
                g.proceed()
                steps += 1
            }
            #expect(g.ending != nil, "seed \(seed)")
        }
    }
}
