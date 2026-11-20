import Foundation

// Data för talmannens tre relationsvyer (halvcirkel, tabell, ett parti).
// Allt bygger på keyRelations/removedRelations i Graf.swift.

/// Ett säte i riksdagens halvcirkel. x i [-1, 1], y i [0, 1] (uppåt), vinkel från π (vänster) till 0 (höger).
public struct Seat: Sendable {
    public let party: P
    public let x: Double
    public let y: Double
    public let angle: Double
}

/// Riksdagens 349 säten i en halvcirkel, partierna från vänster till höger.
public func hemicycleSeats() -> [Seat] {
    let rows = 10
    let inner = 0.4
    let radii = (0..<rows).map { inner + (1 - inner) * Double($0) / Double(rows - 1) }
    // Fördela sätena på raderna efter radielängd (största rest får de sista).
    let total = radii.reduce(0, +)
    let exact = radii.map { Double(totalSeats) * $0 / total }
    var counts = exact.map { Int($0) }
    let order = exact.indices.sorted { exact[$0] - Double(counts[$0]) > exact[$1] - Double(counts[$1]) }
    for i in order.prefix(totalSeats - counts.reduce(0, +)) { counts[i] += 1 }

    var spots: [(angle: Double, r: Double)] = []
    for (r, n) in zip(radii, counts) {
        for k in 0..<n {
            // π·(n−1)/(n−1) kan avrundas till en hårsmån över π (sin < 0); klampa så att inget säte hamnar under golvet.
            let angle = n == 1 ? Double.pi / 2 : min(Double.pi, max(0, Double.pi * Double(n - 1 - k) / Double(n - 1)))
            spots.append((angle, r))
        }
    }
    spots.sort { $0.angle != $1.angle ? $0.angle > $1.angle : $0.r < $1.r }

    var seats: [Seat] = []
    var next = 0
    for p in leftToRight {
        for _ in 0..<p.seats {
            let s = spots[next]
            seats.append(Seat(party: p, x: s.r * cos(s.angle), y: s.r * sin(s.angle), angle: s.angle))
            next += 1
        }
    }
    return seats
}

public struct PartyLink: Equatable, Sendable {
    public let party: P
    public let label: String
    public let isNew: Bool
}

/// Ett partis relationer i klartext, grupperade efter sort. Ordningen följer vänster till höger.
public struct PartyRelations: Sendable {
    public let attraction: [PartyLink]
    public let negotiating: [PartyLink]
    public let conflict: [PartyLink]
    /// Partier utan någon tydlig relation till det valda partiet.
    public let none: [P]
    /// Relationer som senaste rubriken tog bort.
    public let removed: [PartyLink]
}

public func partyRelations(_ p: P, after h: Int) -> PartyRelations {
    func other(_ r: KeyRelation) -> P { r.pair.a == p ? r.pair.b : r.pair.a }
    func links(_ rs: [KeyRelation]) -> [PartyLink] {
        rs.filter { $0.pair.a == p || $0.pair.b == p }
            .map { PartyLink(party: other($0), label: $0.label, isNew: $0.isNew) }
            .sorted { leftToRight.firstIndex(of: $0.party)! < leftToRight.firstIndex(of: $1.party)! }
    }
    let current = keyRelations(after: h)
    func kind(_ k: RelationKind) -> [PartyLink] { links(current.filter { $0.kind == k }) }
    let related = Set(links(current).map(\.party))
    return PartyRelations(
        attraction: kind(.attraction),
        negotiating: kind(.negotiating),
        conflict: kind(.conflict),
        none: leftToRight.filter { $0 != p && !related.contains($0) },
        removed: links(removedRelations(after: h)))
}
