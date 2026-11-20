import SwiftUI
import BrytareModell

// PROTOTYP för ärende #4: provbänk med fyra perspektiv. Slängkod – inte produktionskod.
// Spellogiken ligger i paketet BrytareModell; appen visar den.

@main
struct ProvbankApp: App {
    var body: some Scene {
        WindowGroup {
            MenuView().preferredColorScheme(.dark)
        }
    }
}

struct MenuView: View {
    @State private var helpReset = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    entry(CandidateGame.self)
                    entry(SpeakerGame.self)
                    entry(KingmakerGame.self)
                    entry(CommentatorGame.self)
                } header: {
                    Text("Välj perspektiv")
                } footer: {
                    Text("Samma höst, samma rubriker – fyra sätt att spela den.\n\nAlla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt.")
                }
                Section {
                    Button("Visa starthjälpen igen") {
                        for title in [CandidateGame.title, SpeakerGame.title, KingmakerGame.title, CommentatorGame.title] {
                            UserDefaults.standard.removeObject(forKey: "tipsSeen.\(title)")
                        }
                        helpReset = true
                    }
                } footer: {
                    if helpReset { Text("Klart – hjälpen visas nästa gång du öppnar ett spel.") }
                }
                Section("Från omgång 1") {
                    NavigationLink {
                        BrytareScreen().navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brytare").font(.headline)
                            Text("Reglage per parti. Som jämförelse.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tryck gult!")
        }
    }

    private func entry<G: PerspectiveGame>(_ type: G.Type) -> some View {
        NavigationLink {
            PerspectiveScreen<G>()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(G.title).font(.headline)
                Text(G.role).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
