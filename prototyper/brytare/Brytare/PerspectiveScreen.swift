import SwiftUI
import BrytareModell

/// En skärm för alla perspektivspel: mätare, graf, ett kort och 2–3 val.
struct PerspectiveScreen<G: PerspectiveGame>: View {
    @State private var game = G()
    @State private var showTips = false
    @AppStorage private var tipsSeen: Bool
    @Environment(\.dismiss) private var dismiss

    init() {
        _tipsSeen = AppStorage(wrappedValue: false, "tipsSeen.\(G.title)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                meters
                GraphView(headlineIndex: game.headlineIndex)
                    .frame(height: 220)
                card
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
        .overlay { if let e = game.ending { endingView(e).transition(.opacity) } }
        .animation(.easeInOut(duration: 0.25), value: game.ending)
    }

    private var meters: some View {
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
    }

    @ViewBuilder private var card: some View {
        if let outcome = game.outcome {
            VStack(alignment: .leading, spacing: 12) {
                Text("VAD HÄNDE").font(.caption.weight(.heavy)).foregroundStyle(.orange)
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
                            Text(c.title).font(.subheadline.bold()).foregroundStyle(.white)
                            Text(c.cost).font(.caption).foregroundStyle(.yellow)
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
            Text("Grafen: ljusa linjer drar ihop partier, röda linjer är konflikter. Den ändras när rubrikerna slår ner.")
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
            }
            .foregroundStyle(.white)
            .padding(30)
        }
    }
}
