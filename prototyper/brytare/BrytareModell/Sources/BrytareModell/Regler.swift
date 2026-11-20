// Krav, krockar och hur partierna röstar.

/// Två partier vars krav utesluter varandra. Ordningen spelar ingen roll.
public struct Pair: Hashable, Sendable {
    public let a: P
    public let b: P
    public init(_ x: P, _ y: P) {
        if x.rawValue < y.rawValue { a = x; b = y } else { a = y; b = x }
    }
}

public enum Vote: Sendable { case ja, gult, nej }

public struct Rules: Sendable {
    public var demand: [P: String]
    /// Krav som utesluter varandra.
    public var pairs: Set<Pair>
    /// Hur partiet röstar när kravet är uppfyllt.
    public var supportVote: [P: Vote]
    /// Partier som drar åt samma håll (visas i grafen; påverkar inte krockarna).
    public var allies: Set<Pair>
    public func clash(_ x: P, _ y: P) -> Bool { pairs.contains(Pair(x, y)) }
}

public func startRules() -> Rules {
    var pairs = Set<Pair>()
    for l in anderssonSide { for r in kristerssonSide { pairs.insert(Pair(l, r)) } }
    pairs.insert(Pair(.V, .C))
    pairs.insert(Pair(.SD, .C))
    pairs.insert(Pair(.SD, .L))
    return Rules(
        demand: [
            .S: "Andersson som statsminister",
            .V: "Ministerposter för V",
            .MP: "En rödgrön regering",
            .C: "Inget V och inget SD i regeringen",
            .L: "Kristersson – och inga SD-ministrar",
            .KD: "Kristersson som statsminister",
            .M: "Kristersson som statsminister",
            .SD: "Ministerposter för SD",
        ],
        pairs: pairs,
        supportVote: [.S: .ja, .V: .ja, .MP: .ja, .C: .gult, .L: .ja, .KD: .ja, .M: .ja, .SD: .ja],
        allies: [Pair(.S, .V), Pair(.S, .MP), Pair(.V, .MP),
                 Pair(.M, .KD), Pair(.M, .L), Pair(.KD, .L), Pair(.M, .SD), Pair(.KD, .SD)]
    )
}
