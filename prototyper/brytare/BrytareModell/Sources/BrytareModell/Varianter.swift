// Omgång 7: två varianter där klockan går och nyheter pausar tiden.

/// Gemensamt för varianterna med klocka (appen visar dem med samma skärm).
public protocol ClockGame: Sendable {
    var title: String { get }
    var tips: [String] { get }
    var world: World { get }
    var meters: [Meter] { get }
    /// Korten som går att spela just nu (bara de som spelaren har råd med).
    var cards: [Choice] { get }
    /// Vad senaste kortet ledde till.
    var effect: Effect? { get }
    var ending: Ending? { get }
    mutating func play(_ id: String)
    mutating func tick(days: Int)
    mutating func resume()
}

let fiction = "Rubrikerna är verkliga. Ryktena och utgången är spelets påhitt – det hände inte i verkligheten."

private let leftSide: Set<P> = [.V, .S, .MP]
private let rightSide: Set<P> = [.M, .KD, .L, .SD]

/// En bro går mellan blocken (C räknas som mitten och bygger broar åt båda håll).
private func isBridge(_ r: KeyRelation) -> Bool {
    guard r.kind != .conflict else { return false }
    let a = r.pair.a, b = r.pair.b
    if a == .C || b == .C { return true }
    return leftSide.contains(a) != leftSide.contains(b)
}

// MARK: - Knuten

/// Spelaren är låsningen och vinner om det blir extraval. Motkraften Uppgörelsen fylls av broar mellan blocken.
public struct KnutenGame: ClockGame {
    public static let redLineCost = 3
    public static let utspelCost = 2
    public static let utspelDrop = 15
    public static let segaCost = 2
    public static let segaDays = 6

    public let title = "Knuten"
    public let tips = [
        "Du är knuten – själva låsningen i regeringsbildningen. Du vinner om det blir extraval.",
        "Uppgörelsen är förhandlarnas mätare. Den fylls varje dag, snabbare ju fler broar som finns mellan blocken. Blir den full bildas en regering och du har förlorat.",
        "Dagarna går av sig själva. När en nyhet kommer står tiden still. Verkliga nyheter som låser är gåvor till dig; de som öppnar ger förhandlarna fart.",
        "Prestige är din valuta. Den växer långsamt. Röda linjer, utspel och sega förhandlingar kostar.",
    ]

    public private(set) var world: World
    public private(set) var prestige = 3
    /// Förhandlarnas mätare, 0–100.
    public private(set) var settlement = 0.0
    public private(set) var effect: Effect?
    public private(set) var ending: Ending?
    private var segaLeft = 0
    private var moves = 0
    private var gifts = 0

    public init(rumors: RumorMode) { world = World(rumors: rumors) }

    public var meters: [Meter] {
        [Meter(name: "Datum", value: dateText(day: world.day)),
         Meter(name: "Prestige", value: "\(prestige)"),
         Meter(name: "Uppgörelsen", value: "\(Int(settlement)) %",
               caption: "Förhandlarnas mätare. Full = en regering bildas och du förlorar.")]
    }

    private var bridges: [KeyRelation] {
        world.relations.filter(isBridge).sorted { ($0.pair.a.seats + $0.pair.b.seats) > ($1.pair.a.seats + $1.pair.b.seats) }
    }

    public var cards: [Choice] {
        guard ending == nil, world.paused == nil else { return [] }
        var list: [Choice] = []
        if prestige >= Self.redLineCost, let b = bridges.first {
            list.append(Choice(id: "redline.\(b.pair.a.rawValue).\(b.pair.b.rawValue)",
                               title: "Dra en röd linje mellan \(b.pair.a.rawValue) och \(b.pair.b.rawValue)",
                               quip: "Kostar \(Self.redLineCost) Prestige. Någon måste säga nej. Du hjälper till."))
        }
        if prestige >= Self.utspelCost {
            list.append(Choice(id: "utspel", title: "Gör ett utspel i morgonsoffan",
                               quip: "Kostar \(Self.utspelCost) Prestige. Ett ord som ”svek” räcker långt."))
        }
        if prestige >= Self.segaCost && segaLeft == 0 {
            list.append(Choice(id: "sega", title: "Sega: ”Kongressen måste avgöra”",
                               quip: "Kostar \(Self.segaCost) Prestige. Kongressen är om ett år."))
        }
        return list
    }

    public mutating func play(_ id: String) {
        guard cards.contains(where: { $0.id == id }) else { return }
        moves += 1
        if id.hasPrefix("redline"), let b = bridges.first {
            prestige -= Self.redLineCost
            world.set(b.pair, .conflict, "Röd linje (ditt verk)")
            effect = Effect(title: "RÖD LINJE", tone: .good, chips: ["Prestige −\(Self.redLineCost)", "\(b.pair.a.rawValue) ✋ \(b.pair.b.rawValue)"])
        } else if id == "utspel" {
            prestige -= Self.utspelCost
            settlement = max(0, settlement - Double(Self.utspelDrop))
            effect = Effect(title: "UTSPEL", tone: .good, chips: ["Prestige −\(Self.utspelCost)", "Uppgörelsen −\(Self.utspelDrop)"])
        } else if id == "sega" {
            prestige -= Self.segaCost
            segaLeft = Self.segaDays
            effect = Effect(title: "SEGA", tone: .good, chips: ["Prestige −\(Self.segaCost)", "Uppgörelsen står still \(Self.segaDays) dagar"])
        }
        // Var andra drag läcker.
        if moves % 2 == 0 { world.scheduleRumor("Läcka: någon har sett dig elda på. Förhandlarna skärper sig.", changes: []) }
    }

    public mutating func tick(days: Int) {
        for _ in 0..<days {
            guard ending == nil, world.paused == nil else { return }
            let before = world.day
            world.tick(days: 1)
            if world.day > before { daily() }
            if let n = world.paused { onNews(n); return }
            if world.isOver { finish() }
        }
    }

    public mutating func resume() {
        world.resume()
        if let n = world.paused { onNews(n) } else if world.isOver { finish() }
    }

    private mutating func daily() {
        if world.day % 3 == 0 { prestige += 1 }
        if segaLeft > 0 { segaLeft -= 1; return }
        settlement += 0.4 + 1.2 * Double(bridges.count)
        checkLost()
    }

    private mutating func onNews(_ n: NewsItem) {
        switch n.tag {
        case .locks: prestige += 3; gifts += 1
        case .opens: settlement += 6
        case .lampOut, .none: break
        }
        if n.kind == .rumor && n.title.hasPrefix("Läcka:") { settlement += 5 }
        checkLost()
    }

    private mutating func checkLost() {
        guard ending == nil, settlement >= 100 else { return }
        settlement = 100
        ending = Ending(title: "TÄNK OM: EN REGERING",
                        text: "Förhandlarna hann före. Den \(dateText(day: world.day)) gick en regering igenom i kammaren. Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                        isExtraval: false, footnote: fiction)
    }

    private mutating func finish() {
        guard ending == nil else { return }
        ending = Ending(title: "EXTRAVAL",
                        text: "Knuten höll. Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                        isExtraval: true, footnote: fiction)
    }
}

// MARK: - Hamna i regering

/// Spelaren företräder ett parti och vill in i en regering som klarar en omröstning.
public struct RegeringGame: ClockGame {
    public let party: P
    public private(set) var world: World
    public var kapital = 3
    public private(set) var lamps = 4
    public private(set) var voters = 3
    public private(set) var effect: Effect?
    public private(set) var ending: Ending?

    public init(party: P, rumors: RumorMode) {
        self.party = party
        world = World(rumors: rumors)
    }

    public var title: String { "Hamna i regering – \(party.rawValue)" }
    public var tips: [String] {
        ["Du leder \(party.info.name). Målet: sitta i en regering som klarar omröstningen i kammaren – färre än 175 nej.",
         "Regeringen är ditt parti och de som samarbetar med dig (🤝). Partier som pratar med dig (💬) utan röd linje trycker gult. Alla andra röstar nej.",
         "Dagarna går av sig själva och nyheterna ändrar förutsättningarna. Kapital kommer med tiden. Ring, erbjud ministerposter, släpp krav – och begär omröstning när du tror att det räcker.",
         "Varje fallen omröstning släcker en av talmannens lampor. Utan lampor, eller när tiden är slut, blir det extraval."]
    }

    public var meters: [Meter] {
        [Meter(name: "Datum", value: dateText(day: world.day)),
         Meter(name: "Kapital", value: "\(kapital)"),
         Meter(name: "Lampor", value: String(repeating: "●", count: lamps) + String(repeating: "○", count: 4 - lamps)),
         Meter(name: "Väljarstöd", value: String(repeating: "■", count: voters) + String(repeating: "□", count: 3 - voters))]
    }

    /// Hur en omröstning skulle gå just nu.
    public var prospect: (government: [P], result: VoteResult) {
        let partners = P.allCases.filter { $0 != party && world.relation(party, $0)?.kind == .attraction }
            .sorted { $0.seats > $1.seats }
        var gov: [P] = [party]
        for q in partners where !gov.contains(where: { world.relation($0, q)?.kind == .conflict }) { gov.append(q) }
        var votes = Dictionary(uniqueKeysWithValues: P.allCases.map { ($0, Vote.nej) })
        for p in gov { votes[p] = .ja }
        for q in P.allCases where !gov.contains(q) {
            if let k = world.relation(party, q)?.kind, k != .conflict { votes[q] = .gult }
        }
        return (gov.sorted { leftToRight.firstIndex(of: $0)! < leftToRight.firstIndex(of: $1)! }, tally(votes))
    }

    private func target(_ wanted: (P) -> Bool) -> P? {
        P.allCases.filter { $0 != party && wanted($0) }.max { $0.seats < $1.seats }
    }

    public var cards: [Choice] {
        guard ending == nil, world.paused == nil else { return [] }
        var list = [Choice(id: "vote", title: "Be talmannen om en omröstning", quip: "Kammaren röstar på din regering.")]
        if kapital >= 3, let x = target({ world.relation(party, $0)?.kind == .negotiating }) {
            list.append(Choice(id: "offer.\(x.rawValue)", title: "Erbjud \(x.rawValue) ministerposter",
                               quip: "Kostar 3 Kapital. Det finns alltid ett departement till."))
        } else if voters > 1, let x = target({ world.relation(party, $0)?.kind == .conflict }) {
            list.append(Choice(id: "release.\(x.rawValue)", title: "Släpp kravet mot \(x.rawValue)",
                               quip: "Kostar väljarstöd. Det var ett krav, inte ett löfte. Typ."))
        }
        if kapital >= 1, let x = target({ world.relation(party, $0) == nil }) {
            list.append(Choice(id: "ring.\(x.rawValue)", title: "Ring \(x.rawValue)", quip: "Kostar 1 Kapital. Någon svarar till slut."))
        }
        return list
    }

    public mutating func play(_ id: String) {
        guard ending == nil, world.paused == nil else { return }
        let parts = id.split(separator: ".").map(String.init)
        let x = parts.count > 1 ? P(rawValue: parts[1]) : nil
        switch parts[0] {
        case "vote":
            let (gov, r) = prospect
            if r.passed {
                effect = Effect(title: "GÅR IGENOM", tone: .good, chips: ["\(r.supportSeats) stöd", "\(r.nej) nej"])
                ending = Ending(title: "TÄNK OM: \(party.rawValue) I REGERING",
                                text: "Den \(dateText(day: world.day)) gick regeringen \(gov.map(\.rawValue).joined(separator: " + ")) igenom: \(r.supportSeats) stöd, \(r.nej) nej. Det hände inte i verkligheten.",
                                isExtraval: false, footnote: fiction)
            } else {
                lamps -= 1
                effect = Effect(title: "FALLER", tone: .bad, chips: ["Lampa −1", "\(r.supportSeats) stöd", "\(r.nej) nej"])
                if lamps == 0 { extraval("Fyra omröstningar föll.") }
            }
        case "offer":
            guard let x, kapital >= 3, world.relation(party, x)?.kind == .negotiating else { return }
            kapital -= 3
            world.set(Pair(party, x), .attraction, "Ministerposter")
            // Röda linjer: de som krockar med X och inte redan har kontakt med dig blir fiender.
            var angry: [P] = []
            for q in P.allCases where q != party && q != x && world.relation(x, q)?.kind == .conflict && world.relation(party, q) == nil {
                world.set(Pair(party, q), .conflict, "Arg över \(x.rawValue)")
                angry.append(q)
            }
            effect = Effect(title: "ERBJUDANDE", tone: .neutral, chips: ["Kapital −3", "\(x.rawValue) 🤝"] + angry.map { "\($0.rawValue) ✋" })
            world.scheduleRumor("Läcka: ditt erbjudande till \(x.rawValue) har läckt.", changes: [])
        case "release":
            guard let x, world.relation(party, x)?.kind == .conflict, voters > 1 else { return }
            voters -= 1
            world.set(Pair(party, x), nil, "")
            effect = Effect(title: "KRAV SLÄPPT", tone: .neutral, chips: ["Väljarstöd −1", "\(x.rawValue): ingen röd linje"])
        case "ring":
            guard let x, kapital >= 1, world.relation(party, x) == nil else { return }
            kapital -= 1
            world.set(Pair(party, x), .negotiating, "Samtal")
            effect = Effect(title: "SAMTAL", tone: .neutral, chips: ["Kapital −1", "\(x.rawValue) 💬"])
        default:
            return
        }
    }

    public mutating func tick(days: Int) {
        for _ in 0..<days {
            guard ending == nil, world.paused == nil else { return }
            let before = world.day
            world.tick(days: 1)
            if world.day > before && world.day % 3 == 0 { kapital += 1 }
            if let n = world.paused { onNews(n); return }
            if world.isOver { extraval("Tiden tog slut.") }
        }
    }

    public mutating func resume() {
        world.resume()
        if let n = world.paused { onNews(n) } else if world.isOver { extraval("Tiden tog slut.") }
    }

    private mutating func onNews(_ n: NewsItem) {
        if n.tag == .lampOut {
            lamps = max(0, lamps - 1)
            if lamps == 0 { extraval("Talmannens lampor tog slut.") }
        }
        if n.kind == .rumor && n.title.hasPrefix("Läcka:") {
            voters = max(0, voters - 1)
            if voters == 0 { extraval("Väljarna lämnade partiet.") }
        }
    }

    private mutating func extraval(_ why: String) {
        guard ending == nil else { return }
        ending = Ending(title: "EXTRAVAL", text: "\(why) \(party.info.name) kom aldrig in i regeringen.", isExtraval: true, footnote: fiction)
    }
}
