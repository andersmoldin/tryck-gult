import Foundation

// Nätverksgrafen: partierna är noder, linjerna visar dragning eller konflikt.
// Layouten är en enkel kraftsimulering som appen stegar varje bildruta.

public enum Relation: Sendable { case attraction, conflict }

/// Linjerna i grafen efter h rubriker. Par som saknas har ingen linje.
public func relations(after h: Int) -> [Pair: Relation] {
    var rules = startRules()
    for i in 0..<min(h, headlines.count) { headlines[i].apply(&rules) }
    var result: [Pair: Relation] = [:]
    for pair in rules.allies { result[pair] = .attraction }
    for pair in rules.pairs { result[pair] = .conflict }   // konflikt väger tyngre
    return result
}

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
}

public struct GraphLayout: Sendable {
    public private(set) var positions: [P: Point]
    private var velocities: [P: Point]

    // Krafterna. Enheterna är rutan [-1, 1] × [-1, 1].
    private static let repulsion = 0.02
    private static let allyLength = 0.35
    private static let allyStrength = 4.0
    private static let conflictLength = 1.2
    private static let conflictStrength = 2.0
    private static let gravity = 0.6
    private static let damping = 0.85

    /// Partierna börjar i en ring från vänster till höger.
    public init() {
        var pos: [P: Point] = [:]
        for (i, p) in leftToRight.enumerated() {
            let angle = Double.pi - Double(i) * Double.pi / Double(leftToRight.count - 1)
            pos[p] = Point(x: 0.7 * cos(angle), y: 0.7 * sin(angle) - 0.2)
        }
        positions = pos
        velocities = Dictionary(uniqueKeysWithValues: P.allCases.map { ($0, Point(x: 0, y: 0)) })
    }

    public func distance(_ a: P, _ b: P) -> Double {
        let pa = positions[a]!, pb = positions[b]!
        return ((pa.x - pb.x) * (pa.x - pb.x) + (pa.y - pb.y) * (pa.y - pb.y)).squareRoot()
    }

    /// Ett steg i simuleringen.
    public mutating func step(_ relations: [Pair: Relation], dt: Double = 1.0 / 60) {
        var force = Dictionary(uniqueKeysWithValues: P.allCases.map { ($0, Point(x: 0, y: 0)) })
        let parties = P.allCases
        for i in parties.indices {
            for j in parties.indices where j > i {
                let a = parties[i], b = parties[j]
                let pa = positions[a]!, pb = positions[b]!
                var dx = pb.x - pa.x, dy = pb.y - pa.y
                var d = (dx * dx + dy * dy).squareRoot()
                if d < 0.01 { dx = 0.01; dy = 0; d = 0.01 }
                var f = -Self.repulsion / (d * d)        // positivt = dras ihop
                switch relations[Pair(a, b)] {
                case .attraction?: f += Self.allyStrength * (d - Self.allyLength)
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
