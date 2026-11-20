import SwiftUI
import BrytareModell

// PROTOTYP för ärende #4: provbänk med varianter. Slängkod – inte produktionskod.
// Spellogiken ligger i paketet BrytareModell; appen visar den.

@main
struct ProvbankApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack { MenuView() }
                .preferredColorScheme(.dark)
        }
    }
}

struct MenuView: View {
    @AppStorage("rumorMode") private var rumorMode: RumorMode = .ownMovesOnly
    @State private var helpReset = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ClockScreen(game: KnutenGame(rumors: rumorMode))
                } label: {
                    entry("Knuten", "Du är låsningen. Du vinner om det blir extraval.")
                }
                NavigationLink {
                    PartyPicker(rumorMode: rumorMode)
                } label: {
                    entry("Hamna i regering", "Välj ett parti och försök komma in i regeringen.")
                }
            } header: {
                Text("Omgång 7 – klockan går")
            } footer: {
                Text("Dagarna rullar från valdagen. När en nyhet kommer stannar tiden.")
            }
            Section("Från omgång 6") {
                NavigationLink { SpeakerScreen() } label: {
                    entry("Talmannen", "Veckor, förgrenade val och rykten.")
                }
            }
            Section {
                Picker("Rykten", selection: $rumorMode) {
                    Text("Bara om mina drag").tag(RumorMode.ownMovesOnly)
                    Text("Även påhittade partimöten").tag(RumorMode.alsoRealPartyMeetings)
                }
                Button("Visa starthjälpen igen") {
                    for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("tipsSeen.") {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    helpReset = true
                }
            } header: {
                Text("Inställningar")
            } footer: {
                Text(helpReset ? "Klart – hjälpen visas nästa gång du öppnar ett spel."
                     : "Alla rubriker i spelet är verkliga. Vi hittade inte på dem. Vi hade inte behövt. Ryktena hittade vi på.")
            }
        }
        .navigationTitle("Tryck gult!")
        .onAppear { helpReset = false }
    }

    private func entry(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct PartyPicker: View {
    let rumorMode: RumorMode

    var body: some View {
        List(leftToRight) { p in
            NavigationLink {
                ClockScreen(game: RegeringGame(party: p, rumors: rumorMode))
            } label: {
                HStack(spacing: 10) {
                    Text(p.rawValue).font(.system(size: 13, weight: .heavy)).foregroundStyle(p.textColor)
                        .frame(width: 36, height: 28).background(RoundedRectangle(cornerRadius: 6).fill(p.color))
                    Text("\(p.info.name) · \(p.seats) mandat")
                }
            }
        }
        .navigationTitle("Välj parti")
    }
}
