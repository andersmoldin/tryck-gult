import SwiftUI
import BrytareModell

/// En skärm för alla perspektivspel: mätare, graf, ett kort och 2–3 val.
struct PerspectiveScreen<G: PerspectiveGame>: View {
    @State private var game = G()
    @State private var showTips = false
    @State private var showGraph = false
    @AppStorage private var tipsSeen: Bool
    @Environment(\.dismiss) private var dismiss

    init() {
        _tipsSeen = AppStorage(wrappedValue: false, tipsSeenKey(G.title))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                meters
                if G.self == SpeakerGame.self {
                    // Omgång 4: talmannen visar situationen först och relationerna under, i tre vyer.
                    card
                    RelationsPanel(headlineIndex: game.headlineIndex)
                } else {
                    Button { showGraph = true } label: {
                        VStack(spacing: 4) {
                            GraphView(headlineIndex: game.headlineIndex)
                                .frame(height: 200)
                            GraphLegend()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Partiernas relationer. Tryck för att förstora.")
                    card
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .navigationTitle(G.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showTips = true } label: { Image(systemName: "questionmark.circle") }
        }
        .onAppear { if !tipsSeen { showTips = true } }
        .sheet(isPresented: $showTips, onDismiss: { tipsSeen = true }) { tips }
        .fullScreenCover(isPresented: $showGraph) { GraphDetailView(headlineIndex: game.headlineIndex) }
        .overlay { if let e = game.ending { endingView(e).transition(.opacity) } }
        .animation(.easeInOut(duration: 0.25), value: game.ending)
    }

    private var meters: some View {
        VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
            ForEach(game.meters, id: \.name) { m in
                VStack(spacing: 1) {
                    Text(m.value).font(.subheadline.bold().monospacedDigit())
                    Text(m.name).font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.13)))
            }
        }
        ForEach(game.meters.filter { $0.caption != nil }, id: \.name) { m in
            Text("\(m.name): \(m.caption ?? "")").font(.caption2).foregroundStyle(.secondary)
        }
        }
    }

    @ViewBuilder private var card: some View {
        if let outcome = game.outcome {
            VStack(alignment: .leading, spacing: 12) {
                if let effect = game.effect {
                    EffectBox(effect: effect)
                } else {
                    Text("VAD HÄNDE").font(.caption.weight(.heavy)).foregroundStyle(.orange)
                }
                Text(outcome).font(.body)
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { game.proceed() }
                } label: {
                    Text("Fortsätt").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                headlineCard
                Text(game.question).font(.headline)
                ForEach(game.choices) { c in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { game.choose(c.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.quip == nil ? c.title : c.title.uppercased())
                                .font(.subheadline.bold()).foregroundStyle(.white)
                            if let quip = c.quip {
                                Text(quip).font(.caption).italic().foregroundStyle(.white.opacity(0.8))
                            }
                            if !G.hidesCosts {
                                Text(c.cost).font(.caption).foregroundStyle(.yellow)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var headlineCard: some View {
        let h = game.headline
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(h.id == 0 ? "VALNATT" : "I VERKLIGHETEN")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.red).foregroundStyle(.white)
                Text(h.date).font(.caption.bold())
                Spacer()
                Text("Rubrik \(game.headlineIndex) av \(timelineEnd)").font(.caption2).foregroundStyle(.secondary)
            }
            Text(h.title).font(.subheadline.bold())
            Text("→ " + h.effect).font(.caption).foregroundStyle(.orange)
            Text("Källa: " + h.source).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Så spelar du").font(.title2.bold())
            Text(G.role).font(.headline)
            ForEach(Array(G.tips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.headline).foregroundStyle(.yellow)
                    Text(tip)
                }
            }
            Text(G.self == SpeakerGame.self
                 ? "Relationerna: välj Halvcirkel, Tabell eller Ett parti och tryck för att läsa vad som drar åt och vad som krockar. Vad dina val kostar ser du först efteråt."
                 : "Grafen: vita linjer drar ihop partier, gula förhandlar, röda är konflikter. Tjock linje = ändrades av senaste rubriken. Tryck på grafen för att se den stor, med förklaringar.")
                .font(.footnote).foregroundStyle(.secondary)
            Button {
                showTips = false
            } label: {
                Text("Uppfattat").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
    }

    private func endingView(_ e: Ending) -> some View {
        ZStack {
            (e.isExtraval ? Color(red: 0.55, green: 0.02, blue: 0.05) : Color(white: 0.08))
                .opacity(0.97).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(e.title)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                Text(e.text).multilineTextAlignment(.center)
                Button("Spela igen") {
                    withAnimation { game = G() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                Button("Till menyn") { dismiss() }
                    .foregroundStyle(.white.opacity(0.8))
                if let footnote = e.footnote {
                    Text(footnote).font(.caption).italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .foregroundStyle(.white)
            .padding(30)
        }
    }
}

/// Rutan som visar vad ett val ledde till: stor rubrik och ändringarna en i taget.
struct EffectBox: View {
    let effect: Effect
    @State private var shown = 0

    private var color: Color {
        switch effect.tone {
        case .bad: return .red
        case .neutral: return .yellow
        case .good: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(effect.title)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(color)
                .scaleEffect(shown > 0 ? 1 : 0.4, anchor: .leading)
                .opacity(shown > 0 ? 1 : 0)
            FlowChips(chips: Array(effect.chips.prefix(max(0, shown - 1))), color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 2))
        .task(id: effect) {
            shown = 0
            for step in 1...(effect.chips.count + 1) {
                do { try await Task.sleep(for: .milliseconds(step == 1 ? 50 : 280)) } catch { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = step }
            }
        }
    }
}

/// Chips som radbryts när raden är full.
struct FlowChips: View {
    let chips: [String]
    let color: Color

    var body: some View {
        Flow(spacing: 6) {
            ForEach(chips, id: \.self) { chip in
            Text(chip)
                .font(.subheadline.bold().monospacedDigit())
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(color.opacity(0.3)))
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// En enkel flödeslayout: lägger barnen på rad och börjar en ny rad när bredden tar slut.
struct Flow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.map { $0.height }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(i)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

/// Nyckeln som minns att ett spels starthjälp har visats.
func tipsSeenKey(_ title: String) -> String { "tipsSeen.\(title)" }
