import SwiftUI
import BrytareModell

/// Skärmen för varianterna där klockan går: mätare, nätverk, nyheter som stoppar tiden, och kort.
struct ClockScreen<G: ClockGame>: View {
    @State private var game: G
    /// Startläget, för "Spela igen".
    private let initial: G
    @State private var running = true
    @State private var showTips = false
    @AppStorage private var tipsSeen: Bool
    /// Sekunder per dag.
    private let secondsPerDay = 1.5

    init(game: G) {
        _game = State(initialValue: game)
        initial = game
        _tipsSeen = AppStorage(wrappedValue: false, "tipsSeen.\(game.title)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                meters
                if !game.bars.isEmpty { BarsView(bars: game.bars) }
                if let line = game.ticker {
                    Text(line).font(.caption.weight(.semibold))
                        .foregroundStyle(line.hasPrefix("TÄNK OM") || line.hasPrefix("RYKTE") ? Color.purple : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let news = game.paused {
                    newsCard(news).transition(.scale.combined(with: .opacity))
                } else {
                    play
                }
                if !game.relations.isEmpty {
                    GraphView(relations: game.relations)
                        .frame(height: 320)
                    EmojiLegend()
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { running.toggle() } label: { Image(systemName: running ? "pause.circle" : "play.circle") }
                Button { showTips = true } label: { Image(systemName: "questionmark.circle") }
            }
        }
        .onAppear { if !tipsSeen { showTips = true } }
        .sheet(isPresented: $showTips, onDismiss: { tipsSeen = true }) { tips }
        .overlay { if let e = game.ending { endingView(e).transition(.opacity) } }
        .animation(.easeInOut(duration: 0.3), value: game.paused)
        .animation(.easeInOut(duration: 0.25), value: game.ending)
        .task {
            // Klockan: en dag i taget så länge ingen nyhet visas, spelet pågår och starthjälpen är stängd.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(secondsPerDay)) } catch { return }
                if running && !showTips && game.paused == nil && game.ending == nil {
                    withAnimation(.easeInOut(duration: 0.3)) { game.tick(days: 1) }
                }
            }
        }
    }

    private var meters: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let figure = game.figure {
                    Image(figure).resizable().scaledToFit().frame(width: 48, height: 48)
                }
                ForEach(game.meters, id: \.name) { m in
                    VStack(spacing: 1) {
                        if m.name == "Lampor" {
                            LampRow(value: m.value)
                        } else {
                            Text(m.value).font(.subheadline.bold().monospacedDigit())
                        }
                        Text(m.name).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.13)))
                }
            }
            ForEach(game.meters.compactMap { m in m.caption.map { "\(m.name): \($0)" } }, id: \.self) { line in
                Text(line).font(.caption2).foregroundStyle(.secondary)
            }
            if !running {
                Text("Klockan står still – tryck ▶︎ för att fortsätta.").font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private func newsCard(_ n: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(n.kind == .real ? (n.tag == .locks ? "I VERKLIGHETEN · GÅVA" : "I VERKLIGHETEN") : n.kind == .anonymous ? "ENLIGT UPPGIFTER" : "RYKTE · påhittat")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(n.kind == .real ? Color.red : n.kind == .anonymous ? Color.gray : Color.purple).foregroundStyle(.white)
                Text(dateText(day: n.day)).font(.caption.bold())
                Spacer()
                Text("Tiden står still").font(.caption2).foregroundStyle(.secondary)
            }
            Text(n.title).font(.title3.bold())
            if n.kind == .rumor {
                Text("Spelets påhitt.").font(.caption2).foregroundStyle(.purple)
            } else {
                Text("Källa: " + n.source).font(.caption2).foregroundStyle(.secondary)
            }
            if !n.changes.isEmpty {
                Text("Nätverket har ändrats.").font(.caption).foregroundStyle(.secondary)
            }
            if game.newsChoices.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { game.resume() }
                } label: {
                    Text("Fortsätt").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
            } else {
                ForEach(game.newsChoices) { c in choiceButton(c) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
    }

    private var play: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let e = game.effect { EffectBox(effect: e) }
            ForEach(game.cards) { c in choiceButton(c) }
            if game.cards.isEmpty && game.ending == nil {
                Text("Inget att göra just nu. Dagarna går.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func choiceButton(_ c: Choice) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { game.play(c.id) }
        } label: {
            HStack(spacing: 10) {
                if let icon = c.icon {
                    Image(icon).resizable().scaledToFit().frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.title).font(.subheadline.bold()).foregroundStyle(c.icon == nil ? Color.white : Color.purple)
                    Text(c.quip).font(.caption).italic().foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.18)))
        }
        .buttonStyle(.plain)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Så spelar du").font(.title2.bold())
            ForEach(Array(game.tips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.headline).foregroundStyle(.yellow)
                    Text(tip)
                }
            }
            Button { showTips = false } label: {
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
            (e.isExtraval ? Color(red: 0.55, green: 0.02, blue: 0.05) : Color(red: 0.05, green: 0.2, blue: 0.1))
                .opacity(0.97).ignoresSafeArea()
            VStack(spacing: 16) {
                if e.isExtraval, game.figure != nil {
                    Image("knuten-triumf").resizable().scaledToFit().frame(width: 140, height: 140)
                }
                Text(e.title)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                Text(e.text).multilineTextAlignment(.center)
                Button("Spela igen") { withAnimation { game = initial; running = true } }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
                if let footnote = e.footnote {
                    Text(footnote).font(.caption).italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.white)
            .padding(30)
        }
    }
}

/// Vågräta staplar: Uppgörelsens spår eller Ribban, med zongränser.
struct BarsView: View {
    let bars: [Bar]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bars, id: \.label) { bar in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(bar.label).font(.caption.weight(bar.isLeading ? .heavy : .regular))
                        Spacer()
                        Text("\(Int(bar.value))" + (bar.max == 100 ? " %" : " av \(Int(bar.marks.first ?? bar.max))"))
                            .font(.caption.monospacedDigit().weight(bar.isLeading ? .heavy : .regular))
                    }
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.15))
                            Rectangle().fill(Color.yellow.opacity(0.3))
                                .frame(width: w * CGFloat(min(bar.ghost, bar.max) / bar.max))
                            Rectangle().fill(bar.isLeading ? Color.yellow : Color.yellow.opacity(0.55))
                                .frame(width: w * CGFloat(min(bar.value, bar.max) / bar.max))
                            ForEach(bar.marks, id: \.self) { m in
                                Rectangle().fill(m >= bar.max * 0.8 || bar.max > 100 ? Color.red : Color.orange)
                                    .frame(width: 2)
                                    .offset(x: w * CGFloat(m / bar.max) - 1)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1))
                    }
                    .frame(height: bar.isLeading ? 16 : 10)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: bars)
    }
}

/// Talmannens lampor som bilder (tänd/släckt), från ett värde som "●●○○".
struct LampRow: View {
    let value: String
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(value.enumerated()), id: \.offset) { _, ch in
                Image(ch == "●" ? "lampa-tand" : "lampa-slackt").resizable().scaledToFit().frame(width: 22, height: 22)
            }
        }
    }
}
