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
    @AppStorage("nk.leakWhileRunning") private var leakWhileRunning = true
    @AppStorage("nk.anonymousSources") private var anonymousSources = true
    @AppStorage("nk.finale") private var finale = true
    @AppStorage("sk.hardLinesCanFall") private var hardLinesCanFall = false
    @AppStorage("clock.secondsPerDay") private var secondsPerDay = 3.5
    @AppStorage("clock.turnBased") private var turnBased = false

    private var newsSettings: NewsKnotSettings {
        var s = NewsKnotSettings()
        s.rumors = rumorMode
        s.leakWhileRunning = leakWhileRunning
        s.anonymousSources = anonymousSources
        s.finale = finale
        return s
    }
    @State private var helpReset = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ClockScreen(game: NewsKnotGame(settings: newsSettings))
                } label: {
                    entry("Nyhetsknuten", "Du är knuten. Nyheterna stoppar tiden – reagera, läck i rätt tid, vinn på extraval.")
                }
                NavigationLink {
                    ClockScreen(game: SystemKnotGame(seed: UInt64.random(in: 0...UInt64.max), hardLinesCanFall: hardLinesCanFall))
                } label: {
                    entry("Systemknuten", "Partierna förhandlar av sig själva. Stoppa Ribban med tre stämplar.")
                }
            } header: {
                Text("Omgång 8 – två knutar")
            }
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
                Picker("Dagar", selection: $turnBased) {
                    Text("Rullar av sig själva").tag(false)
                    Text("Tur för tur").tag(true)
                }
                Picker("Spelhastighet", selection: $secondsPerDay) {
                    Text("Lugn (5 s/dag)").tag(5.0)
                    Text("Normal (3,5 s/dag)").tag(3.5)
                    Text("Snabb (2 s/dag)").tag(2.0)
                }
                Picker("Rykten", selection: $rumorMode) {
                    Text("Bara mina drag / föremål").tag(RumorMode.ownMovesOnly)
                    Text("Även påhittade partimöten").tag(RumorMode.alsoRealPartyMeetings)
                }
                Toggle("Nyhetsknuten: läcka medan tiden går", isOn: $leakWhileRunning)
                Toggle("Nyhetsknuten: ENLIGT UPPGIFTER-nyheter", isOn: $anonymousSources)
                Toggle("Nyhetsknuten: TÄNK OM-slutspurt efter 18 nov", isOn: $finale)
                Toggle("Systemknuten: hårda röda linjer kan falla", isOn: $hardLinesCanFall)
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
