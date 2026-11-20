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
    /// `.standard` för de små graferna, `.wide` för talmannens stora nätverk där partierna ska stå långt isär.
    public enum Style: Sendable { case standard, wide }

    /// Krafterna. Enheterna är rutan [-1, 1] × [-1, 1].
    private struct Forces {
        var repulsion: Double
        var allyLength: Double
        var allyStrength: Double
        var negotiatingLength: Double
        var negotiatingStrength: Double
        var conflictLength: Double
        var conflictStrength: Double
        var gravity: Double
        /// Knuffar partier bort från mitten av linjer de inte hör till (där emojin sitter).
        var midpointRepulsion: Double
        var damping = 0.85
    }

    public private(set) var positions: [P: Point]
    private var velocities: [P: Point]
    private let forces: Forces

    /// Partierna börjar i en båge från vänster till höger.
    public init(style: Style = .standard) {
        switch style {
        case .standard:
            forces = Forces(repulsion: 0.03, allyLength: 0.4, allyStrength: 4, negotiatingLength: 0.7,
                            negotiatingStrength: 1.5, conflictLength: 1.3, conflictStrength: 2, gravity: 0.6,
                            midpointRepulsion: 0)
        case .wide:
            forces = Forces(repulsion: 0.09, allyLength: 0.6, allyStrength: 3, negotiatingLength: 0.85,
                            negotiatingStrength: 1.5, conflictLength: 1.5, conflictStrength: 2, gravity: 0.35,
                            midpointRepulsion: 0.02)
        }
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

    /// En liten knuff utåt och runt, så att det syns att något ändrades.
    public mutating func nudge() {
        for p in P.allCases {
            let pos = positions[p]!
            velocities[p]!.x += 0.04 * pos.x - 0.03 * pos.y
            velocities[p]!.y += 0.04 * pos.y + 0.03 * pos.x
        }
    }

    /// Ett steg i simuleringen.
    public mutating func step(_ relations: [KeyRelation], dt: Double = 1.0 / 60) {
        let f = forces
        let kinds = Dictionary(uniqueKeysWithValues: relations.map { ($0.pair, $0.kind) })
        var force = positions.mapValues { _ in Point(x: 0, y: 0) }
        let parties = P.allCases
        func push(_ p: P, _ fx: Double, _ fy: Double) { force[p]!.x += fx; force[p]!.y += fy }
        for i in parties.indices {
            for j in parties.indices where j > i {
                let a = parties[i], b = parties[j]
                let pa = positions[a]!, pb = positions[b]!
                var dx = pb.x - pa.x, dy = pb.y - pa.y
                var d = (dx * dx + dy * dy).squareRoot()
                if d < 0.01 { dx = 0.01; dy = 0; d = 0.01 }
                var pull = -f.repulsion / (d * d)        // positivt = dras ihop
                switch kinds[Pair(a, b)] {
                case .attraction?: pull += f.allyStrength * (d - f.allyLength)
                case .negotiating?: pull += f.negotiatingStrength * (d - f.negotiatingLength)
                case .conflict?: pull += f.conflictStrength * min(0, d - f.conflictLength)
                case nil: break
                }
                push(a, pull * dx / d, pull * dy / d)
                push(b, -pull * dx / d, -pull * dy / d)
            }
        }
        if f.midpointRepulsion > 0 {
            for line in relations {
                let a = positions[line.pair.a]!, b = positions[line.pair.b]!
                let m = Point(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                for p in parties where p != line.pair.a && p != line.pair.b {
                    let pos = positions[p]!
                    var dx = pos.x - m.x, dy = pos.y - m.y
                    var d = (dx * dx + dy * dy).squareRoot()
                    if d < 0.01 { dx = 0.01; dy = 0; d = 0.01 }
                    let away = f.midpointRepulsion / (d * d)
                    push(p, away * dx / d, away * dy / d)
                    // Linjens ändar får motkraften, så att hela linjen flyttar sig.
                    push(line.pair.a, -away * dx / d / 2, -away * dy / d / 2)
                    push(line.pair.b, -away * dx / d / 2, -away * dy / d / 2)
                }
            }
        }
        for p in parties {
            var v = velocities[p]!
            var pos = positions[p]!
            v.x = (v.x + (force[p]!.x - f.gravity * pos.x) * dt) * f.damping
            v.y = (v.y + (force[p]!.y - f.gravity * pos.y) * dt) * f.damping
            pos.x = min(1, max(-1, pos.x + v.x))
            pos.y = min(1, max(-1, pos.y + v.y))
            velocities[p] = v
            positions[p] = pos
        }
    }
}
