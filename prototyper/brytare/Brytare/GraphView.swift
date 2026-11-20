import SwiftUI
import BrytareModell

/// Kraftriktad graf över partierna med några få nyckelrelationer.
/// Vit = dragning, gul streckad = förhandlar, röd = konflikt. Tjockare linje = ändrades av senaste rubriken.
struct GraphView: View {
    enum Mode {
        /// Liten graf i de andra perspektiven.
        case compact
        /// Helskärm med etiketter.
        case detail
        /// Talmannens stora nätverk: partierna långt isär och en emoji på varje linje i stället för text.
        case emojis
    }

    let headlineIndex: Int
    let mode: Mode
    @State private var sim: Simulation

    init(headlineIndex: Int, mode: Mode = .compact) {
        self.headlineIndex = headlineIndex
        self.mode = mode
        _sim = State(initialValue: Simulation(style: mode == .emojis ? .wide : .standard, nudgesOnChange: mode == .emojis))
    }

    private var showLabels: Bool { mode == .detail }

    var body: some View {
        let lines = keyRelations(after: headlineIndex)
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                sim.advance(to: timeline.date, lines: lines)
                draw(in: &ctx, size: size, lines: lines)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07)))
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, lines: [KeyRelation]) {
        if mode == .emojis {
            drawEmojiNetwork(in: &ctx, size: size, lines: lines)
            return
        }
        let pad: CGFloat = showLabels ? 44 : 28
        func point(_ p: P) -> CGPoint {
            let pos = sim.layout.positions[p]!
            return CGPoint(x: pad + (CGFloat(pos.x) + 1) / 2 * (size.width - 2 * pad),
                           y: pad + (CGFloat(pos.y) + 1) / 2 * (size.height - 2 * pad))
        }
        for line in lines {
            var path = Path()
            path.move(to: point(line.pair.a))
            path.addLine(to: point(line.pair.b))
            let width: CGFloat = line.isNew ? 5 : 2.5
            switch line.kind {
            case .attraction:
                ctx.stroke(path, with: .color(.white.opacity(0.75)), lineWidth: width)
            case .negotiating:
                ctx.stroke(path, with: .color(.yellow), style: StrokeStyle(lineWidth: width, dash: [6, 5]))
            case .conflict:
                ctx.stroke(path, with: .color(.red), lineWidth: width)
            }
        }
        if showLabels {
            for line in lines {
                let a = point(line.pair.a), b = point(line.pair.b)
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let text = Text(line.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                let resolved = ctx.resolve(text)
                let s = resolved.measure(in: CGSize(width: 140, height: 40))
                let box = CGRect(x: mid.x - s.width / 2 - 4, y: mid.y - s.height / 2 - 2, width: s.width + 8, height: s.height + 4)
                ctx.fill(Path(roundedRect: box, cornerRadius: 4), with: .color(.black.opacity(0.8)))
                ctx.draw(resolved, in: box.insetBy(dx: 4, dy: 2))
            }
        }
        for p in P.allCases {
            let c = point(p)
            let r = (showLabels ? 14 : 10) + CGFloat(p.seats).squareRoot() * (showLabels ? 2.0 : 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(p.color))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(.black), lineWidth: 1.5)
            ctx.draw(Text(p.rawValue).font(.system(size: showLabels ? 15 : 12, weight: .heavy)).foregroundStyle(p.textColor), at: c)
        }
    }

    /// Håller layouten mellan bildrutorna. Ingen observerad state: den ändras medan Canvas ritar.
    /// Talmannens nätverk. Storlekarna kommer från `WideGraphMetrics` i en jämn skala,
    /// så att testerna av att inget överlappar gäller det som ritas.
    private func drawEmojiNetwork(in ctx: inout GraphicsContext, size: CGSize, lines: [KeyRelation]) {
        let pad: CGFloat = 8
        let unit = (min(size.width, size.height) - 2 * pad) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func point(_ p: Point) -> CGPoint { CGPoint(x: center.x + CGFloat(p.x) * unit, y: center.y + CGFloat(p.y) * unit) }
        let layout = sim.layout
        for line in lines {
            var path = Path()
            path.move(to: point(layout.positions[line.pair.a]!))
            path.addLine(to: point(layout.positions[line.pair.b]!))
            let color: Color = line.kind == .conflict ? .red : (line.kind == .negotiating ? .yellow : .white)
            ctx.stroke(path, with: .color(color.opacity(0.8)), lineWidth: line.isNew ? 5 : 2.5)
        }
        let emojiR = CGFloat(WideGraphMetrics.emojiRadius) * unit
        for (pair, spot) in emojiPositions(layout, lines) {
            guard let line = lines.first(where: { $0.pair == pair }) else { continue }
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

    final class Simulation {
        var layout: GraphLayout
        private let nudgesOnChange: Bool
        private var last: Date?
        private var lastLines: [KeyRelation]?

        init(style: GraphLayout.Style, nudgesOnChange: Bool) {
            layout = GraphLayout(style: style)
            self.nudgesOnChange = nudgesOnChange
        }

        func advance(to now: Date, lines: [KeyRelation]) {
            // "Hoppa till": när en rubrik ändrar linjerna får noderna en knuff innan de lägger sig.
            if nudgesOnChange, let previous = lastLines, previous != lines { layout.nudge() }
            lastLines = lines
            let elapsed = min(now.timeIntervalSince(last ?? now), 0.1)
            last = now
            for _ in 0..<Int((elapsed * 60).rounded()) { layout.step(lines) }
        }
    }
}

extension RelationKind {
    /// Emojin mitt på linjen i talmannens nätverk.
    var emoji: String {
        switch self {
        case .attraction: return "🤝"
        case .negotiating: return "💬"
        case .conflict: return "✋"
        }
    }
}

/// Teckenförklaring för emojinätverket (radbryts vid behov).
struct EmojiLegend: View {
    var body: some View {
        Flow(spacing: 12) {
            Text("\(RelationKind.attraction.emoji) samarbete")
            Text("\(RelationKind.negotiating.emoji) förhandlar")
            Text("\(RelationKind.conflict.emoji) röd linje")
            Text("tjock linje, orange ring = nytt").foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

/// Teckenförklaring i en rad.
struct GraphLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            swatch(.white.opacity(0.75), "dragning")
            swatch(.yellow, "förhandlar", dashed: true)
            swatch(.red, "konflikt")
            Text("tjock = nytt").foregroundStyle(.secondary)
            Spacer()
            Text("Tryck för att förstora").foregroundStyle(.secondary)
        }
        .font(.system(size: 10))
    }

    private func swatch(_ color: Color, _ label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1.5)); p.addLine(to: CGPoint(x: 14, y: 1.5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [3, 2] : []))
                .frame(width: 14, height: 3)
            Text(label)
        }
    }
}

/// Helskärm: stor graf med etiketter och en läsbar lista över relationerna.
struct GraphDetailView: View {
    let headlineIndex: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Läget efter: \(headline(after: headlineIndex).title)")
                        .font(.footnote).foregroundStyle(.secondary)
                    GraphView(headlineIndex: headlineIndex, mode: .detail)
                        .frame(height: 420)
                    ForEach(keyRelations(after: headlineIndex), id: \.pair) { r in
                        row(r, removed: false)
                    }
                    ForEach(removedRelations(after: headlineIndex), id: \.pair) { r in
                        row(r, removed: true)
                    }
                }
                .padding(14)
            }
            .navigationTitle("Partiernas relationer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Stäng") { dismiss() } }
        }
    }

    private func row(_ r: KeyRelation, removed: Bool) -> some View {
        let (symbol, color): (String, Color) = {
            switch r.kind {
            case .attraction: return ("↔", .white)
            case .negotiating: return ("⋯", .yellow)
            case .conflict: return ("✕", .red)
            }
        }()
        return HStack(spacing: 8) {
            Text("\(r.pair.a.rawValue) \(symbol) \(r.pair.b.rawValue)")
                .font(.subheadline.bold().monospaced())
                .foregroundStyle(color)
                .frame(width: 84, alignment: .leading)
            Text(r.label).font(.subheadline).strikethrough(removed)
            Spacer()
            if removed {
                Text("BORTA").font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.gray).foregroundStyle(.black)
            } else if r.isNew {
                Text("NYTT").font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.orange).foregroundStyle(.black)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.12)))
    }
}
