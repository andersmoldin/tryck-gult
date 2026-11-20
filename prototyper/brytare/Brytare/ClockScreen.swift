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
                if let news = game.world.paused {
                    newsCard(news).transition(.scale.combined(with: .opacity))
                } else {
                    play
                }
                GraphView(relations: game.world.relations)
                    .frame(height: 320)
                EmojiLegend()
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
        .animation(.easeInOut(duration: 0.3), value: game.world.paused)
        .animation(.easeInOut(duration: 0.25), value: game.ending)
        .task {
            // Klockan: en dag i taget så länge ingen nyhet visas, spelet pågår och starthjälpen är stängd.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(secondsPerDay)) } catch { return }
                if running && !showTips && game.world.paused == nil && game.ending == nil {
                    withAnimation(.easeInOut(duration: 0.3)) { game.tick(days: 1) }
                }
            }
        }
    }

    private var meters: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
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
                Text(n.kind == .real ? "I VERKLIGHETEN" : "RYKTE")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(n.kind == .real ? Color.red : Color.purple).foregroundStyle(.white)
                Text(dateText(day: n.day)).font(.caption.bold())
                Spacer()
                Text("Tiden står still").font(.caption2).foregroundStyle(.secondary)
            }
            Text(n.title).font(.title3.bold())
            if n.kind == .real {
                Text("Källa: " + n.source).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Spelets påhitt.").font(.caption2).foregroundStyle(.purple)
            }
            if !n.changes.isEmpty {
                Text("Nätverket har ändrats.").font(.caption).foregroundStyle(.secondary)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { game.resume() }
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
    }

    private var play: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let e = game.effect { EffectBox(effect: e) }
            ForEach(game.cards) { c in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { game.play(c.id) }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.title).font(.subheadline.bold()).foregroundStyle(.white)
                        Text(c.quip).font(.caption).italic().foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.18)))
                }
                .buttonStyle(.plain)
            }
            if game.cards.isEmpty && game.ending == nil {
                Text("Inget att göra just nu. Dagarna går.").font(.caption).foregroundStyle(.secondary)
            }
        }
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
