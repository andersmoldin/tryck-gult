import SwiftUI
import Observation
import BrytareModell

/// Kopplar spelmodellen till SwiftUI: animerar varje ändring och väntar ut de
/// `FollowUp` som modellen begär. Vyerna läser modellens värden rakt igenom (`game.backing` osv.).
@MainActor @Observable @dynamicMemberLookup
final class GameController {
    private(set) var state = Game()
    /// Ökar vid "Spela igen" så att väntande timers från förra omgången inte gör något.
    private var generation = 0

    subscript<T>(dynamicMember keyPath: KeyPath<Game, T>) -> T { state[keyPath: keyPath] }

    func vote(of p: P) -> Vote { state.vote(of: p) }

    func toggle(_ p: P) {
        let next = withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { state.toggle(p) }
        wait(for: next)
    }

    func callVote() {
        let next = withAnimation(.easeOut(duration: 0.25)) { state.callVote() }
        wait(for: next)
    }

    func reset() {
        generation += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { state.reset() }
    }

    private func wait(for followUp: FollowUp?) {
        guard let followUp else { return }
        let gen = generation
        let delay: Double
        switch followUp {
        case .headline(let after), .finishVote(let after): delay = after
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == gen else { return }
            let next: FollowUp?
            switch followUp {
            case .headline:
                next = withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { self.state.fireEvent() }
            case .finishVote:
                next = withAnimation(.easeInOut(duration: 0.3)) { self.state.finishVote() }
            }
            self.wait(for: next)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension P {
    var color: Color { Color(hex: info.color) }
    var textColor: Color { Color(hex: info.textColor) }
}
