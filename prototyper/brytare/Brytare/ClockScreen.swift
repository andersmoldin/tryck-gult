import SwiftUI
import BrytareModell

/// Utseende per spel (game-art-direction: en palett per spel).
struct ClockTheme {
    let background: Color
    let card: Color
    let cardText: Color
    let border: Color
    let accent: Color
    let hardShadow: Bool

    static func of(_ title: String) -> ClockTheme {
        if title == "Nyhetsknuten" {   // Löpsedel: gult, svart kontur, hård skugga, lila = påhitt
            return ClockTheme(background: Color(white: 0.09), card: Color(red: 1, green: 0.84, blue: 0),
                              cardText: .black, border: .black, accent: Color(red: 1, green: 0.84, blue: 0), hardShadow: true)
        }
        if title == "Systemknuten" {   // Förhandlingsbordet: mörk filt, mässing, lila stämplar
            return ClockTheme(background: Color(red: 0.11, green: 0.21, blue: 0.16), card: Color(red: 0.96, green: 0.95, blue: 0.91),
                              cardText: .black, border: Color(red: 0.79, green: 0.64, blue: 0.15), accent: Color(red: 0.79, green: 0.64, blue: 0.15), hardShadow: false)
        }
        return ClockTheme(background: .black, card: Color(white: 0.14), cardText: .white, border: Color(white: 0.3), accent: .yellow, hardShadow: false)
    }
}

/// Skärmen för spelen där dagarna går: fasta zoner uppifrån och ned –
/// resurser och dag, mätaren, små aviseringar, huvudkortet (nyhet eller effekt), handlingarna.
struct ClockScreen<G: ClockGame>: View {
    @State private var game: G
    private let initial: G
    @State private var running = true
    @State private var showTips = false
    @State private var showBoard = false
    @State private var presses = 0
    @AppStorage private var tipsSeen: Bool
    /// Sekunder per dag (inställning Spelhastighet).
    @AppStorage("clock.secondsPerDay") private var secondsPerDay = 3.5
    /// Dagar tur för tur: klockan står still tills spelaren avslutar dagen.
    @AppStorage("clock.turnBased") private var turnBased = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(game: G) {
        _game = State(initialValue: game)
        initial = game
        _tipsSeen = AppStorage(wrappedValue: false, "tipsSeen.\(game.title)")
    }

    private var theme: ClockTheme { ClockTheme.of(game.title) }
    private var motion: Animation? { reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.65) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hud
                if !game.bars.isEmpty { BarsView(bars: game.bars, theme: theme) }
                notices
                mainCard
                actions
                if !game.relations.isEmpty {
                    DisclosureGroup(isExpanded: $showBoard) {
                        GraphView(relations: game.relations).frame(height: 300)
                        EmojiLegend()
                    } label: {
                        Text("Visa bordet (partiernas trådar)").font(.subheadline.weight(.semibold))
                    }
                    .tint(theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !turnBased {
                    Button { running.toggle() } label: { Image(systemName: running ? "pause.circle" : "play.circle") }
                        .accessibilityLabel(running ? "Pausa klockan" : "Starta klockan")
                }
                Button { showTips = true } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("Så spelar du")
            }
        }
        .onAppear { if !tipsSeen { showTips = true } }
        .sheet(isPresented: $showTips, onDismiss: { tipsSeen = true }) { tips }
        .overlay { if let e = game.ending { endingView(e).transition(.opacity) } }
        .animation(motion, value: game.paused)
        .animation(motion, value: game.bars)
        .animation(.easeInOut(duration: 0.3), value: game.notices)
        .animation(.easeInOut(duration: 0.25), value: game.ending)
        .sensoryFeedback(.impact(weight: .medium), trigger: presses)
        .sensoryFeedback(.warning, trigger: game.paused)
        .task {
            // Klockan: en dag i taget när ingen nyhet visas, spelet pågår, appen är aktiv och dagarna rullar.
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(secondsPerDay)) } catch { return }
                if !turnBased && running && !showTips && scenePhase == .active && game.paused == nil && game.ending == nil {
                    withAnimation(motion) { game.tick(days: 1) }
                }
            }
        }
    }

    // MARK: Zon 1: resurser och dag

    private var hud: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let figure = game.figure {
                    Image(figure).resizable().scaledToFit().frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                }
                ForEach(game.meters, id: \.name) { m in
                    VStack(spacing: 1) {
                        if m.name == "Lampor" { LampRow(value: m.value) } else {
                            Text(m.value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.white)
                        }
                        Text(m.name).font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                    .accessibilityElement(children: .combine)
                }
            }
            ProgressView(value: Double(game.day), total: Double(max(game.day, lastDay)))
                .tint(theme.accent)
                .accessibilityLabel("Dag \(game.day)")
            ForEach(game.meters.compactMap { m in m.caption.map { "\(m.name): \($0)" } }, id: \.self) { line in
                Text(line).font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            if turnBased {
                Text("Tur för tur: dagen går först när du trycker Avsluta dagen.").font(.caption).foregroundStyle(theme.accent)
            } else if !running {
                Text("Klockan står still – tryck ▶︎ för att fortsätta.").font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: Zon 3: små aviseringar (stoppar inte tiden)

    @ViewBuilder private var notices: some View {
        let recent = Array(game.notices.suffix(3))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(recent.enumerated()), id: \.offset) { i, n in
                    HStack(alignment: .top, spacing: 6) {
                        Text(n.kind == .rumor ? "RYKTE" : n.kind == .whatIf ? "TÄNK OM" : "NOTIS")
                            .font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(n.kind == .info ? Color.gray : Color.purple).foregroundStyle(.white)
                        Text(n.text).font(.caption).foregroundStyle(.white.opacity(i == recent.count - 1 ? 1 : 0.6))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        }
    }

    // MARK: Zon 4: huvudkortet

    @ViewBuilder private var mainCard: some View {
        if let news = game.paused {
            newsCard(news).transition(.scale(scale: 0.95).combined(with: .opacity))
        } else if let e = game.effect {
            EffectBox(effect: e)
        }
    }

    private func newsCard(_ n: NewsItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(n.kind == .real ? (n.tag == .locks ? "I VERKLIGHETEN · GÅVA" : "I VERKLIGHETEN") : n.kind == .anonymous ? "ENLIGT UPPGIFTER" : "RYKTE · påhittat")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(n.kind == .real ? Color.red : n.kind == .anonymous ? Color.gray : Color.purple).foregroundStyle(.white)
                Text(dateText(day: n.day)).font(.caption.bold()).foregroundStyle(theme.cardText)
                Spacer()
                Label("Tiden står still", systemImage: "pause.fill").font(.caption2).foregroundStyle(theme.cardText.opacity(0.7))
            }
            Text(n.title).font(.title3.bold()).foregroundStyle(theme.cardText)
                .fixedSize(horizontal: false, vertical: true)
            if n.kind != .rumor {
                Text("Källa: " + n.source).font(.caption).foregroundStyle(theme.cardText.opacity(0.7))
            }
            if game.newsChoices.isEmpty {
                primaryButton("Fortsätt") { game.resume() }
            } else {
                ForEach(game.newsChoices) { c in choiceButton(c, onCard: true) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(theme.card)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 2))
            .shadow(color: theme.hardShadow ? .black : .clear, radius: 0, x: 4, y: 4)
    }

    // MARK: Zon 5: handlingarna (under tummen)

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if game.paused == nil && game.ending == nil {
                ForEach(game.cards) { c in choiceButton(c, onCard: false) }
                if game.cards.isEmpty {
                    Text(turnBased ? "Inget att göra i dag." : "Inget att göra just nu. Dagarna går.")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                if turnBased {
                    primaryButton("Avsluta dagen") { game.tick(days: 1) }
                }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            presses += 1
            withAnimation(motion) { action() }
        } label: {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.accent)
        .foregroundStyle(.black)
    }

    private func choiceButton(_ c: Choice, onCard: Bool) -> some View {
        Button {
            presses += 1
            withAnimation(motion) { game.play(c.id) }
        } label: {
            HStack(spacing: 10) {
                if let icon = c.icon {
                    Image(icon).resizable().scaledToFit().frame(width: 52, height: 52).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.title).font(.headline).foregroundStyle(c.icon == nil ? Color.white : Color.purple)
                    if let preview = c.preview {
                        Text(preview).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(c.quip).font(.caption).italic().foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: onCard ? 0.12 : 0.16)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Hjälp och slut

    private var tips: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Så spelar du").font(.title2.bold())
                ForEach(Array(game.tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.headline).foregroundStyle(theme.accent)
                        Text(tip)
                    }
                }
                Text("Varje knapp visar vad den gör innan du trycker. Rykten och TÄNK OM kommer som små notiser och stoppar inte tiden.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { showTips = false } label: {
                    Text("Uppfattat").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(.black)
            }
            .padding(24)
        }
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
    var theme: ClockTheme = .of("")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(bars, id: \.label) { bar in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(bar.label + (bar.isLeading ? "  · leder" : "")).font(.subheadline.weight(bar.isLeading ? .heavy : .regular)).foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(bar.value))" + (bar.max == 100 ? " %" : " av \(Int(bar.marks.first ?? bar.max))"))
                            .font(.subheadline.monospacedDigit().weight(bar.isLeading ? .heavy : .regular)).foregroundStyle(.white)
                    }
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.15))
                            Rectangle().fill(theme.accent.opacity(0.3))
                                .frame(width: w * CGFloat(min(bar.ghost, bar.max) / bar.max))
                            Rectangle().fill(bar.isLeading ? theme.accent : theme.accent.opacity(0.55))
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
                    .frame(height: bar.isLeading ? 22 : 14)
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
