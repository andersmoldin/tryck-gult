import SwiftUI
import BrytareModell

/// Talmannen: mätare, ett kort i taget (situation, utfall eller rykte) och nätverket under.
struct SpeakerScreen: View {
    @State private var game = SpeakerGame()
    @State private var showTips = false
    @AppStorage("tipsSeen.Talmannen") private var tipsSeen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                meters
                card
                GraphView(relations: game.relations)
                    .frame(height: 360)
                EmojiLegend()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .navigationTitle("Talmannen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showTips = true } label: { Image(systemName: "questionmark.circle") }
                Menu {
                    Button("Visa starthjälpen igen") { tipsSeen = false; showTips = true }
                    Button("Börja om", role: .destructive) { withAnimation { game = SpeakerGame() } }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onAppear { if !tipsSeen { showTips = true } }
        .sheet(isPresented: $showTips, onDismiss: { tipsSeen = true }) { tips }
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
            ForEach(game.meters.compactMap { m in m.caption.map { "\(m.name): \($0)" } }, id: \.self) { line in
                Text(line).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var card: some View {
        switch game.phase {
        case .outcome:
            box {
                if let effect = game.effect { EffectBox(effect: effect) }
                if let outcome = game.outcome { Text(outcome) }
                proceedButton
            }
        case .rumor:
            box {
                Text("MEDAN DU VÄNTADE …").font(.caption.weight(.heavy)).foregroundStyle(.purple)
                HStack(spacing: 6) {
                    Text("RYKTE").font(.caption2.weight(.heavy))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.purple).foregroundStyle(.white)
                    Text("spelets påhitt").font(.caption2).foregroundStyle(.secondary)
                }
                Text(game.rumor?.text ?? "").font(.title3.bold())
                Text("Titta på nätverket – något har flyttat sig.").font(.caption).foregroundStyle(.secondary)
                proceedButton
            }
            .transition(.scale.combined(with: .opacity))
        case .choosing, .ended:
            VStack(alignment: .leading, spacing: 10) {
                headlineCard
                Text(game.question).font(.headline)
                ForEach(game.choices) { c in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { game.choose(c.id) }
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
            }
        }
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
    }

    private var proceedButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) { game.proceed() }
        } label: {
            Text("Fortsätt").font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow)
        .foregroundStyle(.black)
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
            Text(h.quote).font(.caption).italic()
            Text("Källa: " + h.source).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Så spelar du").font(.title2.bold())
            ForEach(Array(SpeakerGame.tips.enumerated()), id: \.offset) { i, tip in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)").font(.headline).foregroundStyle(.yellow)
                    Text(tip)
                }
            }
            Text("Nätverket: partier som samarbetar samlas i ett moln. \(RelationKind.attraction.emoji) samarbete, \(RelationKind.negotiating.emoji) förhandlar, \(RelationKind.conflict.emoji) röd linje. Tjock linje = nytt.")
                .font(.footnote).foregroundStyle(.secondary)
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
            (e.isExtraval ? Color(red: 0.55, green: 0.02, blue: 0.05) : Color(white: 0.08))
                .opacity(0.97).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(e.title)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                Text(e.text).multilineTextAlignment(.center)
                Button("Spela igen") { withAnimation { game = SpeakerGame() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
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
