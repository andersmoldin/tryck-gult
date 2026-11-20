// Perspektiv 2: du är talmannen. Varje vecka är en situation med 2–3 val.
// Att ta reda på stödet kostar riksdagens tålamod; att rösta blint kostar försök.
// Fyra fallna omröstningar ger extraval. Poängen är hur många gånger samtalen fortsatte.

public enum SpeakerAction: Equatable, Sendable {
    /// Sondera med alla partier: du får veta stödet för båda kandidaterna.
    case probe
    /// Förhandlingsuppdrag: du får veta stödet för en kandidat.
    case mission(Candidate)
    /// Ett möte som inte ger något nytt.
    case meeting
    /// Egen deadline: tålamod +1, men nästa vecka måste riksdagen rösta.
    case deadline
    case vote(Candidate)

    public var id: String {
        switch self {
        case .probe: return "probe"
        case .mission(let c): return "mission.\(c.rawValue)"
        case .meeting: return "meeting"
        case .deadline: return "deadline"
        case .vote(let c): return "vote.\(c.rawValue)"
        }
    }

    var isVote: Bool { if case .vote = self { return true } else { return false } }
}

public struct SpeakerCard: Sendable {
    public let action: SpeakerAction
    public let title: String
    public let quip: String
}

/// En vecka i talmannens kalender: situationen och valen.
public struct SpeakerStep: Sendable {
    public let situation: String
    /// Val som inte är omröstningar, i den ordning de visas.
    let extras: [SpeakerCard]
    /// Vilka kandidater som går att föreslå när spelaren inte är tvingad att rösta.
    let votes: [Candidate]
    /// En kvickhet per kandidat; används också när omröstning är tvingande.
    let voteQuips: [Candidate: String]

    func voteCard(_ c: Candidate) -> SpeakerCard {
        SpeakerCard(action: .vote(c), title: "Låt \(c.surname) försöka", quip: voteQuips[c] ?? "")
    }

    /// Alla kort i steget (för texter och tester).
    public var cards: [SpeakerCard] { extras + Candidate.allCases.map(voteCard) }
}

/// Talmannens manus, ett steg per rubrik (index = antal rubriker som slagit ner).
/// Skrivregel: reta alla lika mycket.
public let speakerScript: [SpeakerStep] = [
    SpeakerStep(
        situation: "Valnatten är slut. Ingen sida har 175. Enligt tradition får största partiet försöka först. Enligt erfarenhet spelar det ingen roll.",
        extras: [SpeakerCard(action: .probe, title: "Sonderingsrunda",
                             quip: "Åtta partiledare, åtta kaffekoppar, ett besked: ”vi återkommer”.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "Störst parti först. S har 99 mandat och en tradition att luta sig mot.",
                    .kristersson: "Regeringen sitter kvar under tiden. Det är så det fungerar."]),
    SpeakerStep(
        situation: "SD vill inte längre ha ministrar, bara inflytande. Det låter som en nedgradering. Det är det inte.",
        extras: [SpeakerCard(action: .mission(.kristersson), title: "Förhandlingsuppdrag till Kristersson",
                             quip: "M får en vecka att räkna. M har räknat förut.")],
        votes: [.kristersson, .andersson],
        voteQuips: [.kristersson: "SD trycker gult. Gult är den nya färgen för ”ja, men”.",
                    .andersson: "V väntar fortfarande på sina ministerposter. V väntar gärna."]),
    SpeakerStep(
        situation: "C vill ha ett totalpaket från båda sidor och har satt en deadline för dem. Talmannen har ingen deadline. Än.",
        extras: [SpeakerCard(action: .deadline, title: "Sätt en egen deadline",
                             quip: "Om C får ha en deadline får du också ha en.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "Rödgröna plus C. Det är en majoritet om C vill. C vill ha ett paket först.",
                    .kristersson: "M, KD och L har ett paket. C har inte öppnat det."]),
    SpeakerStep(
        situation: "S vill regera utan V. V säger att kravet ”inte går att påverka”. Båda menar det. Det är det som är problemet.",
        extras: [SpeakerCard(action: .mission(.andersson), title: "Förhandlingsuppdrag till Andersson",
                             quip: "S får en vecka att övertyga V om att utanför är ett bra ställe att vara.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "V röstar nej av princip. S kallar det ansvarslöst. V kallar det samma sak.",
                    .kristersson: "L och SD har hittat ett sätt att tycka olika tillsammans."]),
    SpeakerStep(
        situation: "C har valt S:s totalpaket. Vågmästaren har vägt. Vågen står still.",
        extras: [SpeakerCard(action: .meeting, title: "Kalla S och V till ditt kontor",
                             quip: "Du bjuder på kaffe. Ingen dricker.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "S + MP + C. Det är en majoritet om man räknar generöst.",
                    .kristersson: "KD har 22 mandat och ett tydligt krav: Kristersson. Det räcker inte heller."]),
    SpeakerStep(
        situation: "S och V har mötts i två timmar. Beskedet var detsamma som tidigare, vilket i sig är ett slags besked.",
        extras: [SpeakerCard(action: .probe, title: "Sonderingsrunda igen",
                             quip: "Samma kaffe, samma frågor. MP svarar som S. Det är det enda som är enkelt.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "S, MP och C har 146. De har haft 146 sedan C bestämde sig.",
                    .kristersson: "SD trycker gult igen. Det börjar likna en vana."]),
    SpeakerStep(
        situation: "C säger nej till V i regeringen, även om alternativet är extraval. Alternativet hörde det.",
        extras: [],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "V röstar nej. C röstar ja. S röstar på sig själv. Det räcker inte.",
                    .kristersson: "M, KD, L och SD har fortfarande 173. De har haft 173 länge nu."]),
]

public struct SpeakerGame: PerspectiveGame {
    public static let title = "Talmannen"
    public static let hidesCosts = true
    public static let role = "Du är talmannen. Välj vem som får försöka – och när. Undvik extraval."
    public static let tips = [
        "Du föreslår statsminister och riksdagen röstar. Det brukar gå bra. I år gick det inte.",
        "Riksdagens tålamod är hur länge riksdagen står ut med att du inte röstar. Varje vecka du sonderar, ger uppdrag eller håller möte kostar ett streck. När strecken är slut finns bara omröstningar kvar.",
        "Stödet är okänt tills du sonderat. Att ta reda på kostar tålamod. Att gissa kostar försök. Fyra fallna omröstningar ger extraval.",
        disclaimer,
    ]

    private static let maxPatience = 3
    private static let disclaimer = "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt."

    /// Vad spelaren vet om en kandidats stöd, och varifrån.
    private struct Knowledge {
        /// Rubrikindex när stödet mättes.
        let at: Int
        let support: Int
        /// "sonderingen", "uppdraget" eller "omröstningen".
        let source: String
    }

    private var turns = Turns()
    public private(set) var attemptsLeft = 4
    public private(set) var patience = maxPatience
    /// Antal drag som inte var en omröstning. Spelets poäng.
    public private(set) var talksContinue = 0
    /// Spelarens egen deadline har gått ut: nästa val måste vara en omröstning.
    private var mustVote = false
    private var known: [Candidate: Knowledge] = [:]
    public private(set) var effect: Effect?
    /// Det försök som kom närmast 175, för slutskärmen.
    private var closest: (candidate: Candidate, support: Int)?

    public init() {}

    public var headlineIndex: Int { turns.headlineIndex }
    public var outcome: String? { turns.outcome }
    public var ending: Ending? { turns.ending }

    private var step: SpeakerStep { speakerScript[min(headlineIndex, speakerScript.count - 1)] }
    private var forced: Bool { patience == 0 || mustVote || turns.isLastHeadline }

    public var question: String {
        var text = step.situation
        if mustVote { text = "Din deadline har gått ut. Nu måste riksdagen rösta. " + text }
        else if patience == 0 { text = "Tålamodet är slut. Riksdagen kräver omröstning – nu. " + text }
        let facts = Candidate.allCases.compactMap { c in
            known[c].map { "\(c.name) \($0.support) (\($0.source), \(BrytareModell.headline(after: $0.at).date))." }
        }
        if !facts.isEmpty { text += "\n\nDet du vet: " + facts.joined(separator: " ") }
        return text
    }

    public var meters: [Meter] {
        [Meter(name: "Försök kvar", value: "\(attemptsLeft) av 4"),
         Meter(name: "Riksdagens tålamod",
               value: String(repeating: "■", count: patience) + String(repeating: "□", count: Self.maxPatience - patience),
               caption: "Hur länge riksdagen står ut med att du inte röstar."),
         Meter(name: "Samtalen fortsätter", value: "\(talksContinue)")]
    }

    private var cards: [SpeakerCard] {
        guard turns.canChoose else { return [] }
        if forced { return Candidate.allCases.map(step.voteCard) }
        return step.extras + step.votes.map(step.voteCard)
    }

    public var choices: [Choice] {
        cards.map { Choice(id: $0.action.id, title: $0.title, cost: cost(of: $0.action), quip: $0.quip) }
    }

    public mutating func choose(_ id: String) {
        guard let card = cards.first(where: { $0.action.id == id }) else { return }
        switch card.action {
        case .probe:
            stall()
            learn(Candidate.allCases, from: "sonderingen")
            effect = Effect(title: "STÖDET AVSLÖJAT", tone: .neutral, chips: stallChips + knownChips(Candidate.allCases))
            turns.resolve("Sonderingen tog en vecka. Under tiden kom en ny rubrik. Sedan visste du: \(knownText(Candidate.allCases)).")
        case .mission(let c):
            stall()
            learn([c], from: "uppdraget")
            effect = Effect(title: "UPPDRAGET KLART", tone: .neutral, chips: stallChips + knownChips([c]))
            turns.resolve("Förhandlingsuppdraget tog en vecka. Under tiden kom en ny rubrik. Sedan visste du: \(knownText([c])).")
        case .meeting:
            stall()
            effect = Effect(title: "INGET NYTT", tone: .neutral, chips: stallChips)
            turns.resolve("Mötet tog två timmar och en vecka. Beskedet var detsamma som tidigare.")
        case .deadline:
            talksContinue += 1
            let gained = patience < Self.maxPatience
            patience = min(Self.maxPatience, patience + 1)
            effect = Effect(title: "DEADLINE SATT", tone: .neutral,
                            chips: (gained ? ["Tålamod +1"] : []) + ["Samtalen fortsätter +1", "Nästa vecka: omröstning"])
            mustVote = true
            turns.resolve("Du sätter en deadline till nästa vecka. Riksdagen gillar deadlines. Tålamodet stiger.")
        case .vote(let c):
            vote(c)
        }
    }

    public mutating func proceed() {
        effect = nil
        turns.proceed()
    }

    private let stallChips = ["Tålamod −1", "Samtalen fortsätter +1"]

    private func knownChips(_ candidates: [Candidate]) -> [String] {
        candidates.compactMap { c in known[c].map { "\(c.surname) \($0.support)" } }
    }

    private mutating func stall() {
        talksContinue += 1
        patience -= 1
    }

    /// Stödet mäts som det är efter veckan, alltså efter nästa rubrik.
    private mutating func learn(_ candidates: [Candidate], from source: String) {
        let at = min(headlineIndex + 1, timelineEnd)
        for c in candidates { known[c] = Knowledge(at: at, support: support(c, at: at), source: source) }
    }

    private func knownText(_ candidates: [Candidate]) -> String {
        candidates.compactMap { c in known[c].map { "\(c.name) \($0.support)" } }.joined(separator: ", ")
    }

    private mutating func vote(_ c: Candidate) {
        mustVote = false
        let r = tally(historicVotes(for: c, after: headlineIndex))
        known[c] = Knowledge(at: headlineIndex, support: r.supportSeats, source: "omröstningen")
        if r.supportSeats > (closest?.support ?? -1) { closest = (c, r.supportSeats) }
        let numbers = ["\(r.supportSeats) stöd", "\(r.nej) nej"]
        if r.passed {
            effect = Effect(title: "GÅR IGENOM", tone: .good, chips: numbers)
            turns.resolve(voteText(r), ending: Ending(title: "REGERING", text: "\(c.name) blev statsminister.", isExtraval: false))
            return
        }
        attemptsLeft -= 1
        effect = Effect(title: "FALLER", tone: .bad, chips: ["Försök −1"] + numbers)
        turns.resolve(voteText(r) + " \(c.name) saknade \(majority - r.supportSeats) mandat. " + why(c),
                      ending: attemptsLeft == 0 ? extraval() : nil)
    }

    private func support(_ c: Candidate, at h: Int) -> Int {
        tally(historicVotes(for: c, after: h)).supportSeats
    }

    private func cost(of action: SpeakerAction) -> String {
        let after = "(\(patience - 1) kvar)"
        let talk = " Samtalen fortsätter +1."
        switch action {
        case .probe: return "Tålamod −1 \(after). Du får veta exakt stöd för båda." + talk
        case .mission(let c): return "Tålamod −1 \(after). Du får veta exakt stöd för \(c.surname)." + talk
        case .meeting: return "Tålamod −1 \(after). Inget nytt besked." + talk
        case .deadline:
            let gain = patience < Self.maxPatience ? "Tålamod +1 (\(patience + 1) kvar)." : "Tålamodet är redan fullt."
            return gain + " Men nästa vecka måste du hålla omröstning." + talk
        case .vote(let c):
            let fails = "faller den går ett av fyra försök."
            guard let k = known[c] else { return "Omröstning. Stöd okänt – \(fails)" }
            if k.at == headlineIndex {
                let passes = k.support >= majority
                return "Omröstning. \(k.support) av \(majority) enligt sonderingen – " + (passes ? "går igenom." : fails)
            }
            return "Omröstning. \(k.support) vid \(k.source) \(BrytareModell.headline(after: k.at).date) – kan ha ändrats. Faller den går ett av fyra försök."
        }
    }

    /// Vem som fällde kandidaten, i klartext (följer `historicVotes`).
    private func why(_ c: Candidate) -> String {
        let h = headlineIndex
        switch c {
        case .andersson:
            if h < 3 { return "C röstade nej – C vill inte ha V i regeringen." }
            if h == 3 { return "V och C röstade nej – V vill ha ministrar och C väntar på ett totalpaket." }
            return "V röstade nej – V kräver ministerposter."
        case .kristersson:
            if h == 0 { return "SD och C röstade nej – SD vill ha ministrar och C vill inte ha SD-inflytande." }
            if h < 4 { return "C röstade nej – C väntar på ett totalpaket." }
            return "C röstade nej – C valde S:s totalpaket."
        }
    }

    private func extraval() -> Ending {
        var text = "Ingen fick ihop 175."
        if let c = closest {
            text += " Närmast kom \(c.candidate.name) med \(c.support) – \(majority - c.support) mandat för lite."
        }
        let verdict: String
        switch talksContinue {
        case 0...1: verdict = "handlingskraftig. Det hjälpte inte."
        case 2...3: verdict = "processorienterad."
        default: verdict = "mycket lyssnande."
        }
        text += " Du sa ”samtalen fortsätter” \(talksContinue) \(talksContinue == 1 ? "gång" : "gånger"). Omdöme: \(verdict)"
        return Ending(title: "EXTRAVAL", text: text, isExtraval: true, footnote: Self.disclaimer)
    }
}
