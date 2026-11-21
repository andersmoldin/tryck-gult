// Omgång 8: Nyhetsknuten (data/tg-knut-nyhet/report.md). Spelaren är knuten och vinner om det blir extraval.
// Dagarna rullar; när en nyhet kommer står tiden still och spelaren väljer en reaktion. Mätaren Uppgörelsen
// har tre spår (◀ Vänster, ● Mitten, ▶ Höger) från extraval till regering. Läckor läggs på dagar framåt.

public enum Lane: String, CaseIterable, Sendable {
    case left, center, right
    public var label: String {
        switch self {
        case .left: return "◀ Vänster"
        case .center: return "● Mitten"
        case .right: return "▶ Höger"
        }
    }
    public var short: String { String(label.dropFirst(2)) }
}

/// Kaptenens öppna frågor som inställningar (förval = rapportens rekommendation A).
public struct NewsKnotSettings: Equatable, Sendable {
    /// Fråga 3: A föremål/processer/namnlösa källor (`ownMovesOnly`), B även namngivna partimöten.
    public var rumors: RumorMode = .ownMovesOnly
    /// Fråga 2: läcka medan tiden rullar.
    public var leakWhileRunning = true
    /// Fråga 4: ta med nyheter från anonyma källor (ENLIGT UPPGIFTER).
    public var anonymousSources = true
    /// Fråga 1: TÄNK OM-slutspurt efter 18 nov (annars "Fortsättning följer").
    public var finale = true
    public init() {}
}

/// En nyhet i Nyhetsknuten: vad den gör med spåren och vilken torr rad reaktionen får.
public struct KnotNews: Equatable, Sendable {
    public let day: Int
    public let kind: NewsItem.Kind
    public let title: String
    public let source: String
    /// Gåva (låser): spelaren får spaltmeter.
    public let gift: Int
    public let deltas: [Lane: Double]
    /// Spåret nyheten mest handlar om (där Påminn siktar).
    public let target: Lane
    /// Kvickheten på Påminn-kortet.
    public let quip: String
    /// Står spåren still några dagar (anståndet).
    public let pause: Int
}

private func kn(_ day: Int, _ kind: NewsItem.Kind, _ title: String, _ source: String, gift: Int = 0,
                _ deltas: [Lane: Double], _ target: Lane, _ quip: String, pause: Int = 0) -> KnotNews {
    KnotNews(day: day, kind: kind, title: title, source: source, gift: gift, deltas: deltas, target: target, quip: quip, pause: pause)
}

private let knotNews: [KnotNews] = [
    kn(1, .real, "V kräver plats i en S-ledd regering. C släpper inte fram en regering där V ingår.", "Händelse #2, 14 sep", gift: 2,
       [.left: -5], .left, "Påminn alla om att 176 bara är en siffra."),
    kn(5, .real, "Andersson ringer alla partiledare utom Åkesson. L: ”behöver inte ringa mig”.", "Händelse #4, 18 sep", gift: 1,
       [.left: -4], .left, "Fråga vem som ringde vem först."),
    kn(15, .real, "V röstar på Norlén som talman. Andersson lämnar tillbaka sonderingsuppdraget.", "Händelse #5, 28 sep",
       [.left: 4, .right: 3], .right, "Påminn om att talmannen är M."),
    kn(19, .real, "Andersson får återuppta sonderingen, rapport senast 12 okt.", "Händelse #6, 2 okt",
       [.left: 6], .left, "Fråga om rapporten har en bilaga."),
    kn(32, .real, "C öppnar för en S-regering utan egna ministrar, om politiken är förankrad i mitten.", "Händelse #9, 15 okt",
       [.left: 8, .center: 6], .center, "Fråga vad ”förankrad” betyder i kronor."),
    kn(43, .real, "C: ”Det finns idag en majoritet för mittenpolitik, men ingen majoritet för en mittenregering.”", "Händelse #11, 26 okt", gift: 1,
       [.center: -6], .center, "Påminn om att majoritet och regering är olika saker."),
    kn(46, .real, "Talmannen föreslår Thand Ringqvist (C) för en regering av C, S, KD, MP och L.", "Händelse #12, 29 okt",
       [.center: 15], .center, "Räkna partierna högt i direktsändning."),
    kn(54, .real, "SD släpper kravet på ministerposter och tolererar Kristersson.", "Händelse #14, 6 nov",
       [.right: 18], .right, "Fråga vad ”tolerera” kostar per år."),
    kn(54, .real, "C ber Andersson och Kristersson om var sitt ”totalpaket” till fredag.", "Händelse #15, 6 nov",
       [.left: 5, .right: 5], .right, "Påminn om att fredag är en dag som alla andra."),
    kn(56, .real, "S: full opposition mot Tidö 2 – och vill regera med MP och C, V utanför.", "Händelse #17, #19, 8 nov", gift: 2,
       [.right: -10, .left: 6], .right, "Fråga vem som skrev ”full”."),
    kn(56, .real, "V: kravet på regeringsplats ”går inte att påverka”.", "Händelse #20, 8 nov", gift: 2,
       [.left: -8], .left, "Påminn om kongressen. Igen."),
    kn(58, .real, "MP: om det blir en stabil överenskommelse ”kommer vi att rösta ja”.", "Händelse #24, 10 nov",
       [.left: 10], .left, "Fråga om någon frågade MP."),
    kn(59, .anonymous, "Uppgifter: S försökte locka V med sakpolitik. V ska ha avvisat det som ”ett januariavtal”.", "ENLIGT UPPGIFTER – händelse #29, 12 nov",
       [.left: 6], .left, "Fråga vilken januari det gällde."),
    kn(60, .real, "V: ”Vårt kongressbeslut ligger ju fast.” ”Vi kommer ju aldrig att rösta på Ulf Kristersson.”", "Händelse #28, 12 nov", gift: 2,
       [.right: -4], .right, "Påminn om att ”aldrig” är ett långt ord."),
    kn(62, .anonymous, "Uppgifter: innehållet i S:s totalpaket läcker – 135 punkter.", "ENLIGT UPPGIFTER – händelse #31, 14–15 nov",
       [.left: 4], .left, "Fråga om punkt 136."),
    kn(63, .real, "C väljer S:s totalpaket.", "Händelse #32, 15 nov",
       [.left: 15, .right: -10], .left, "Fråga om paketet går att lämna tillbaka."),
    kn(64, .real, "S och V möts i två timmar. V: ”samma besked som tidigare”.", "Händelse #34, 16 nov", gift: 1,
       [.left: -6], .left, "Påminn om att två timmar är 120 minuter."),
    kn(65, .real, "Talmannen ger alla partiledare en veckas anstånd.", "Händelse #35, 17 nov",
       [:], .left, "Fråga vad en vecka är i politiska dagar.", pause: 3),
    kn(66, .real, "C: nej till V i regeringen – även för att undvika extraval.", "Händelse #37, 18 nov", gift: 3,
       [.left: -12], .left, "Påminn om att extraval också är ett alternativ."),
]

/// Rykten: A = föremål, processer och namnlösa källor; B lägger till påhittade möten mellan namngivna partier.
private let objectRumors: [KnotNews] = [
    kn(12, .rumor, "En kopiator i riksdagshuset har gått varm hela natten.", "", [.center: 3], .center, "Fråga vad som kopierades."),
    kn(24, .rumor, "En anonym källa: ”Det finns en plan B.” Ingen vet vad plan A var.", "", [.right: 4], .right, "Fråga efter plan C."),
    kn(39, .rumor, "Kaffeautomaten utanför talmannens rum är tom. Igen.", "", [.left: 1, .center: 1, .right: 1], .center, "Påminn om att kaffe är förhandlingsbart."),
    kn(48, .rumor, "Ett mejl med ämnesraden ”Utkast 7” har skickats till fel person.", "", [.left: 4], .left, "Fråga vad som stod i utkast 6."),
    kn(61, .rumor, "Någon har bokat riksdagens största sal i en vecka. Syftet är okänt.", "", [.center: 5], .center, "Fråga vem som har nyckeln."),
]
private let meetingRumorsKnot: [KnotNews] = [
    kn(18, .rumor, "C och S har setts äta lunch.", "", [.left: 4], .left, "Fråga vem som betalade."),
    kn(36, .rumor, "M och C pratade länge i korridoren.", "", [.right: 4], .right, "Fråga hur lång korridoren är."),
    kn(52, .rumor, "KD och C delade på en pizza efter voteringen.", "", [.right: 3], .right, "Fråga om pizzan hade totalpaket."),
]

public struct NewsKnotGame: ClockGame {
    public let title = "Nyhetsknuten"
    public let tips = [
        "Du är knuten. Du vinner om det blir extraval: alla fyra lampor släckta.",
        "Mätaren Uppgörelsen har tre spår – ◀ Vänster, ● Mitten, ▶ Höger – från extraval till regering. Samtalen fortsätter varje dag, så spåren kryper uppåt. Över 60 vässar talmannen pennan, över 85 blir en omröstning din förlust.",
        "När en nyhet kommer står tiden still. Välj en reaktion: Påminn, Följdfråga eller Inga kommentarer. Hur mycket den verkar ser du först efteråt. Gåvor – när partiledarna låser sig själva – ger spaltmeter.",
        "Mellan nyheterna kan du läcka till en dag framåt. Landar läckan på en deadline eller omröstningsdag slår den hårdare. Två läckor mot samma spår inom fem dagar dementeras.",
    ]

    public let settings: NewsKnotSettings
    public private(set) var day = 0
    public private(set) var lanes: [Lane: Double] = [.left: 20, .center: 10, .right: 25]
    public private(set) var spaltmeter = 3
    public private(set) var lamps = 4
    public private(set) var moves = 0
    public private(set) var gifts = 0
    public private(set) var effect: Effect?
    public private(set) var ending: Ending?
    public private(set) var ticker: String?
    private var current: KnotNews?
    private var queue: [KnotNews]
    private var stillUntil: [Lane: Int] = [:]
    private var leaks: [(day: Int, lane: Lane)] = []
    private var lastLeak: [Lane: Int] = [:]
    private var votes: [(day: Int, lane: Lane?, real: Bool)]

    static let spaltmeterCap = 9
    static let voteLine = 85.0
    static let finaleDays = [70, 74]

    public static func news(anonymous: Bool) -> [KnotNews] {
        knotNews.filter { anonymous || $0.kind != .anonymous }
    }

    public static func rumors(for mode: RumorMode) -> [KnotNews] {
        objectRumors + (mode == .alsoRealPartyMeetings ? meetingRumorsKnot : [])
    }

    public init(settings: NewsKnotSettings) {
        self.settings = settings
        queue = (Self.news(anonymous: settings.anonymousSources) + Self.rumors(for: settings.rumors))
            .enumerated().sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }.map(\.element)
        votes = [(32, .left, true), (51, .center, true)]
        if settings.finale { votes += Self.finaleDays.map { ($0, nil, false) } }
    }

    private var endDay: Int { settings.finale ? Self.finaleDays.last! : lastDay }

    /// Dagar då en läcka slår hårdare: omröstningar och kända deadlines.
    private var deadlineDays: Set<Int> { Set(votes.map(\.day) + [61, 65]) }

    public var paused: NewsItem? {
        current.map { NewsItem(day: $0.day, kind: $0.kind, title: $0.title, source: $0.source,
                               tag: $0.gift > 0 ? .locks : .none, changes: []) }
    }

    public var relations: [KeyRelation] { [] }
    public var figure: String? { "knuten-neutral" }

    public var leading: Lane { Lane.allCases.max { lanes[$0]! < lanes[$1]! }! }

    // MARK: Klockan

    public mutating func tick(days: Int) {
        for _ in 0..<days {
            guard ending == nil, current == nil else { return }
            if day >= endDay { finish(); return }
            day += 1
            daily()
            guard ending == nil else { return }
            landLeaks()
            runVotes()
            guard ending == nil else { return }
            if releaseNews() { return }
        }
    }

    public mutating func resume() {
        current = nil
        _ = releaseNews()
    }

    /// "Samtalen fortsätter": varje spår stiger, snabbare i senare akter.
    private func rate(_ lane: Lane) -> Double {
        let table: [(upTo: Int, rates: [Lane: Double])] = [
            (18, [.left: 0.6, .center: 0.3, .right: 0.6]),
            (32, [.left: 1.2, .center: 0.5, .right: 0.8]),
            (51, [.left: 0.6, .center: 1.3, .right: 0.9]),
            (63, [.left: 2.0, .center: 0.8, .right: 1.5]),
            (Int.max, [.left: 1.5, .center: 1.2, .right: 1.5]),
        ]
        return table.first { day <= $0.upTo }!.rates[lane]!
    }

    private mutating func daily() {
        if day % 4 == 0 { spaltmeter = min(Self.spaltmeterCap, spaltmeter + 1) }
        for lane in Lane.allCases where day > (stillUntil[lane] ?? -1) {
            lanes[lane] = min(100, lanes[lane]! + rate(lane))
        }
        checkGraddfil()
    }

    private mutating func move(_ lane: Lane, _ by: Double) {
        lanes[lane] = max(0, min(100, lanes[lane]! + by))
    }

    private mutating func checkGraddfil() {
        if let lane = Lane.allCases.first(where: { lanes[$0]! >= 100 }) { lose(lane, "\(lane.short) nådde 100 % – talmannen tog gräddfilen") }
    }

    private mutating func releaseNews() -> Bool {
        guard current == nil, let next = queue.first, next.day <= day else { return false }
        queue.removeFirst()
        for (lane, d) in next.deltas { move(lane, d) }
        if next.pause > 0 { for lane in Lane.allCases { stillUntil[lane] = day + next.pause } }
        current = next
        checkGraddfil()
        return true
    }

    private mutating func landLeaks() {
        for leak in leaks where leak.day == day {
            if let last = lastLeak[leak.lane], day - last <= 5 {
                move(leak.lane, 5)
                ticker = "Läckan om \(leak.lane.short) dementerades. Den gav +5 i stället."
            } else {
                let hit = deadlineDays.contains(day) ? 22.0 : 15.0
                move(leak.lane, -hit)
                ticker = "Läckan om \(leak.lane.short) landade: −\(Int(hit))" + (hit > 15 ? " på rätt dag." : ".")
            }
            lastLeak[leak.lane] = day
        }
        leaks.removeAll { $0.day == day }
    }

    private mutating func runVotes() {
        for v in votes where v.day == day {
            let lane = v.lane ?? leading
            if lanes[lane]! >= Self.voteLine {
                lose(lane, "Omröstningen om \(lane.short) gick igenom \(dateText(day: day))")
                return
            }
            lamps -= 1
            move(lane, -25)
            spaltmeter = min(Self.spaltmeterCap, spaltmeter + 3)
            effect = Effect(title: "OMRÖSTNINGEN FÖLL", tone: .good, chips: ["\(lane.label) −25", "Lampa −1", "+3 spaltmeter"])
            ticker = v.real ? "I verkligheten föll omröstningen \(dateText(day: day))."
                            : "TÄNK OM: talmannens omröstning om \(lane.short) föll \(dateText(day: day))."
            if lamps == 0 {
                ending = Ending(title: "EXTRAVAL", text: verdict, isExtraval: true,
                                footnote: "Rubrikerna är verkliga. Ryktena, slutspurten och utgången är spelets påhitt.")
                return
            }
        }
        votes.removeAll { $0.day == day }
    }

    private var verdict: String { "Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig." }

    private mutating func lose(_ lane: Lane, _ why: String) {
        guard ending == nil else { return }
        ending = Ending(title: "TÄNK OM: REGERING (\(lane.short.uppercased()))", text: "\(why). \(verdict)",
                        isExtraval: false, footnote: "Det hände inte i verkligheten. Rubrikerna är verkliga, ryktena och utgången påhittade.")
    }

    private mutating func finish() {
        guard ending == nil else { return }
        ending = settings.finale
            ? Ending(title: "EXTRAVAL", text: verdict, isExtraval: true, footnote: "Rubrikerna är verkliga. Ryktena och utgången är spelets påhitt.")
            : Ending(title: "FORTSÄTTNING FÖLJER", text: "Det är 18 nov och ingen regering finns. \(verdict)",
                     isExtraval: false, footnote: "Rubrikerna är verkliga. Ryktena är spelets påhitt.")
    }

    // MARK: Reaktioner och kort

    public var newsChoices: [Choice] {
        guard let n = current, ending == nil else { return [] }
        if n.kind == .rumor { return [Choice(id: "read", title: "Fortsätt", quip: "Ryktet är spelets påhitt.")] }
        if n.gift > 0 { return [Choice(id: "thanks", title: "TACK SÅ MYCKET", quip: "Partiledarna gjorde jobbet åt dig. +\(n.gift) spaltmeter.")] }
        var list: [Choice] = []
        if spaltmeter >= 1 {
            list.append(Choice(id: "remind.\(n.target.rawValue)", title: "Påminn – \(n.target.label)", quip: "1 spaltmeter. " + n.quip))
            let second = Lane.allCases.filter { $0 != n.target }.max { lanes[$0]! < lanes[$1]! }!
            list.append(Choice(id: "follow.\(n.target.rawValue).\(second.rawValue)", title: "Följdfråga – \(n.target.short) och \(second.short)",
                               quip: "1 spaltmeter. Svaret blir en ny fråga."))
        }
        list.append(Choice(id: "nocomment", title: "Inga kommentarer", quip: "Ger 1 spaltmeter. Tystnad är också ett citat."))
        return list
    }

    public var cards: [Choice] {
        guard ending == nil, current == nil else { return [] }
        var list: [Choice] = []
        let lane = leading
        if settings.leakWhileRunning && spaltmeter >= 2 {
            list.append(Choice(id: "leak.\(lane.rawValue).\(day + 1)", title: "Läck om \(lane.short) till i morgon",
                               quip: "2 spaltmeter. Kvällspressen tar allt."))
            let target = (day + 1...day + 3).first { deadlineDays.contains($0) && $0 > day + 1 } ?? (day + 3)
            let onDeadline = deadlineDays.contains(target)
            list.append(Choice(id: "leak.\(lane.rawValue).\(target)", title: "Läck om \(lane.short) till \(dateText(day: target))" + (onDeadline ? " – deadline" : ""),
                               quip: "2 spaltmeter. Tajmingen är allt."))
        }
        if spaltmeter >= 3 && day > (stillUntil[lane] ?? -1) {
            list.append(Choice(id: "sega", title: "Sega – \(lane.label) står still",
                               quip: "3 spaltmeter. ”Processen får ta tid.”"))
        }
        return list
    }

    public mutating func play(_ id: String) {
        let parts = id.split(separator: ".").map(String.init)
        if let n = current {
            guard newsChoices.contains(where: { $0.id == id }) else { return }
            switch parts[0] {
            case "thanks":
                spaltmeter = min(Self.spaltmeterCap, spaltmeter + n.gift)
                gifts += 1
                effect = Effect(title: "GÅVA", tone: .good, chips: ["+\(n.gift) spaltmeter"])
            case "remind":
                spaltmeter -= 1; moves += 1
                hit(Lane(rawValue: parts[1])!, by: n.kind == .anonymous ? 6 : 8, label: "PÅMINT")
            case "follow":
                spaltmeter -= 1; moves += 1
                let a = Lane(rawValue: parts[1])!, b = Lane(rawValue: parts[2])!
                let chips = [a, b].compactMap { lane -> String? in
                    guard lanes[lane]! >= 25 else { return "\(lane.short): ingen bryr sig" }
                    move(lane, -4); return "\(lane.label) −4"
                }
                effect = Effect(title: "FÖLJDFRÅGA", tone: .good, chips: ["−1 spaltmeter"] + chips)
            case "nocomment":
                spaltmeter = min(Self.spaltmeterCap, spaltmeter + 1)
                effect = Effect(title: "INGA KOMMENTARER", tone: .neutral, chips: ["+1 spaltmeter"])
            case "read":
                effect = nil
            default:
                return
            }
            resume()
            return
        }
        guard cards.contains(where: { $0.id == id }) else { return }
        switch parts[0] {
        case "leak":
            spaltmeter -= 2; moves += 1
            let lane = Lane(rawValue: parts[1])!, landing = Int(parts[2])!
            leaks.append((landing, lane))
            effect = Effect(title: "LÄCKA LAGD", tone: .neutral, chips: ["−2 spaltmeter", "\(lane.label) \(dateText(day: landing))"])
        case "sega":
            spaltmeter -= 3; moves += 1
            stillUntil[leading] = day + 4
            effect = Effect(title: "SEGA", tone: .good, chips: ["−3 spaltmeter", "\(leading.label) står still 4 dagar"])
        default:
            return
        }
    }

    private mutating func hit(_ lane: Lane, by: Double, label: String) {
        if lanes[lane]! < 25 {
            effect = Effect(title: "INGEN BRYR SIG", tone: .neutral, chips: ["−1 spaltmeter", "\(lane.short) under 25 %"])
            return
        }
        move(lane, -by)
        effect = Effect(title: label, tone: .good, chips: ["−1 spaltmeter", "\(lane.label) −\(Int(by))"])
    }

    // MARK: Visning

    public var meters: [Meter] {
        [Meter(name: "Datum", value: dateText(day: day)),
         Meter(name: "Spaltmeter", value: "\(spaltmeter)"),
         Meter(name: "Lampor", value: String(repeating: "●", count: lamps) + String(repeating: "○", count: 4 - lamps))]
    }

    public var bars: [Bar] {
        let lead = leading
        return Lane.allCases.map { Bar(label: $0.label, value: lanes[$0]!, ghost: lanes[$0]!, max: 100, marks: [60, 85], isLeading: $0 == lead) }
    }
}
