// Spelets regler som ett rent värde. Ingen tid och ingen SwiftUI här:
// när något ska hända senare returnerar metoderna en `FollowUp` som appen schemalägger.
//
// - Varje parti har ett krav. Uppfyller du kravet trycker partiet ja (grönt) eller avstår (gult).
// - Vissa krav krockar. Slår du på ett parti slås de som krockar av (fastgood.cheap-effekten).
// - Negativ parlamentarism: kandidaten faller om minst 175 röstar nej, alltså krävs minst 175 i stöd (ja + gult).
// - Så fort stödet är nära (150+) kommer nästa verkliga rubrik och ändrar kraven.
// - Fyra fallna statsministeromröstningar = extraval.

/// Vem som slog av vilka partier, för att appen ska kunna visa det.
public struct Kick: Equatable, Sendable {
    public var serial: Int
    /// nil = en rubrik sparkade ut partiet.
    public var by: P?
    public var parties: [P]
}

/// Något appen ska göra senare. Modellen har ingen klocka; appen väntar och anropar sedan metoden.
public enum FollowUp: Equatable, Sendable {
    /// Anropa `fireEvent()` efter så här många sekunder.
    case headline(after: Double)
    /// Anropa `finishVote()` efter så här många sekunder.
    case finishVote(after: Double)

    /// Hur länge appen ska vänta.
    public var delay: Double {
        switch self {
        case .headline(let after), .finishVote(let after): return after
        }
    }
}

public struct VoteResult: Equatable, Sendable {
    public let ja: Int
    public let gult: Int
    public let nej: Int
    public init(ja: Int, gult: Int, nej: Int) {
        self.ja = ja; self.gult = gult; self.nej = nej
    }
    public var passed: Bool { nej < majority }
}

public struct Game: Sendable {
    public private(set) var rules = startRules()
    public private(set) var backing: Set<P> = []
    public private(set) var nextEvent = 0
    public private(set) var headline = startHeadline
    /// Ökar varje gång en ny rubrik visas, så att appen kan pulsera rubriken.
    public private(set) var headlineSerial = 0
    /// En rubrik är på väg (appen väntar på att anropa `fireEvent()`).
    public private(set) var pendingEvent = false
    public private(set) var attemptsLeft = 4
    /// Pågående omröstning (visas i 2,8 s).
    public private(set) var lastVote: VoteResult?
    public private(set) var isExtraval = false
    public private(set) var kick = Kick(serial: 0, by: nil, parties: [])
    /// De senaste händelserna, nyast först (högst tre).
    public private(set) var log: [String] = []

    public init() {}

    public var backingSeats: Int { backing.reduce(0) { $0 + $1.seats } }
    public var nejSeats: Int { totalSeats - backingSeats }
    public var jaSeats: Int { backing.filter { (rules.supportVote[$0] ?? .ja) == .ja }.reduce(0) { $0 + $1.seats } }
    public var gultSeats: Int { backingSeats - jaSeats }
    public var wouldPass: Bool { nejSeats < majority }
    public var isNear: Bool { backingSeats >= nearLimit }
    public var eventsLeft: Int { headlines.count - nextEvent }
    public var locked: Bool { lastVote != nil || isExtraval }

    public func vote(of p: P) -> Vote {
        backing.contains(p) ? (rules.supportVote[p] ?? .ja) : .nej
    }

    /// Spelaren slår på eller av ett parti.
    @discardableResult
    public mutating func toggle(_ p: P) -> FollowUp? {
        guard !locked else { return nil }
        if backing.contains(p) {
            backing.remove(p)
            note("\(p.rawValue) av")
        } else {
            let losers = backing.filter { rules.clash($0, p) }.sorted { $0.seats > $1.seats }
            backing.subtract(losers)
            backing.insert(p)
            if losers.isEmpty {
                note("\(p.rawValue) på")
            } else {
                kick = Kick(serial: kick.serial + 1, by: p, parties: losers)
                note("\(p.rawValue) på → " + losers.map(\.rawValue).joined(separator: ", ") + " slogs av")
            }
        }
        guard !pendingEvent, eventsLeft > 0, isNear else { return nil }
        return schedule(after: 0.9)
    }

    /// Nästa rubrik slår ner. Anropas av appen när en `.headline`-väntan är över.
    @discardableResult
    public mutating func fireEvent() -> FollowUp? {
        guard pendingEvent else { return nil }
        pendingEvent = false
        guard eventsLeft > 0 else { return nil }
        let h = headlines[nextEvent]
        nextEvent += 1
        h.apply(&rules)
        var out = backing.intersection(h.ejects)
        backing.subtract(out)
        while let (x, y) = firstClash() {
            let loser = h.ejects.contains(x) ? x : (h.ejects.contains(y) ? y : (x.seats < y.seats ? x : y))
            backing.remove(loser)
            out.insert(loser)
        }
        headline = h
        headlineSerial += 1
        if !out.isEmpty {
            kick = Kick(serial: kick.serial + 1, by: nil, parties: out.sorted { $0.seats > $1.seats })
            note("Rubrik: " + out.map(\.rawValue).joined(separator: ", ") + " hoppade av")
        }
        // Historien låter dig aldrig vinna: står det fortfarande en majoritet kommer nästa rubrik direkt.
        guard wouldPass, eventsLeft > 0 else { return nil }
        return schedule(after: 2.6)
    }

    /// Talmannen låter riksdagen rösta om statsministern.
    @discardableResult
    public mutating func callVote() -> FollowUp? {
        guard !locked, !pendingEvent else { return nil }
        let r = VoteResult(ja: jaSeats, gult: gultSeats, nej: nejSeats)
        lastVote = r
        if !r.passed { attemptsLeft -= 1 }
        note(r.passed ? "Omröstning: går igenom" : "Omröstning: faller med \(r.nej) nej")
        return .finishVote(after: 2.8)
    }

    /// Omröstningsresultatet har visats klart. Anropas av appen när en `.finishVote`-väntan är över.
    @discardableResult
    public mutating func finishVote() -> FollowUp? {
        guard let r = lastVote else { return nil }
        lastVote = nil
        if !r.passed && attemptsLeft == 0 { isExtraval = true }
        guard !isExtraval, eventsLeft > 0 else { return nil }
        return schedule(after: 0.4)
    }

    /// Spela igen från valnatten. Räknarna för rubrik och kick fortsätter så att appen ser ändringen.
    public mutating func reset() {
        let serial = headlineSerial + 1
        let lastKick = kick
        self = Game()
        headlineSerial = serial
        kick = lastKick
    }

    private mutating func schedule(after delay: Double) -> FollowUp {
        pendingEvent = true
        return .headline(after: delay)
    }

    private func firstClash() -> (P, P)? {
        let list = Array(backing)
        for i in list.indices {
            for j in list.indices where j > i {
                if rules.clash(list[i], list[j]) { return (list[i], list[j]) }
            }
        }
        return nil
    }

    private mutating func note(_ s: String) {
        log.insert(s, at: 0)
        if log.count > 3 { log.removeLast() }
    }
}
