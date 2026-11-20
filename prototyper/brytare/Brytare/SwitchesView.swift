import SwiftUI
import BrytareModell

// PROTOTYP – brytare per partikrav (fastgood.cheap).
// Slår du på ett krav slås krav som krockar av av sig själva.

struct SwitchesView: View {
    let game: GameController

    var body: some View {
        VStack(spacing: 4) {
            ForEach(bySeats) { p in
                SwitchRow(game: game, p: p)
            }
            Spacer(minLength: 0)
        }
    }
}

struct SwitchRow: View {
    let game: GameController
    let p: P
    @State private var shakes: CGFloat = 0
    @State private var flash = false
    @State private var kickedBy: String = ""

    var body: some View {
        let on = game.backing.contains(p)
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(p.color)
                Text(p.rawValue).font(.caption.weight(.heavy)).foregroundStyle(p.textColor)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(p.info.name) · \(p.seats)").font(.footnote.bold()).lineLimit(1)
                Text(flash ? kickedBy : (game.rules.demand[p] ?? ""))
                    .font(.caption)
                    .foregroundStyle(flash ? Color.red : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            VoteLamp(vote: game.vote(of: p))
            Toggle("", isOn: Binding(get: { on }, set: { _ in game.toggle(p) }))
                .labelsHidden()
                .tint(p.color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(flash ? Color.red.opacity(0.3) : Color(white: 0.13)))
        .modifier(Shake(animatableData: shakes))
        .onChange(of: game.kick.serial) { _, _ in
            guard game.kick.parties.contains(p) else { return }
            kickedBy = game.kick.by.map { "✕ Slogs av när \($0.rawValue) slogs på" } ?? "✕ Hoppade av efter rubriken"
            withAnimation(.linear(duration: 0.45)) { shakes += 1 }
            withAnimation(.easeOut(duration: 0.15)) { flash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.3)) { flash = false }
            }
        }
    }
}
