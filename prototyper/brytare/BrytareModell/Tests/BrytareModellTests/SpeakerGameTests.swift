import Testing
@testable import BrytareModell

@Suite("Talmannen")
struct SpeakerGameTests {
    @Test("Valnatten: tre val med kort rubrik och en kort rad, följderna hemliga")
    func start() {
        let g = SpeakerGame()
        #expect(g.headlineIndex == 0)
        #expect(g.choices.map(\.id) == ["probe", "vote.andersson", "vote.kristersson"])
        #expect(g.choices.map(\.title) == ["Kalla alla partiledare till samtal",
                                           "Låt kammaren rösta om Andersson",
                                           "Låt kammaren rösta om Kristersson"])
        #expect(g.phase == .choosing)
    }

    @Test("Valet förgrenar handlingen: samma rubrik, olika situationer")
    func forgrening() {
        var left = SpeakerGame(); left.choose("vote.andersson"); left.proceed(); left.proceed()
        var right = SpeakerGame(); right.choose("vote.kristersson"); right.proceed(); right.proceed()
        #expect(left.headlineIndex == 1 && right.headlineIndex == 1)
        #expect(left.thread == .left && right.thread == .right)
        #expect(left.question != right.question)
        #expect(left.choices.map(\.id) != right.choices.map(\.id))
    }

    @Test("Ett rykte kommer mellan dragen och ändrar relationerna utan att spelaren valt det")
    func rykte() {
        var g = SpeakerGame()
        g.choose("vote.andersson")
        #expect(g.phase == .outcome)
        g.proceed()
        #expect(g.phase == .rumor)
        #expect(g.rumor?.text == "C och S har setts äta lunch.")
        let cs = g.relations.first { $0.pair == Pair(.C, .S) }
        #expect(cs?.kind == .negotiating)
        #expect(cs?.label == "Lunch på stan")
        #expect(cs?.isNew == true)
        g.proceed()
        #expect(g.phase == .choosing)
    }

    @Test("Verkliga rubriker vinner över rykten")
    func rubrikVinner() {
        var g = SpeakerGame()
        g.choose("vote.andersson"); g.proceed(); g.proceed()     // rykte: C–S lunch
        for _ in 0..<3 {
            g.choose(g.choices.first { $0.id.hasPrefix("vote") }!.id)
            g.proceed()
            if g.phase == .rumor { g.proceed() }
        }
        #expect(g.headlineIndex == 4)
        #expect(g.relations.first { $0.pair == Pair(.C, .S) }?.label == "C valde S:s totalpaket")
    }

    @Test("Sonderingen avslöjar stödet efteråt och det står i situationen")
    func sondering() {
        var g = SpeakerGame()
        g.choose("probe")
        #expect(g.effect == Effect(title: "STÖDET AVSLÖJAT", tone: .neutral,
                                   chips: ["Tålamod −1", "Samtalen fortsätter +1", "Andersson 151", "Kristersson 173"]))
        g.proceed()
        if g.phase == .rumor { g.proceed() }
        #expect(g.question.hasSuffix("Det du vet: Andersson (S) 151 (sonderingen, 6 nov). Kristersson (M) 173 (sonderingen, 6 nov)."))
    }

    @Test("En fallen omröstning ger en tydlig dålig effekt och förklaring")
    func faller() {
        var g = SpeakerGame()
        g.choose("vote.andersson")
        #expect(g.attemptsLeft == 3)
        #expect(g.effect == Effect(title: "FALLER", tone: .bad, chips: ["Försök −1", "151 stöd", "198 nej"]))
        #expect(g.outcome == "Omröstningen faller: 151 stöd, 198 nej. Andersson (S) saknade 24 mandat. C röstade nej – C vill inte ha V i regeringen.")
    }

    @Test("När tålamodet är slut finns bara omröstningar kvar")
    func talamod() {
        var g = SpeakerGame()
        while g.patience > 0 && g.ending == nil {
            guard let stall = g.choices.first(where: { !$0.id.hasPrefix("vote") && $0.id != "deadline" }) else { break }
            g.choose(stall.id); g.proceed(); if g.phase == .rumor { g.proceed() }
        }
        #expect(g.patience == 0)
        #expect(g.choices.allSatisfy { $0.id.hasPrefix("vote") })
        #expect(g.question.hasPrefix("Tålamodet är slut."))
    }

    @Test("Varje situation har 2–3 val och korta texter som inte avslöjar något")
    func manus() {
        for step in speakerScript.allSteps {
            #expect((2...3).contains(step.extras.count + step.votes.count), "\(step.situation)")
            for card in step.cards {
                #expect(card.title.count <= 45, "\(card.title)")
                #expect(card.quip.count <= 60, "\(card.quip)")
                for n in ["146", "151", "121", "111", "173", "majoritet", "nej", "räcker inte"] {
                    #expect(!card.quip.contains(n), "\(card.quip)")
                }
            }
        }
    }

    @Test("Reta alla lika mycket: varje parti förekommer i kvickheter eller rykten")
    func retaAlla() {
        let text = (speakerScript.allSteps.flatMap { $0.cards.map(\.quip) } + rumorTable.map(\.text)).joined(separator: " ")
        for p in P.allCases {
            #expect(text.contains(p.rawValue + " ") || text.contains(p.rawValue + ".") || text.contains(p.rawValue + ",") || text.contains(p.rawValue + ":"), "\(p.rawValue)")
        }
    }

    @Test("Ingen omröstning går igenom och spelet tar alltid slut, hur man än väljer")
    func tarSlut() {
        for seed in 0..<300 {
            var g = SpeakerGame()
            var steps = 0
            while g.ending == nil && steps < 200 {
                let c = g.choices
                if !c.isEmpty {
                    g.choose(c[(seed * 7 + steps) % c.count].id)
                    #expect(g.effect?.tone != .good, "seed \(seed)")
                }
                g.proceed()
                steps += 1
            }
            #expect(g.ending?.isExtraval == true, "seed \(seed)")
        }
    }

    @Test("Slutet säger vilken väg du tog, och brasklappen gäller ryktena")
    func slut() {
        var g = SpeakerGame()
        for _ in 0..<4 { g.choose("vote.kristersson"); g.proceed(); if g.phase == .rumor { g.proceed() } }
        #expect(g.ending?.text.contains("Du lutade dig åt Kristersson.") == true)
        #expect(g.ending?.footnote == "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt. Ryktena hittade vi på.")
    }
}
