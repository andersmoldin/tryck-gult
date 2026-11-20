import SwiftUI
import BrytareModell

/// Kraftriktad graf över partierna. Ljusa linjer = dragning, röda = konflikt.
/// Layouten stegas varje bildruta, så noderna glider när en rubrik ändrar linjerna.
struct GraphView: View {
    let headlineIndex: Int
    @State private var sim = Simulation()

    var body: some View {
        let lines = relations(after: headlineIndex)
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                sim.advance(to: timeline.date, lines: lines)
                draw(in: &ctx, size: size, lines: lines)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07)))
        .overlay(alignment: .bottomLeading) { legend.padding(8) }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            Label("dragning", systemImage: "line.diagonal").foregroundStyle(.white.opacity(0.7))
            Label("konflikt", systemImage: "line.diagonal").foregroundStyle(.red)
        }
        .font(.system(size: 10))
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, lines: [Pair: Relation]) {
        let pad: CGFloat = 30
        func point(_ p: P) -> CGPoint {
            let pos = sim.layout.positions[p]!
            return CGPoint(x: pad + (CGFloat(pos.x) + 1) / 2 * (size.width - 2 * pad),
                           y: pad + (CGFloat(pos.y) + 1) / 2 * (size.height - 2 * pad))
        }
        for (pair, kind) in lines {
            var path = Path()
            path.move(to: point(pair.a))
            path.addLine(to: point(pair.b))
            switch kind {
            case .attraction:
                ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 3)
            case .conflict:
                ctx.stroke(path, with: .color(.red.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        for p in P.allCases {
            let c = point(p)
            let r = 9 + CGFloat(p.seats).squareRoot() * 1.6
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(p.color))
            ctx.draw(Text(p.rawValue).font(.system(size: 11, weight: .heavy)).foregroundStyle(p.textColor), at: c)
        }
    }

    /// Håller layouten mellan bildrutorna. Ingen observerad state: den ändras medan Canvas ritar.
    final class Simulation {
        var layout = GraphLayout()
        private var last: Date?

        func advance(to now: Date, lines: [Pair: Relation]) {
            let elapsed = min(now.timeIntervalSince(last ?? now), 0.1)
            last = now
            for _ in 0..<Int((elapsed * 60).rounded()) { layout.step(lines) }
        }
    }
}
