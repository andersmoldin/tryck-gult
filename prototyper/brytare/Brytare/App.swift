import SwiftUI
import BrytareModell

// PROTOTYP för ärende #4: talmannen. Slängkod – inte produktionskod.
// Spellogiken ligger i paketet BrytareModell; appen visar den.

@main
struct ProvbankApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { SpeakerScreen() }
                .preferredColorScheme(.dark)
        }
    }
}
