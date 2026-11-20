import Foundation

// Nätverksgrafen: partierna är noder och några få nyckelrelationer är linjer med etikett.
// Layouten är en enkel kraftsimulering som appen stegar varje bildruta.

public enum RelationKind: Sendable { case attraction, negotiating, conflict }

public struct KeyRelation: Equatable, Sendable {
    public let pair: Pair
    public let kind: RelationKind
    public let label: String
    /// Linjen kom till eller ändrades med den senaste rubriken.
    public let isNew: Bool
}

/// Linjerna efter h rubriker. Bara det som behövs för att förstå läget, med en kort etikett.
public func keyRelations(after h: Int) -> [KeyRelation] {
    let now = relationState(after: h)
    let before = h > 0 ? relationState(after: h - 1) : now
    return now.map { pair, value in
        KeyRelation(pair: pair, kind: value.kind, label: value.label,
                    isNew: before[pair].map { $0 != value } ?? true)
    }
    .sorted { ($0.pair.a.rawValue, $0.pair.b.rawValue) < ($1.pair.a.rawValue, $1.pair.b.rawValue) }
}

/// Linjer som fanns före rubrik h men som rubriken tog bort.
public func removedRelations(after h: Int) -> [KeyRelation] {
    guard h > 0 else { return [] }
    let now = relationState(after: h)
    return relationState(after: h - 1)
        .filter { now[$0.key] == nil }
        .map { KeyRelation(pair: $0.key, kind: $0.value.kind, label: $0.value.label, isNew: true) }
        .sorted { ($0.pair.a.rawValue, $0.pair.b.rawValue) < ($1.pair.a.rawValue, $1.pair.b.rawValue) }
}

private struct RelationValue: Equatable {
    let kind: RelationKind
    let label: String
}

private func relationState(after h: Int) -> [Pair: RelationValue] {
    func v(_ kind: RelationKind, _ label: String) -> RelationValue { RelationValue(kind: kind, label: label) }
    var r: [Pair: RelationValue] = [
        Pair(.S, .V): v(.attraction, "Rödgröna – V vill ha ministrar"),
        Pair(.S, .MP): v(.attraction, "Rödgröna"),
        Pair(.S, .M): v(.conflict, "Två statsministerkandidater"),
        Pair(.M, .KD): v(.attraction, "Kristerssons sida"),
        Pair(.M, .L): v(.attraction, "Kristerssons sida"),
        Pair(.M, .SD): v(.attraction, "SD vill ha ministrar"),
        Pair(.V, .C): v(.conflict, "C: inget V i regeringen"),
        Pair(.SD, .C): v(.conflict, "C: inget SD-inflytande"),
        Pair(.SD, .L): v(.conflict, "L: inga SD-ministrar"),
    ]
    if h >= 1 {
        r[Pair(.SD, .L)] = nil
        r[Pair(.M, .SD)] = v(.attraction, "SD tolererar Kristersson")
    }
    if h >= 2 {
        r[Pair(.C, .S)] = v(.negotiating, "C vill ha totalpaket av S")
        r[Pair(.C, .M)] = v(.negotiating, "C vill ha totalpaket av M")
    }
    if h >= 3 {
        r[Pair(.S, .V)] = v(.conflict, "S: V utanför regeringen")
    }
    if h >= 4 {
        r[Pair(.C, .S)] = v(.attraction, "C valde S:s totalpaket")
        r[Pair(.C, .M)] = v(.conflict, "C valde bort Kristersson")
    }
    if h >= 5 {
        r[Pair(.S, .V)] = v(.conflict, "Två timmars möte: samma besked")
    }
    if h >= 6 {
        r[Pair(.V, .C)] = v(.conflict, "Låst – även inför extraval")
    }
    return r
}

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
}

public struct GraphLayout: Sendable {
    public private(set) var positions: [P: Point]
    private var velocities: [P: Point]

    // Krafterna. Enheterna är rutan [-1, 1] × [-1, 1].
    private static let repulsion = 0.03
    private static let allyLength = 0.4
    private static let allyStrength = 4.0
    private static let negotiatingLength = 0.7
    private static let negotiatingStrength = 1.5
    private static let conflictLength = 1.3
    private static let conflictStrength = 2.0
    private static let gravity = 0.6
    private static let damping = 0.85

    /// Partierna börjar i en båge från vänster till höger.
    public init() {
        var pos: [P: Point] = [:]
        for (i, p) in leftToRight.enumerated() {
            let angle = Double.pi - Double(i) * Double.pi / Double(leftToRight.count - 1)
            pos[p] = Point(x: 0.7 * cos(angle), y: 0.2 - 0.7 * sin(angle))
        }
        precondition(pos.count == P.allCases.count, "leftToRight måste innehålla alla partier")
        positions = pos
        velocities = pos.mapValues { _ in Point(x: 0, y: 0) }
    }

    public func distance(_ a: P, _ b: P) -> Double {
        let pa = positions[a]!, pb = positions[b]!
        return ((pa.x - pb.x) * (pa.x - pb.x) + (pa.y - pb.y) * (pa.y - pb.y)).squareRoot()
    }

    /// Ett steg i simuleringen.
    public mutating func step(_ relations: [KeyRelation], dt: Double = 1.0 / 60) {
        let kinds = Dictionary(uniqueKeysWithValues: relations.map { ($0.pair, $0.kind) })
        var force = positions.mapValues { _ in Point(x: 0, y: 0) }
        let parties = P.allCases
        for i in parties.indices {
            for j in parties.indices where j > i {
                let a = parties[i], b = parties[j]
                let pa = positions[a]!, pb = positions[b]!
                var dx = pb.x - pa.x, dy = pb.y - pa.y
                var d = (dx * dx + dy * dy).squareRoot()
                if d < 0.01 { dx = 0.01; dy = 0; d = 0.01 }
                var f = -Self.repulsion / (d * d)        // positivt = dras ihop
                switch kinds[Pair(a, b)] {
                case .attraction?: f += Self.allyStrength * (d - Self.allyLength)
                case .negotiating?: f += Self.negotiatingStrength * (d - Self.negotiatingLength)
                case .conflict?: f += Self.conflictStrength * min(0, d - Self.conflictLength)
                case nil: break
                }
                let fx = f * dx / d, fy = f * dy / d
                force[a]!.x += fx; force[a]!.y += fy
                force[b]!.x -= fx; force[b]!.y -= fy
            }
        }
        for p in parties {
            var v = velocities[p]!
            var pos = positions[p]!
            v.x = (v.x + (force[p]!.x - Self.gravity * pos.x) * dt) * Self.damping
            v.y = (v.y + (force[p]!.y - Self.gravity * pos.y) * dt) * Self.damping
            pos.x = min(1, max(-1, pos.x + v.x))
            pos.y = min(1, max(-1, pos.y + v.y))
            velocities[p] = v
            positions[p] = pos
        }
    }
}
