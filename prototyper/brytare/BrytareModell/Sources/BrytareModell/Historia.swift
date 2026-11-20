// Tidslinjen för perspektivspelen: hur partierna röstade om varje kandidat
// efter h verkliga rubriker (h = 0 är valnatten, h = 6 är 18 nov).
// Rösterna följer historien och går inte att ändra; spelen låter spelaren välja runt dem.

public enum Candidate: String, CaseIterable, Sendable {
    case andersson, kristersson

    public var name: String {
        switch self {
        case .andersson: return "Andersson (S)"
        case .kristersson: return "Kristersson (M)"
        }
    }
}

/// Antal rubriker på tidslinjen.
public let timelineEnd = headlines.count

/// Rubriken som senast slog ner efter h rubriker.
public func headline(after h: Int) -> Headline {
    h == 0 ? startHeadline : headlines[h - 1]
}

/// Hur varje parti röstar om kandidaten efter h rubriker.
public func historicVotes(for candidate: Candidate, after h: Int) -> [P: Vote] {
    var votes = Dictionary(uniqueKeysWithValues: P.allCases.map { ($0, Vote.nej) })
    switch candidate {
    case .andersson:
        votes[.S] = .ja
        votes[.MP] = .ja
        votes[.V] = h < 3 ? .ja : .nej    // rubrik 3: S vill regera utan V
        votes[.C] = h < 4 ? .nej : .ja    // rubrik 4: C väljer S:s totalpaket
    case .kristersson:
        votes[.M] = .ja
        votes[.KD] = .ja
        votes[.L] = .ja                   // Kristersson utan SD-ministrar
        votes[.SD] = h < 1 ? .nej : .gult // SD kräver ministrar tills rubrik 1
        // C röstar nej hela vägen. Rubrik 1 och 2 kom samma dag (6 nov): när SD släppte
        // ministerkravet krävde C samtidigt ett totalpaket, och i rubrik 4 valde C S:s.
    }
    return votes
}

/// Räknar ihop en omröstning.
public func tally(_ votes: [P: Vote]) -> VoteResult {
    var ja = 0, gult = 0, nej = 0
    for p in P.allCases {
        switch votes[p] ?? .nej {
        case .ja: ja += p.seats
        case .gult: gult += p.seats
        case .nej: nej += p.seats
        }
    }
    return VoteResult(ja: ja, gult: gult, nej: nej)
}

extension VoteResult {
    /// Stöd = ja + gult.
    public var supportSeats: Int { ja + gult }
}
