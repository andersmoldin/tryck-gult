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

    public func distance(to o: Point) -> Double { ((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y)).squareRoot() }
    /// Punkten en andel `t` av vägen härifrån mot `o`.
    public func toward(_ o: Point, _ t: Double) -> Point { Point(x: x + (o.x - x) * t, y: y + (o.y - y) * t) }
}

/// Storlekarna i talmannens nätverk, i grafens enheter (rutan [-1, 1]). Appen ritar med samma tal,
/// så testerna av att inget överlappar gäller det som syns på skärmen.
public enum WideGraphMetrics {
    public static func nodeRadius(_ p: P) -> Double { 0.085 + Double(p.seats).squareRoot() * 0.008 }
    /// Radien på emojins bakgrundsskiva.
    public static let emojiRadius = 0.1
    /// Minsta luft mellan två saker.
    public static let margin = 0.02
}

/// Var emojin på varje linje ska sitta: så nära mitten som möjligt, men flyttad längs linjen
/// om den annars skulle krocka med ett parti eller en annan emoji.
public func emojiPositions(_ layout: GraphLayout, _ lines: [KeyRelation]) -> [Pair: Point] {
    typealias M = WideGraphMetrics
    // Mitten först, sedan växelvis utåt mot ändarna.
    let candidates = [0.5] + stride(from: 0.04, through: 0.3, by: 0.04).flatMap { [0.5 - $0, 0.5 + $0] }
    var placed: [Pair: Point] = [:]
    func clearance(_ e: Point) -> Double {
        let nodes = P.allCases.map { e.distance(to: layout.positions[$0]!) - M.nodeRadius($0) - M.emojiRadius }
        let emojis = placed.values.map { e.distance(to: $0) - 2 * M.emojiRadius }
        return (nodes + emojis).min() ?? .infinity
    }
    // Korta linjer har minst utrymme att flytta emojin på, så de får välja först.
    for line in lines.sorted(by: { layout.distance($0.pair.a, $0.pair.b) < layout.distance($1.pair.a, $1.pair.b) }) {
        let a = layout.positions[line.pair.a]!, b = layout.positions[line.pair.b]!
        let spots = candidates.map { a.toward(b, $0) }
        placed[line.pair] = spots.first { clearance($0) >= M.margin } ?? spots.max { clearance($0) < clearance($1) }!
    }
    return placed
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
        /// Knuffar partier bort från linjer de inte hör till (där emojin sitter), så att ingen nod ligger på en linje.
        var lineRepulsion: Double
        /// Håll hela noden (med radie) inom ramen, inte bara mittpunkten.
        var keepDiscInside = false
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
                            lineRepulsion: 0)
        case .wide:
            forces = Forces(repulsion: 0.09, allyLength: 0.6, allyStrength: 3, negotiatingLength: 0.85,
                            negotiatingStrength: 1.5, conflictLength: 1.5, conflictStrength: 2, gravity: 0.35,
                            lineRepulsion: 0.02, keepDiscInside: true)
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
        if f.lineRepulsion > 0 {
            for line in relations {
                let a = positions[line.pair.a]!, b = positions[line.pair.b]!
                let abx = b.x - a.x, aby = b.y - a.y
                let len2 = max(abx * abx + aby * aby, 1e-6)
                for p in parties where p != line.pair.a && p != line.pair.b {
                    let pos = positions[p]!
                    // Närmaste punkt på linjen.
                    let t = min(1, max(0, ((pos.x - a.x) * abx + (pos.y - a.y) * aby) / len2))
                    let q = a.toward(b, t)
                    var dx = pos.x - q.x, dy = pos.y - q.y
                    var d = (dx * dx + dy * dy).squareRoot()
                    if d < 0.01 { dx = -aby; dy = abx; d = max((dx * dx + dy * dy).squareRoot(), 1e-6) }
                    let away = f.lineRepulsion / max(d * d, 0.0025)
                    push(p, away * dx / d, away * dy / d)
                    // Linjens ändar får motkraften i proportion till var på linjen trycket sitter.
                    push(line.pair.a, -away * dx / d * (1 - t), -away * dy / d * (1 - t))
                    push(line.pair.b, -away * dx / d * t, -away * dy / d * t)
                }
            }
        }
        for p in parties {
            var v = velocities[p]!
            var pos = positions[p]!
            v.x = (v.x + (force[p]!.x - f.gravity * pos.x) * dt) * f.damping
            v.y = (v.y + (force[p]!.y - f.gravity * pos.y) * dt) * f.damping
            let limit = f.keepDiscInside ? 1 - WideGraphMetrics.nodeRadius(p) : 1
            pos.x = min(limit, max(-limit, pos.x + v.x))
            pos.y = min(limit, max(-limit, pos.y + v.y))
            velocities[p] = v
            positions[p] = pos
        }
    }
}
