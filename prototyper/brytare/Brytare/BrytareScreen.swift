import SwiftUI

// Omgång 1: brytarvarianten, kvar i menyn som jämförelse.

struct BrytareScreen: View {
    @State private var game = GameController()

    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text("PROTOTYP · Tryck gult! · Brytare").font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("Läge: \(game.headline.date)").font(.caption2.bold())
            }
            HeadlineBanner(game: game)
            SeatGauge(game: game)
            SwitchesView(game: game)
                .frame(maxHeight: .infinity)
            BottomBar(game: game)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .overlay {
            if let r = game.lastVote {
                VoteOverlay(result: r, attemptsLeft: game.attemptsLeft).transition(.opacity)
            }
        }
        .overlay {
            if game.isExtraval {
                ExtravalOverlay(game: game).transition(.opacity)
            }
        }
    }
}
