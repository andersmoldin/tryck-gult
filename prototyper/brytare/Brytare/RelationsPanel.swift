import SwiftUI
import BrytareModell

/// Talmannens relationspanel: tre sätt att visa partiernas samband, att växla mellan.
/// Ingen text på linjer; tryck på ett parti eller en ruta för att läsa klartext under.
struct RelationsPanel: View {
    let headlineIndex: Int
    @AppStorage("relationsView") private var mode: Mode = .hemicycle
    @State private var selected: P = .C

    enum Mode: String, CaseIterable, Identifiable {
        case hemicycle, matrix, party
        var id: String { rawValue }
        var title: String {
            switch self {
            case .hemicycle: return "Halvcirkel"
            case .matrix: return "Tabell"
            case .party: return "Ett parti"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Visa", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            switch mode {
            case .hemicycle:
                HemicycleView(headlineIndex: headlineIndex, selected: $selected)
                RelationLegend()
                PartyRelationsList(party: selected, headlineIndex: headlineIndex)
            case .matrix:
                MatrixView(headlineIndex: headlineIndex)
            case .party:
                PartyPicker(selected: $selected)
                PartyRelationsList(party: selected, headlineIndex: headlineIndex)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.07)))
    }
}

extension RelationKind {
    var color: Color {
        switch self {
        case .attraction: return .white
        case .negotiating: return .yellow
        case .conflict: return .red
        }
    }
    var symbol: String {
        switch self {
        case .attraction: return "●"
        case .negotiating: return "⋯"
        case .conflict: return "✕"
        }
    }
}

// MARK: Halvcirkel

struct HemicycleView: View {
    let headlineIndex: Int
    @Binding var selected: P
    private let seats = hemicycleSeats()

    /// Var halvcirkeln ligger i en given storlek.
    private struct Frame {
        let center: CGPoint
        let radius: CGFloat
        init(_ size: CGSize) {
            center = CGPoint(x: size.width / 2, y: size.height - 8)
            radius = min(size.width / 2 - 26, size.height - 30)
        }
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: center.x + CGFloat(x) * radius, y: center.y - CGFloat(y) * radius)
        }
        /// Omvänt: en punkt på skärmen i halvcirkelns enheter.
        func unit(_ p: CGPoint) -> (x: Double, y: Double) {
            (Double((p.x - center.x) / radius), Double((center.y - p.y) / radius))
        }
    }

    var body: some View {
        let lines = keyRelations(after: headlineIndex)
        GeometryReader { geo in
            let frame = Frame(geo.size)
            Canvas { ctx, _ in draw(in: &ctx, frame: frame, lines: lines) }
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap in
                    // Välj partiet för sätet närmast trycket (inte närmaste medelvinkel, som slår fel vid kanterna).
                    let u = frame.unit(tap.location)
                    func d(_ s: Seat) -> Double { (s.x - u.x) * (s.x - u.x) + (s.y - u.y) * (s.y - u.y) }
                    if let seat = seats.min(by: { d($0) < d($1) }) { selected = seat.party }
                })
        }
        .frame(height: 190)
        .overlay(alignment: .topLeading) {
            Text("Tryck på ett parti").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func draw(in ctx: inout GraphicsContext, frame: Frame, lines: [KeyRelation]) {
        // Relationerna som bågar genom den tomma mitten.
        for line in lines {
            let a = anchor(line.pair.a), b = anchor(line.pair.b)
            var path = Path()
            path.move(to: frame.point(a.x, a.y))
            path.addQuadCurve(to: frame.point(b.x, b.y), control: frame.point((a.x + b.x) / 4, 0.02))
            let involved = line.pair.a == selected || line.pair.b == selected
            let width: CGFloat = (line.isNew ? 4 : 2) + (involved ? 1.5 : 0)
            let dash: [CGFloat] = line.kind == .negotiating ? [5, 4] : []
            ctx.stroke(path, with: .color(line.kind.color.opacity(involved ? 1 : 0.25)),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
        }
        // Sätena.
        for s in seats {
            let p = frame.point(s.x, s.y)
            let r: CGFloat = 2.6
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(s.party.color.opacity(s.party == selected ? 1 : 0.7)))
        }
        // Partinamn utanför bågen.
        for p in P.allCases {
            let a = meanAngle(p)
            let text = Text(p.rawValue).font(.system(size: 12, weight: p == selected ? .heavy : .semibold))
                .foregroundStyle(p == selected ? Color.yellow : Color.white)
            ctx.draw(text, at: frame.point(1.13 * cos(a), 1.13 * sin(a)))
        }
    }

    private func meanAngle(_ p: P) -> Double {
        let mine = seats.filter { $0.party == p }
        return mine.map(\.angle).reduce(0, +) / Double(mine.count)
    }

    /// Där partiets bågar börjar: innerkanten av dess sektor.
    private func anchor(_ p: P) -> (x: Double, y: Double) {
        let a = meanAngle(p)
        return (0.36 * cos(a), 0.36 * sin(a))
    }
}

// MARK: Tabell

struct MatrixView: View {
    let headlineIndex: Int
    /// Rutan spelaren tryckte på, i rad- och kolumnordning.
    @State private var picked: (row: P, col: P)?

    var body: some View {
        let lines = Dictionary(uniqueKeysWithValues: keyRelations(after: headlineIndex).map { ($0.pair, $0) })
        VStack(alignment: .leading, spacing: 8) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    Color.clear.frame(width: 30, height: 24)
                    ForEach(leftToRight) { p in PartyChip(party: p, small: true) }
                }
                ForEach(leftToRight) { row in
                    GridRow {
                        PartyChip(party: row, small: true)
                        ForEach(leftToRight) { col in
                            cell(row: row, col: col, line: row == col ? nil : lines[Pair(row, col)])
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                ForEach([RelationKind.attraction, .negotiating, .conflict], id: \.self) { k in
                    Text("\(k.symbol) \(k.legend)").foregroundStyle(k.color)
                }
                Text("orange ram = nytt").foregroundStyle(.orange)
            }
            .font(.caption2)
            if let (row, col) = picked {
                if let line = lines[Pair(row, col)] {
                    Text("\(row.rawValue) \(line.kind.symbol) \(col.rawValue): \(line.label)")
                        .font(.subheadline).foregroundStyle(line.kind.color)
                } else {
                    Text("\(row.rawValue) och \(col.rawValue): ingen tydlig relation.").font(.subheadline)
                }
            } else {
                Text("Tryck på en ruta för att läsa vad den betyder.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func cell(row: P, col: P, line: KeyRelation?) -> some View {
        let isPicked = picked.map { $0.row == row && $0.col == col } ?? false
        return Button {
            if row != col { picked = (row, col) }
        } label: {
            Text(line?.kind.symbol ?? "")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(line?.kind.color ?? .clear)
                .frame(width: 34, height: 30)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(row == col ? Color(white: 0.04) : Color(white: isPicked ? 0.3 : 0.15)))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(line?.isNew == true ? Color.orange : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(row == col)
    }
}

extension RelationKind {
    var legend: String {
        switch self {
        case .attraction: return "drar åt"
        case .negotiating: return "förhandlar"
        case .conflict: return "krockar"
        }
    }
}

/// Teckenförklaring för bågarna i halvcirkeln.
struct RelationLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            swatch(.white, "drar åt")
            swatch(.yellow, "förhandlar", dashed: true)
            swatch(.red, "krockar")
            Text("tjock = nytt").foregroundStyle(.secondary)
        }
        .font(.caption2)
    }

    private func swatch(_ color: Color, _ label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            Path { p in p.move(to: CGPoint(x: 0, y: 1.5)); p.addLine(to: CGPoint(x: 16, y: 1.5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [3, 2] : []))
                .frame(width: 16, height: 3)
            Text(label)
        }
    }
}

// MARK: Ett parti

struct PartyChip: View {
    let party: P
    var small = false
    var selected = false

    var body: some View {
        Text(party.rawValue)
            .font(.system(size: small ? 11 : 14, weight: .heavy))
            .foregroundStyle(party.textColor)
            .frame(width: small ? 34 : 38, height: small ? 24 : 32)
            .background(RoundedRectangle(cornerRadius: 6).fill(party.color))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.yellow : .clear, lineWidth: 3))
    }
}

struct PartyPicker: View {
    @Binding var selected: P

    var body: some View {
        HStack(spacing: 4) {
            ForEach(leftToRight) { p in
                Button { selected = p } label: { PartyChip(party: p, selected: p == selected) }
                    .buttonStyle(.plain)
            }
        }
    }
}

/// Ett partis relationer i klartext.
struct PartyRelationsList: View {
    let party: P
    let headlineIndex: Int

    var body: some View {
        let r = partyRelations(party, after: headlineIndex)
        VStack(alignment: .leading, spacing: 6) {
            Text(party.info.name).font(.headline)
            group("Drar åt", r.attraction, .attraction)
            group("Förhandlar med", r.negotiating, .negotiating)
            group("Krockar med", r.conflict, .conflict)
            if !r.none.isEmpty {
                Text("Ingen tydlig relation: " + r.none.map(\.rawValue).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(r.removed, id: \.party) { link in
                HStack(spacing: 6) {
                    Text("BORTA").font(.caption2.weight(.heavy)).padding(.horizontal, 4)
                        .background(Color.gray).foregroundStyle(.black)
                    Text("\(link.party.rawValue): \(link.label)").strikethrough().font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func group(_ title: String, _ links: [PartyLink], _ kind: RelationKind) -> some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(kind.symbol) \(title)").font(.caption.weight(.heavy)).foregroundStyle(kind.color)
                ForEach(links, id: \.party) { link in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(link.party.rawValue).font(.subheadline.bold()).frame(width: 28, alignment: .leading)
                        Text(link.label).font(.subheadline)
                        if link.isNew {
                            Text("NYTT").font(.caption2.weight(.heavy)).padding(.horizontal, 4)
                                .background(Color.orange).foregroundStyle(.black)
                        }
                    }
                }
            }
        }
    }
}
