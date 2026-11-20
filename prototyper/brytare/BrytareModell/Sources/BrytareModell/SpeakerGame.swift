// Talmannen: varje vecka är en situation med 2–3 val. Valen förgrenar handlingen (tråden),
// rykten i det fördolda ändrar relationerna mellan dragen, och de verkliga rubrikerna är ankaret.
// Rösterna följer historien (historicVotes): ingen får ihop 175. Fyra fall ger extraval.

/// Vart handlingen lutar, efter spelarens val.
public enum Thread: Sendable { case left, right, wide }

public enum SpeakerAction: Equatable, Sendable {
    /// Samtal med alla partiledare: du får veta stödet för båda kandidaterna.
    case probe
    /// En vecka för en kandidat att förhandla: du får veta hens stöd.
    case mission(Candidate)
    /// Två partier till möte hos talmannen. Inget nytt besked.
    case meeting(Pair)
    /// Egen deadline: tålamod +1, men nästa vecka måste kammaren rösta.
    case deadline
    case vote(Candidate)

    public var id: String {
        switch self {
        case .probe: return "probe"
        case .mission(let c): return "mission.\(c.rawValue)"
        case .meeting(let p): return "meeting.\(p.a.rawValue).\(p.b.rawValue)"
        case .deadline: return "deadline"
        case .vote(let c): return "vote.\(c.rawValue)"
        }
    }

    /// Vart valet för handlingen.
    var thread: Thread {
        switch self {
        case .probe, .deadline: return .wide
        case .mission(let c), .vote(let c): return c == .andersson ? .left : .right
        case .meeting(let p):
            if p.a == .M || p.b == .M { return .right }
            if p.a == .S || p.b == .S { return .left }
            return .wide
        }
    }
}

public struct SpeakerCard: Sendable {
    public let action: SpeakerAction
    public let title: String
    public let quip: String
}

/// En situation: text, val som inte är omröstningar, och vilka kandidater som går att föreslå.
public struct SpeakerStep: Sendable {
    public let situation: String
    let extras: [SpeakerCard]
    let votes: [Candidate]
    /// En kvickhet per kandidat (båda behövs: används också när omröstning är tvingande).
    let voteQuips: [Candidate: String]

    func voteCard(_ c: Candidate) -> SpeakerCard {
        SpeakerCard(action: .vote(c), title: "Låt kammaren rösta om \(c.surname)", quip: voteQuips[c] ?? "")
    }

    public var cards: [SpeakerCard] { extras + Candidate.allCases.map(voteCard) }
}

/// Manuset: valnatten, vecka 1–5 i tre trådar, och sista veckan.
public struct SpeakerScript: Sendable {
    let opening: SpeakerStep
    let weeks: [[Thread: SpeakerStep]]
    let final: SpeakerStep

    func step(week: Int, thread: Thread) -> SpeakerStep {
        if week == 0 { return opening }
        if week >= timelineEnd { return final }
        return weeks[week - 1][thread]!
    }

    public var allSteps: [SpeakerStep] {
        [opening] + weeks.flatMap { [$0[.left]!, $0[.right]!, $0[.wide]!] } + [final]
    }
}

private func card(_ a: SpeakerAction, _ title: String, _ quip: String) -> SpeakerCard {
    SpeakerCard(action: a, title: title, quip: quip)
}
private let probeCard = card(.probe, "Kalla alla partiledare till samtal", "Samma kaffe. MP svarar som S.")
private let deadlineCard = card(.deadline, "Sätt en deadline: omröstning nästa vecka", "Om C får ha en deadline får du också.")

/// Skrivregler: reta alla lika mycket, inga siffror och inga utfall i kvickheterna.
public let speakerScript = SpeakerScript(
    opening: SpeakerStep(
        situation: "Valnatten är slut. Ingen sida har 175. Enligt tradition får största partiet försöka först. Enligt erfarenhet spelar det ingen roll.",
        extras: [card(.probe, "Kalla alla partiledare till samtal", "Åtta partiledare, ett besked: ”vi återkommer”.")],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "Störst parti först. S gillar traditionen.",
                    .kristersson: "Regeringen sitter kvar under tiden."]),
    weeks: [
        [ // 1: SD släpper ministerkravet
            .left: SpeakerStep(
                situation: "SD vill inte ha ministrar längre. Det gör Kristersson starkare – och S nervös.",
                extras: [card(.mission(.andersson), "Ge Andersson en vecka att förhandla", "S ringer C. C ringer tillbaka. Senare.")],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "V väntar på ministerposter. V väntar gärna.",
                            .kristersson: "SD trycker gult: ”ja, men”."]),
            .right: SpeakerStep(
                situation: "SD vill inte ha ministrar längre, bara inflytande. M tycker att det låter som en majoritet.",
                extras: [card(.mission(.kristersson), "Ge Kristersson en vecka att förhandla", "M har räknat förut. M räknar igen.")],
                votes: [.kristersson, .andersson],
                voteQuips: [.kristersson: "SD trycker gult: ”ja, men”.",
                            .andersson: "V väntar på ministerposter. V väntar gärna."]),
            .wide: SpeakerStep(
                situation: "SD släpper ministerkravet. Alla partier vill plötsligt prata med dig. Samtidigt.",
                extras: [card(.meeting(Pair(.C, .L)), "Kalla C och L till möte hos dig", "Två liberala partier, ett rum, ingen agenda.")],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "S har en tradition. Det är något.",
                            .kristersson: "SD trycker gult: ”ja, men”."]),
        ],
        [ // 2: C kräver totalpaket
            .left: SpeakerStep(
                situation: "C vill ha ett totalpaket. S skriver ett. Det blir långt.",
                extras: [card(.meeting(Pair(.C, .S)), "Kalla C och S till samma bord", "S tar med paketet. C tar med en lista."), deadlineCard],
                votes: [.andersson],
                voteQuips: [.andersson: "Det går om C vill. C vill ha ett paket först.",
                            .kristersson: "M, KD och L har ett paket. C har inte öppnat det."]),
            .right: SpeakerStep(
                situation: "C vill ha ett totalpaket. M, KD och L har ett färdigt. C har inte öppnat det.",
                extras: [card(.meeting(Pair(.C, .M)), "Kalla C och M till samma bord", "M tar med paketet. C tar med en sax."), deadlineCard],
                votes: [.kristersson],
                voteQuips: [.kristersson: "KD har ett krav: Kristersson.",
                            .andersson: "Det går om C vill. C vill ha ett paket först."]),
            .wide: SpeakerStep(
                situation: "C har satt en deadline för båda sidor. Talmannen har ingen deadline. Än.",
                extras: [probeCard],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "Det går om C vill. C vill ha ett paket först.",
                            .kristersson: "M, KD och L har ett paket. C har inte öppnat det."]),
        ],
        [ // 3: S vill regera utan V
            .left: SpeakerStep(
                situation: "S vill regera utan V. V säger att kravet ”inte går att påverka”. Båda menar det.",
                extras: [card(.meeting(Pair(.S, .V)), "Kalla S och V till möte hos dig", "Du bjuder på kaffe. Ingen dricker.")],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "V har principer. S har en plan.",
                            .kristersson: "L och SD tycker olika, tillsammans."]),
            .right: SpeakerStep(
                situation: "S har gjort sig av med V. Kristerssons sida undrar om det är en fälla.",
                extras: [card(.mission(.kristersson), "Ge Kristersson en vecka till", "KD föreslår ett möte om mötena.")],
                votes: [.kristersson, .andersson],
                voteQuips: [.kristersson: "L och SD tycker olika, tillsammans.",
                            .andersson: "V har principer. S har en plan."]),
            .wide: SpeakerStep(
                situation: "S vill regera utan V. V vill regera med S. Båda menar allvar.",
                extras: [probeCard],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "V har principer. S har en plan.",
                            .kristersson: "L och SD tycker olika, tillsammans."]),
        ],
        [ // 4: C väljer S:s totalpaket
            .left: SpeakerStep(
                situation: "C har valt S:s totalpaket. S firar försiktigt. V firar inte.",
                extras: [card(.mission(.andersson), "Ge Andersson en vecka att räkna", "S räknar. MP håller i miniräknaren.")],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "På papperet ser det ut som en regering.",
                            .kristersson: "KD har ett krav: Kristersson."]),
            .right: SpeakerStep(
                situation: "C har valt S:s paket. Kristerssons sida läser det ändå, för säkerhets skull.",
                extras: [card(.meeting(Pair(.C, .M)), "Kalla C och M till ett sista samtal", "M frågar om paketet går att byta.")],
                votes: [.kristersson, .andersson],
                voteQuips: [.kristersson: "KD har ett krav: Kristersson.",
                            .andersson: "På papperet ser det ut som en regering."]),
            .wide: SpeakerStep(
                situation: "C har valt S:s totalpaket. Vågmästaren har vägt. Vågen står still.",
                extras: [probeCard],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "På papperet ser det ut som en regering.",
                            .kristersson: "KD har ett krav: Kristersson."]),
        ],
        [ // 5: S–V-möte, samma besked
            .left: SpeakerStep(
                situation: "S och V har mötts i två timmar. Beskedet var detsamma som tidigare.",
                extras: [card(.meeting(Pair(.S, .V)), "Kalla S och V till ett tredje möte", "Tredje gången gillt, sägs det. Av någon.")],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "C bestämde sig. Sedan stod allt still.",
                            .kristersson: "SD trycker gult igen. Det är en vana nu."]),
            .right: SpeakerStep(
                situation: "S och V har mötts i två timmar. Kristersson ser på och väntar.",
                extras: [deadlineCard],
                votes: [.kristersson, .andersson],
                voteQuips: [.kristersson: "SD trycker gult igen. Det är en vana nu.",
                            .andersson: "C bestämde sig. Sedan stod allt still."]),
            .wide: SpeakerStep(
                situation: "Två timmars möte, samma besked. Det är också ett slags besked.",
                extras: [probeCard],
                votes: [.andersson, .kristersson],
                voteQuips: [.andersson: "C bestämde sig. Sedan stod allt still.",
                            .kristersson: "SD trycker gult igen. Det är en vana nu."]),
        ],
    ],
    final: SpeakerStep(
        situation: "C säger nej till V i regeringen, även om alternativet är extraval. Alternativet hörde det.",
        extras: [],
        votes: [.andersson, .kristersson],
        voteQuips: [.andersson: "Samma partier, samma krav, ny vecka.",
                    .kristersson: "Samma fyra partier som förra veckan."]))

/// Ett rykte i det fördolda: spelets påhitt, tydligt skilt från de verkliga rubrikerna.
public struct Rumor: Sendable {
    /// Veckan ryktet kommer (när tiden går fram till den).
    public let week: Int
    public let thread: Thread
    public let text: String
    /// Linjer som ryktet sätter (nil = tar bort linjen).
    let changes: [(pair: Pair, kind: RelationKind?, label: String)]
}

public let rumorTable: [Rumor] = [
    Rumor(week: 1, thread: .left, text: "C och S har setts äta lunch.", changes: [(Pair(.C, .S), .negotiating, "Lunch på stan")]),
    Rumor(week: 1, thread: .right, text: "M och C pratade länge i korridoren.", changes: [(Pair(.C, .M), .negotiating, "Korridorsamtal")]),
    Rumor(week: 1, thread: .wide, text: "KD har bokat det största konferensrummet.", changes: [(Pair(.KD, .L), .attraction, "Samma konferensrum")]),
    Rumor(week: 2, thread: .left, text: "V och MP har startat en chattgrupp. S är inte med.", changes: [(Pair(.V, .MP), .attraction, "Egen chattgrupp")]),
    Rumor(week: 2, thread: .right, text: "L och SD hälsade på varandra i hissen.", changes: [(Pair(.SD, .L), .negotiating, "Artigt i hissen")]),
    Rumor(week: 3, thread: .left, text: "V har slutat svara när S ringer.", changes: [(Pair(.S, .V), .conflict, "Svarar inte")]),
    Rumor(week: 3, thread: .right, text: "C:s gruppledare sågs på M:s fest. Hen gick tidigt.", changes: [(Pair(.C, .M), .negotiating, "Gick tidigt från festen")]),
    Rumor(week: 4, thread: .left, text: "MP och C delade taxi från riksdagen.", changes: [(Pair(.C, .MP), .attraction, "Delad taxi")]),
    Rumor(week: 4, thread: .right, text: "SD bjöd M på kaffe. M betalade.", changes: [(Pair(.M, .SD), .attraction, "Kaffe, M betalade")]),
    Rumor(week: 5, thread: .wide, text: "Någon i riksdagen har börjat skriva valaffischer.", changes: []),
]

public struct SpeakerGame: Sendable {
    public static let tips = [
        "Du är talmannen. Du föreslår statsminister och kammaren röstar. Det brukar gå bra. I år gick det inte.",
        "Riksdagens tålamod är hur länge riksdagen står ut med att du inte röstar. Samtal, uppdrag och möten tar ett streck var. När strecken är slut finns bara omröstningar kvar.",
        "Dina val styr vad som händer härnäst. Mellan dragen förhandlar partierna i det fördolda – det syns som rykten och i nätverket.",
        "Fyra fallna omröstningar ger extraval. Vad ett val kostar ser du först efteråt.",
    ]
    static let disclaimer = "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt. Ryktena hittade vi på."
    private static let maxPatience = 3

    public enum Phase: Equatable, Sendable { case choosing, outcome, rumor, ended }

    private struct Knowledge {
        let at: Int
        let support: Int
        /// "sonderingen", "uppdraget" eller "omröstningen".
        let source: String
    }

    /// Ett rykte som gäller tills en verklig rubrik ändrar samma par.
    private struct Overlay {
        let kind: RelationKind?
        let label: String
        let since: Int
    }

    public private(set) var phase: Phase = .choosing
    public private(set) var headlineIndex = 0
    public private(set) var thread: Thread = .wide
    public private(set) var attemptsLeft = 4
    public private(set) var patience = maxPatience
    public private(set) var talksContinue = 0
    public private(set) var outcome: String?
    public private(set) var effect: Effect?
    public private(set) var rumor: Rumor?
    public private(set) var ending: Ending?
    private var pendingEnding: Ending?
    private var mustVote = false
    private var known: [Candidate: Knowledge] = [:]
    private var closest: (candidate: Candidate, support: Int)?
    private var overlays: [Pair: Overlay] = [:]
    private var threadCount: [Thread: Int] = [:]

    public init() {}

    public var headline: Headline { BrytareModell.headline(after: headlineIndex) }
    private var step: SpeakerStep { speakerScript.step(week: headlineIndex, thread: thread) }
    private var isLastWeek: Bool { headlineIndex >= timelineEnd }
    private var forced: Bool { patience == 0 || mustVote || isLastWeek }

    public var question: String {
        var text = step.situation
        if mustVote { text = "Din deadline har gått ut. Nu måste kammaren rösta. " + text }
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
        guard phase == .choosing else { return [] }
        if forced { return Candidate.allCases.map(step.voteCard) }
        return step.extras + step.votes.map(step.voteCard)
    }

    public var choices: [Choice] { cards.map { Choice(id: $0.action.id, title: $0.title, quip: $0.quip) } }

    /// Linjerna i nätverket just nu: de verkliga rubrikernas linjer, med rykten ovanpå
    /// så länge ingen senare rubrik har ändrat samma par.
    public var relations: [KeyRelation] {
        let base = keyRelations(after: headlineIndex)
        var byPair = Dictionary(uniqueKeysWithValues: base.map { ($0.pair, $0) })
        for (pair, o) in overlays where sameBase(pair, o.since, headlineIndex) {
            if let kind = o.kind {
                byPair[pair] = KeyRelation(pair: pair, kind: kind, label: o.label, isNew: o.since == headlineIndex)
            } else {
                byPair[pair] = nil
            }
        }
        return byPair.values.sorted { ($0.pair.a.rawValue, $0.pair.b.rawValue) < ($1.pair.a.rawValue, $1.pair.b.rawValue) }
    }

    public mutating func choose(_ id: String) {
        guard let card = cards.first(where: { $0.action.id == id }) else { return }
        thread = card.action.thread
        threadCount[thread, default: 0] += 1
        switch card.action {
        case .probe:
            stall()
            learn(Candidate.allCases, from: "sonderingen")
            resolve("Samtalen tog en vecka. Sedan visste du: \(knownText(Candidate.allCases)).",
                    Effect(title: "STÖDET AVSLÖJAT", tone: .neutral, chips: stallChips + knownChips(Candidate.allCases)))
        case .mission(let c):
            stall()
            learn([c], from: "uppdraget")
            resolve("Förhandlingen tog en vecka. Sedan visste du: \(knownText([c])).",
                    Effect(title: "UPPDRAGET KLART", tone: .neutral, chips: stallChips + knownChips([c])))
        case .meeting(let p):
            stall()
            resolve("Mötet mellan \(p.a.rawValue) och \(p.b.rawValue) tog en vecka. Beskedet var detsamma som tidigare.",
                    Effect(title: "INGET NYTT", tone: .neutral, chips: stallChips))
        case .deadline:
            talksContinue += 1
            let gained = patience < Self.maxPatience
            patience = min(Self.maxPatience, patience + 1)
            mustVote = true
            resolve("Du sätter en deadline till nästa vecka. " + (gained ? "Riksdagen gillar deadlines. Tålamodet stiger." : "Tålamodet var redan fullt."),
                    Effect(title: "DEADLINE SATT", tone: .neutral,
                           chips: (gained ? ["Tålamod +1"] : []) + ["Samtalen fortsätter +1", "Nästa vecka: omröstning"]))
        case .vote(let c):
            vote(c)
        }
    }

    /// Spelaren har läst rutan: från utfallet går tiden fram (och ett rykte kan komma), från ryktet till nästa val.
    public mutating func proceed() {
        switch phase {
        case .outcome:
            outcome = nil
            effect = nil
            if !isLastWeek { headlineIndex += 1 }
            if let e = pendingEnding {
                ending = e
                phase = .ended
            } else if let r = rumorTable.first(where: { $0.week == headlineIndex && $0.thread == thread }) {
                for change in r.changes { overlays[change.pair] = Overlay(kind: change.kind, label: change.label, since: headlineIndex) }
                rumor = r
                phase = .rumor
            } else {
                phase = .choosing
            }
        case .rumor:
            rumor = nil
            phase = .choosing
        case .choosing, .ended:
            break
        }
    }

    private mutating func resolve(_ text: String, _ e: Effect, ending: Ending? = nil) {
        outcome = text
        effect = e
        pendingEnding = ending
        phase = .outcome
    }

    private let stallChips = ["Tålamod −1", "Samtalen fortsätter +1"]

    private mutating func stall() {
        talksContinue += 1
        patience -= 1
    }

    private mutating func learn(_ candidates: [Candidate], from source: String) {
        let at = min(headlineIndex + 1, timelineEnd)
        for c in candidates { known[c] = Knowledge(at: at, support: support(c, at: at), source: source) }
    }

    private func knownText(_ candidates: [Candidate]) -> String {
        candidates.compactMap { c in known[c].map { "\(c.name) \($0.support)" } }.joined(separator: ", ")
    }

    private func knownChips(_ candidates: [Candidate]) -> [String] {
        candidates.compactMap { c in known[c].map { "\(c.surname) \($0.support)" } }
    }

    private mutating func vote(_ c: Candidate) {
        mustVote = false
        let r = tally(historicVotes(for: c, after: headlineIndex))
        known[c] = Knowledge(at: headlineIndex, support: r.supportSeats, source: "omröstningen")
        if r.supportSeats > (closest?.support ?? -1) { closest = (c, r.supportSeats) }
        let numbers = ["\(r.supportSeats) stöd", "\(r.nej) nej"]
        if r.passed {
            resolve(voteText(r), Effect(title: "GÅR IGENOM", tone: .good, chips: numbers),
                    ending: Ending(title: "REGERING", text: "\(c.name) blev statsminister.", isExtraval: false))
            return
        }
        attemptsLeft -= 1
        resolve(voteText(r) + " \(c.name) saknade \(majority - r.supportSeats) mandat. " + why(c),
                Effect(title: "FALLER", tone: .bad, chips: ["Försök −1"] + numbers),
                ending: attemptsLeft == 0 ? extraval() : nil)
    }

    private func support(_ c: Candidate, at h: Int) -> Int {
        tally(historicVotes(for: c, after: h)).supportSeats
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

    /// Har de verkliga rubrikerna lämnat paret orört mellan två veckor?
    private func sameBase(_ pair: Pair, _ from: Int, _ to: Int) -> Bool {
        func at(_ h: Int) -> (RelationKind, String)? {
            keyRelations(after: h).first { $0.pair == pair }.map { ($0.kind, $0.label) }
        }
        return at(from)?.0 == at(to)?.0 && at(from)?.1 == at(to)?.1
    }

    private func extraval() -> Ending {
        var text = "Ingen fick ihop 175."
        if let c = closest {
            text += " Närmast kom \(c.candidate.name) med \(c.support) – \(majority - c.support) mandat för lite."
        }
        let leaning = threadCount.max { $0.value < $1.value }?.key ?? .wide
        switch leaning {
        case .left: text += " Du lutade dig åt Andersson."
        case .right: text += " Du lutade dig åt Kristersson."
        case .wide: text += " Du höll dig till processen."
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
