import SwiftUI
import BrytareModell

/// Talmannens nätverk. Partier som samarbetar dras ihop och får ett moln runt sig; röda linjer knuffar isär.
/// En emoji sitter på varje linje i stället för text. Storlekarna kommer från `WideGraphMetrics`,
/// så testerna av att inget överlappar gäller det som ritas.
struct GraphView: View {
    let relations: [KeyRelation]
    @State private var sim = Simulation()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                sim.advance(to: timeline.date, lines: relations)
                draw(in: &ctx, size: size, time: timeline.date)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07)))
        .accessibilityLabel("Nätverk över partiernas relationer")
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Date) {
        let pad: CGFloat = 8
        let unit = (min(size.width, size.height) - 2 * pad) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func point(_ p: Point) -> CGPoint { CGPoint(x: center.x + CGFloat(p.x) * unit, y: center.y + CGFloat(p.y) * unit) }
        let layout = sim.layout

        // Molnen: en puff runt varje parti i blocket och puffar mellan grannarna, mjukt andande.
        // När ett parti glider in eller ut ur ett block puffar molnet till.
        let t = time.timeIntervalSinceReferenceDate
        let bump = max(0, 1 - time.timeIntervalSince(sim.blocksChangedAt) / 0.9)
        for block in clusters(relations) {
            var cloud = Path()
            for (i, p) in block.enumerated() {
                let c = point(layout.positions[p]!)
                let breathe = 1 + 0.03 * sin(t * 1.6 + Double(i)) + 0.18 * bump
                let r = (CGFloat(WideGraphMetrics.nodeRadius(p)) + 0.16) * unit * CGFloat(breathe)
                cloud.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                for q in block.dropFirst(i + 1) {
                    let m = point(layout.positions[p]!.toward(layout.positions[q]!, 0.5))
                    let rm = 0.17 * unit * CGFloat(breathe)
                    cloud.addEllipse(in: CGRect(x: m.x - rm, y: m.y - rm, width: 2 * rm, height: 2 * rm))
                }
            }
            ctx.fill(cloud, with: .color(Color(red: 0.75, green: 0.85, blue: 1).opacity(0.16)))
        }

        for line in relations {
            var path = Path()
            path.move(to: point(layout.positions[line.pair.a]!))
            path.addLine(to: point(layout.positions[line.pair.b]!))
            let color: Color = line.kind == .conflict ? .red : (line.kind == .negotiating ? .yellow : .white)
            ctx.stroke(path, with: .color(color.opacity(0.8)), lineWidth: line.isNew ? 5 : 2.5)
        }
        let emojiR = CGFloat(WideGraphMetrics.emojiRadius) * unit
        for (pair, spot) in emojiPositions(layout, relations) {
            guard let line = relations.first(where: { $0.pair == pair }) else { continue }
            let c = point(spot)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - emojiR, y: c.y - emojiR, width: 2 * emojiR, height: 2 * emojiR)),
                     with: .color(line.isNew ? Color.orange.opacity(0.35) : Color(white: 0.12)))
            ctx.draw(Text(line.kind.emoji).font(.system(size: emojiR * 1.25)), at: c)
        }
        for p in P.allCases {
            let c = point(layout.positions[p]!)
            let r = CGFloat(WideGraphMetrics.nodeRadius(p)) * unit
            let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(disc, with: .color(p.color))
            ctx.stroke(disc, with: .color(.black), lineWidth: 1.5)
            ctx.draw(Text(p.rawValue).font(.system(size: r * 0.62, weight: .heavy)).foregroundStyle(p.textColor), at: c)
        }
    }

    /// Håller layouten mellan bildrutorna. Ingen observerad state: den ändras medan Canvas ritar.
    final class Simulation {
        var layout = GraphLayout()
        private(set) var blocksChangedAt = Date.distantPast
        private var last: Date?
        private var lastLines: [KeyRelation]?

        func advance(to now: Date, lines: [KeyRelation]) {
            if let previous = lastLines, previous != lines {
                // "Hoppa till": när linjerna ändras får noderna en knuff innan de lägger sig.
                layout.nudge()
                if clusters(previous) != clusters(lines) { blocksChangedAt = now }
            }
            lastLines = lines
            let elapsed = min(now.timeIntervalSince(last ?? now), 0.1)
            last = now
            for _ in 0..<Int((elapsed * 60).rounded()) { layout.step(lines) }
        }
    }
}

extension RelationKind {
    /// Emojin på linjen.
    var emoji: String {
        switch self {
        case .attraction: return "🤝"
        case .negotiating: return "💬"
        case .conflict: return "✋"
        }
    }
}

/// Teckenförklaring (radbryts vid behov).
struct EmojiLegend: View {
    var body: some View {
        Flow(spacing: 12) {
            Text("☁️ block")
            Text("\(RelationKind.attraction.emoji) samarbete")
            Text("\(RelationKind.negotiating.emoji) förhandlar")
            Text("\(RelationKind.conflict.emoji) röd linje")
            Text("tjock linje, orange ring = nytt").foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
