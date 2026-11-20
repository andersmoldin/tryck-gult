import SwiftUI
import BrytareModell

// PROTOTYP – rubrik, 175-mätare, omröstning och extraval.

struct HeadlineBanner: View {
    let game: GameController
    @State private var pulse = false

    var body: some View {
        let h = game.headline
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(h.id == 0 ? "VALNATT" : "SENASTE NYTT")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.red).foregroundStyle(.white)
                Text(h.date).font(.caption.bold())
                Spacer()
                Text("Rubrik \(game.nextEvent) av \(headlines.count)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(h.title).font(.subheadline.bold()).lineLimit(2).minimumScaleFactor(0.8)
            Text(h.quote).font(.caption).italic().lineLimit(2).minimumScaleFactor(0.8)
            Text("→ " + h.effect).font(.caption.bold()).foregroundStyle(.orange).lineLimit(2).minimumScaleFactor(0.8)
            Text("Källa: " + h.source).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pulse ? Color.red : Color(white: 0.25), lineWidth: pulse ? 3 : 1))
        .scaleEffect(pulse ? 1.04 : 1)
        .onChange(of: game.headlineSerial) { _, _ in
            withAnimation(.easeOut(duration: 0.15)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.4)) { pulse = false }
            }
        }
    }
}

struct SeatGauge: View {
    let game: GameController

    var status: (String, Color) {
        if game.pendingEvent { return ("NÄRA! …något händer", .orange) }
        if game.wouldPass { return ("Skulle gå igenom: \(game.nejSeats) nej", .green) }
        if game.isNear { return ("Nära! \(game.nejSeats) nej – 175 fäller", .orange) }
        return ("Faller: \(game.nejSeats) nej – 175 fäller", .red)
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text("Stöd \(game.backingSeats)").bold()
                Text("(ja \(game.jaSeats) · gult \(game.gultSeats))").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(status.0).bold().foregroundStyle(status.1)
            }
            .font(.footnote.monospacedDigit())
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(white: 0.2))
                    HStack(spacing: 0) {
                        ForEach(leftToRight.filter { game.backing.contains($0) }) { p in
                            Rectangle().fill(p.color)
                                .frame(width: w * CGFloat(p.seats) / CGFloat(totalSeats))
                        }
                    }
                    Rectangle().fill(Color.white)
                        .frame(width: 3)
                        .offset(x: w * CGFloat(majority) / CGFloat(totalSeats) - 1.5)
                    Text("175")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3)
                        .background(Color.white)
                        .offset(x: w * CGFloat(majority) / CGFloat(totalSeats) + 2)
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(game.log.first ?? "Tryck på partierna. Uppfyll krav tills 175 trycker ja eller gult.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
    }
}

struct BottomBar: View {
    let game: GameController

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Talmannens försök").font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < game.attemptsLeft ? Color.white : Color.red.opacity(0.7))
                            .frame(width: 11, height: 11)
                    }
                }
            }
            Spacer()
            Button { game.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.bordered)
            Button { game.callVote() } label: {
                Text(game.pendingEvent ? "Rubrik på väg…" : "Rösta om statsminister")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .disabled(game.pendingEvent || game.locked)
        }
    }
}

struct VoteLamp: View {
    let vote: Vote
    var body: some View {
        let (label, color): (String, Color) = {
            switch vote {
            case .ja: return ("JA", .green)
            case .gult: return ("GULT", .yellow)
            case .nej: return ("NEJ", .red)
            }
        }()
        Text(label)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.black)
            .frame(width: 34, height: 18)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
    }
}

struct VoteOverlay: View {
    let result: VoteResult
    let attemptsLeft: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("STATSMINISTEROMRÖSTNING").font(.headline).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    box("JA", result.ja, .green)
                    box("GULT", result.gult, .yellow)
                    box("NEJ", result.nej, .red)
                }
                Text(result.passed ? "Går igenom!" : "FALLER – \(result.nej) nej (175 räcker)")
                    .font(.title3.bold())
                    .foregroundStyle(result.passed ? .green : .red)
                Text(attemptsLeft == 0 ? "Inga försök kvar." : "Talmannen har \(attemptsLeft) försök kvar")
                    .font(.subheadline)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.12)))
            .padding(20)
        }
    }

    func box(_ label: String, _ n: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.system(size: 34, weight: .heavy).monospacedDigit())
            Text(label).font(.caption.bold())
        }
        .foregroundStyle(.black)
        .frame(width: 84, height: 74)
        .background(RoundedRectangle(cornerRadius: 10).fill(color))
    }
}

struct ExtravalOverlay: View {
    let game: GameController

    var body: some View {
        ZStack {
            Color(red: 0.55, green: 0.02, blue: 0.05).opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("EXTRAVAL")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.yellow)
                Text("Fyra statsministeromröstningar har fallit.")
                    .font(.headline)
                Text("Historien gick inte att ändra – du misslyckades precis som partiledarna.")
                    .multilineTextAlignment(.center)
                Text("Senaste läget: \(game.nejSeats) nej. Det räckte med 175.")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                Button("Spela igen") { game.reset() }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            .padding(30)
        }
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 7
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 4), y: 0))
    }
}
