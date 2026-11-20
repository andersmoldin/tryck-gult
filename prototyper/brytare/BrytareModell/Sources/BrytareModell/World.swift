// Omgång 7: världen som Knuten och Hamna i regering spelar i.
// Dagarna går från valdagen 13 sep (dag 0) till 18 nov (sista dagen). När en nyhet kommer stannar
// tiden tills spelaren fortsätter. Nyheter är verkliga (I VERKLIGHETEN, ur researchen i ärende #2)
// eller rykten (spelets påhitt). Inget sprids – nyheterna och dragen ändrar relationerna.

/// Sista dagen: 18 nov.
public let lastDay = 66

/// "13 sep", "1 okt" … för dag n efter valdagen.
public func dateText(day: Int) -> String {
    let months = [("sep", 30), ("okt", 31), ("nov", 30)]
    var d = 13 + day
    for (name, length) in months {
        if d <= length { return "\(d) \(name)" }
        d -= length
    }
    return "\(d) dec"
}

/// Vad rykten får handla om (inställning i appen).
public enum RumorMode: String, CaseIterable, Sendable {
    /// Bara om spelarens egna drag ("Ditt erbjudande har läckt").
    case ownMovesOnly
    /// Också påhittade möten mellan verkliga partier.
    case alsoRealPartyMeetings
}

public struct NewsItem: Equatable, Sendable {
    public enum Kind: Sendable { case real, rumor }
    public enum Tag: Sendable { case opens, locks, lampOut, none }
    public let day: Int
    public let kind: Kind
    public let title: String
    /// Var den verkliga nyheten kommer ifrån (tom för rykten).
    public let source: String
    public let tag: Tag
    public let changes: [Change]

    public struct Change: Equatable, Sendable {
        public let pair: Pair
        /// nil tar bort linjen.
        public let kind: RelationKind?
        public let label: String
    }
}

private func real(_ day: Int, _ title: String, _ source: String, _ tag: NewsItem.Tag,
                  _ changes: [(Pair, RelationKind?, String)] = []) -> NewsItem {
    NewsItem(day: day, kind: .real, title: title, source: source, tag: tag,
             changes: changes.map { NewsItem.Change(pair: $0.0, kind: $0.1, label: $0.2) })
}

private func rumor(_ day: Int, _ title: String, _ changes: [(Pair, RelationKind?, String)]) -> NewsItem {
    NewsItem(day: day, kind: .rumor, title: title, source: "", tag: .none,
             changes: changes.map { NewsItem.Change(pair: $0.0, kind: $0.1, label: $0.2) })
}

/// Relationerna på valnatten, innan något har hänt.
let startRelations: [Pair: (RelationKind, String)] = [
    Pair(.S, .V): (.attraction, "Rödgröna"),
    Pair(.S, .MP): (.attraction, "Rödgröna"),
    Pair(.M, .KD): (.attraction, "Kristerssons sida"),
    Pair(.M, .L): (.attraction, "Kristerssons sida"),
    Pair(.M, .SD): (.negotiating, "SD vill ha ministrar"),
    Pair(.SD, .L): (.conflict, "L: inga SD-ministrar"),
    Pair(.SD, .C): (.conflict, "C: inget SD-inflytande"),
]

/// Verkliga händelser hösten 2026 (numren är händelserna i researchen, data/tg-valresultat).
public let realNews: [NewsItem] = [
    real(1, "V kräver plats i en S-ledd regering. C släpper inte fram en regering där V ingår.", "Händelse #2, 14 sep", .locks,
         [(Pair(.V, .C), .conflict, "C: inget V i regeringen")]),
    real(5, "Andersson ringer alla partiledare utom Åkesson. L: ”behöver inte ringa mig”.", "Händelse #4, 18 sep", .locks,
         [(Pair(.S, .L), .conflict, "L: ring inte")]),
    real(32, "Första statsministeromröstningen: Andersson faller 99–248.", "Riksdagen, 15 okt", .lampOut),
    real(32, "C öppnar för en S-regering utan egna ministrar, om politiken är förankrad i mitten.", "Händelse #9, 15 okt", .opens,
         [(Pair(.C, .S), .negotiating, "C öppnar för S")]),
    real(51, "Thand Ringqvist (C) faller 25–324.", "Riksdagen, 3 nov", .lampOut),
    real(54, "SD släpper kravet på ministerposter och tolererar Kristersson.", "Händelse #14, 6 nov", .opens,
         [(Pair(.M, .SD), .negotiating, "SD tolererar"), (Pair(.SD, .L), nil, "")]),
    real(54, "C ber Andersson och Kristersson om var sitt ”totalpaket”.", "Händelse #15, 6 nov", .opens,
         [(Pair(.C, .M), .negotiating, "C vill ha totalpaket")]),
    real(56, "Andersson: ”full opposition mot en Tidö 2-regering”.", "Händelse #17, 8 nov", .locks,
         [(Pair(.S, .M), .conflict, "Full opposition")]),
    real(56, "S vill regera med MP och C – V utanför regeringen.", "Händelse #19, 8 nov", .locks,
         [(Pair(.S, .V), .conflict, "V utanför")]),
    real(58, "MP: om det blir en stabil överenskommelse ”kommer vi att rösta ja”.", "Händelse #24, 10 nov", .opens,
         [(Pair(.MP, .C), .negotiating, "MP röstar ja")]),
    real(60, "V: ”Vårt kongressbeslut ligger ju fast.” ”Vi kommer ju aldrig att rösta på Ulf Kristersson.”", "Händelse #28, 12 nov", .locks,
         [(Pair(.V, .M), .conflict, "Aldrig Kristersson")]),
    real(63, "C väljer S:s totalpaket.", "Händelse #32, 15 nov", .opens,
         [(Pair(.C, .S), .attraction, "C valde S"), (Pair(.C, .M), .conflict, "C valde bort M")]),
    real(64, "S och V möts i två timmar. V: ”samma besked som tidigare”.", "Händelse #34, 16 nov", .locks,
         [(Pair(.S, .V), .conflict, "Samma besked")]),
    real(65, "Talmannen ger alla partiledare en veckas anstånd.", "Händelse #35, 17 nov", .none),
    real(66, "C: nej till V i regeringen – även för att undvika extraval.", "Händelse #37, 18 nov", .locks,
         [(Pair(.V, .C), .conflict, "Låst – även inför extraval")]),
]

/// Påhittade möten mellan verkliga partier (bara i läget `alsoRealPartyMeetings`).
public let meetingRumors: [NewsItem] = [
    rumor(10, "C och S har setts äta lunch.", [(Pair(.C, .S), .negotiating, "Lunch på stan")]),
    rumor(24, "KD och C delade på en pizza efter voteringen.", [(Pair(.C, .KD), .negotiating, "Delad pizza")]),
    rumor(40, "V och MP har startat en chattgrupp. S är inte med.", [(Pair(.V, .MP), .attraction, "Egen chattgrupp")]),
    rumor(47, "L och SD hälsade på varandra i hissen.", [(Pair(.SD, .L), .negotiating, "Artigt i hissen")]),
    rumor(59, "MP och C delade taxi från riksdagen.", [(Pair(.C, .MP), .attraction, "Delad taxi")]),
    rumor(62, "M och C pratade länge i korridoren.", [(Pair(.C, .M), .negotiating, "Korridorsamtal")]),
]

/// Klockan, nyheterna och relationerna.
public struct World: Sendable {
    private struct Link: Sendable {
        let kind: RelationKind
        let label: String
        let isRumor: Bool
        let since: Int
    }

    public let rumorMode: RumorMode
    public private(set) var day = 0
    /// Nyheten som visas just nu; tiden står still tills `resume()`.
    public private(set) var paused: NewsItem?
    private var queue: [NewsItem]
    private var links: [Pair: Link]

    public init(rumors: RumorMode) {
        rumorMode = rumors
        let all = realNews + (rumors == .alsoRealPartyMeetings ? meetingRumors : [])
        queue = all.enumerated().sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }.map(\.element)
        links = startRelations.mapValues { Link(kind: $0.0, label: $0.1, isRumor: false, since: 0) }
    }

    public var isOver: Bool { day >= lastDay && paused == nil && queue.isEmpty }

    /// Låt dagarna gå. Stannar vid första nyhet som förfaller (och tillämpar den).
    public mutating func tick(days: Int) {
        guard paused == nil else { return }
        if releaseDue() { return }
        var left = days
        while left > 0 && day < lastDay {
            day += 1
            left -= 1
            if releaseDue() { return }
        }
    }

    /// Spelaren har läst nyheten.
    public mutating func resume() {
        paused = nil
        _ = releaseDue()
    }

    /// Ett rykte om spelarens eget drag kommer nästa dag (före dagens verkliga nyheter).
    public mutating func scheduleRumor(_ title: String, changes: [NewsItem.Change]) {
        let item = NewsItem(day: min(day + 1, lastDay), kind: .rumor, title: title, source: "", tag: .none, changes: changes)
        let i = queue.firstIndex { $0.day >= item.day } ?? queue.endIndex
        queue.insert(item, at: i)
    }

    /// Ändra en relation (spelarens drag).
    public mutating func set(_ pair: Pair, _ kind: RelationKind?, _ label: String, rumor: Bool = false) {
        if let kind { links[pair] = Link(kind: kind, label: label, isRumor: rumor, since: day) } else { links[pair] = nil }
    }

    public func relation(_ a: P, _ b: P) -> KeyRelation? {
        links[Pair(a, b)].map { KeyRelation(pair: Pair(a, b), kind: $0.kind, label: $0.label, isNew: $0.since == day, isRumor: $0.isRumor) }
    }

    public var relations: [KeyRelation] {
        links.map { KeyRelation(pair: $0.key, kind: $0.value.kind, label: $0.value.label,
                                isNew: $0.value.since == day && day > 0, isRumor: $0.value.isRumor) }
            .sorted { ($0.pair.a.rawValue, $0.pair.b.rawValue) < ($1.pair.a.rawValue, $1.pair.b.rawValue) }
    }

    private mutating func releaseDue() -> Bool {
        guard paused == nil, let next = queue.first, next.day <= day else { return false }
        queue.removeFirst()
        for c in next.changes { set(c.pair, c.kind, c.label, rumor: next.kind == .rumor) }
        paused = next
        return true
    }
}
