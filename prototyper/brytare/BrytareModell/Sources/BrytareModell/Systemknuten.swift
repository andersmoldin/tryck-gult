// Omgång 8: Systemknuten. Översättning av simuleringen i data/tg-knut-system/report.md (Bilaga A och B).
// Partierna förhandlar av sig själva: trådar växer mot sina tak, tålamod brinner ner tills partier släpper
// mjuka krav, och Ribban visar hur många mandat som trycker ja eller gult för det ledande spåret.
// Spelaren är knuten och stoppar det med tre stämplar som laddas om med tiden.

/// Seedad slump (SplitMix64) så att en runda går att spela om och testa.
struct SeededRandom: Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Likformigt i [a, b].
    mutating func uniform(_ a: Double, _ b: Double) -> Double {
        a + (b - a) * Double(next() >> 11) / Double(1 << 53)
    }
}

/// Siffrorna ur rapportens Bilaga A (Tuning.json).
public enum SystemTuning {
    static let days = 68
    static let tryckStart = 1.0, tryckEnd = 2.0
    static let patienceDrain = 1.15
    static let patienceAfterYield = 50.0, patienceAfterBreakingPoint = 30.0
    static let driftK = 4.5, desperation = 25.0, overCeilDecay = 0.5
    static let mediatorBonus = 1.4
    static let handshakeDecay = 0.5
    static let lockAt = 70.0, redAt = -30.0
    static let demandCap = 0.6, ghostFrom = 0.8
    static let graddfilDays = 3, graddfilSolid = 175.0, failedVoteTryck = 0.15, impFloor = 0.3, voteCooldownDays = 8, failedVoteHit = 15.0
    static let leakHit = 40.0, freshLeakHit = 75.0, freshDays = 4, leakPatienceCost = 7.0
    static let kravDays = 10, kravPatience = 15.0, burstPatience = 15.0
    static let forhalaDays = 4, forhalaVotePush = 3, forhalaTryck = 0.1
    static let patienceJitter = 12.0, driftNoise = 0.25
}

public enum Stamp: String, CaseIterable, Sendable {
    case leak = "LÄCKA", demand = "KRAV", delay = "FÖRHALA"
    /// (högst, dagar per laddning, upplåst dag)
    var charging: (max: Int, per: Int, unlock: Int) {
        switch self {
        case .leak: return (2, 7, 0)
        case .demand: return (1, 9, 5)
        case .delay: return (1, 14, 19)
        }
    }
}

private let startPatience: [P: Double] = [.S: 70, .M: 70, .SD: 92, .V: 75, .C: 72, .KD: 65, .MP: 60, .L: 70]

private let startRel: [Pair: Double] = [
    Pair(.S, .MP): 75, Pair(.S, .V): 55, Pair(.S, .C): 10, Pair(.S, .M): -20, Pair(.S, .KD): -20,
    Pair(.S, .L): -35, Pair(.S, .SD): -100,
    Pair(.M, .KD): 85, Pair(.M, .L): 80, Pair(.KD, .L): 75, Pair(.M, .SD): 75, Pair(.KD, .SD): 70,
    Pair(.L, .SD): 55, Pair(.M, .C): 20, Pair(.KD, .C): 20, Pair(.L, .C): 35,
    Pair(.C, .MP): 20, Pair(.C, .V): -40, Pair(.C, .SD): -60,
    Pair(.V, .M): -100, Pair(.V, .SD): -100, Pair(.V, .KD): -60, Pair(.V, .L): -60, Pair(.V, .MP): 60,
    Pair(.MP, .M): -20, Pair(.MP, .KD): -10, Pair(.MP, .L): 0, Pair(.MP, .SD): -70,
]

private let ceilings: [Pair: Double] = [
    Pair(.S, .MP): 95, Pair(.S, .V): 90, Pair(.S, .C): 85, Pair(.S, .L): 45, Pair(.S, .KD): 30, Pair(.S, .M): 55, Pair(.S, .SD): -100,
    Pair(.M, .KD): 100, Pair(.M, .L): 95, Pair(.M, .SD): 90, Pair(.M, .C): 85, Pair(.M, .MP): 30, Pair(.M, .V): -100,
    Pair(.SD, .KD): 90, Pair(.SD, .L): 70, Pair(.SD, .C): 10, Pair(.SD, .MP): -50, Pair(.SD, .V): -100,
    Pair(.V, .MP): 90, Pair(.V, .KD): 0, Pair(.V, .L): 10, Pair(.V, .C): 50,
    Pair(.C, .L): 90, Pair(.C, .KD): 80, Pair(.C, .MP): 80, Pair(.KD, .MP): 40, Pair(.KD, .L): 95, Pair(.MP, .L): 60,
]

private let frozenStart: Set<Pair> = [Pair(.S, .SD), Pair(.V, .M), Pair(.V, .SD)]

/// Ett spår: en tänkt regering med en statsministerkandidat.
public struct Track: Sendable {
    public let name: String
    public var leader: P
    public var members: [P]
    public var active: Bool
    var cooldownUntil = -1
}

/// Ett krav eller en röd linje som håller ett parti borta från vissa spår.
struct Constraint: Sendable {
    enum Kind: Sendable { case red, demand }
    let id: String
    let party: P
    let kind: Kind
    let hard: Bool
    let applies: @Sendable (Track) -> Bool
    var until = 999
    var player = false
}

struct ScheduledVote: Sendable {
    var day: Int
    let track: String
    let real: Bool
}

public struct SystemKnotGame: ClockGame {
    public let title = "Systemknuten"
    public let tips = [
        "Du är knuten. Åtta partier förhandlar av sig själva, och Ribban visar hur nära en regering det är: mandat som trycker ja eller gult för det ledande spåret.",
        "Når Ribbans fasta fyllnad 175 kallar talmannen till omröstning om tre dagar. Står den kvar då bildas en regering och du har förlorat. Faller den släcks en lampa.",
        "Tre stämplar laddas om med tiden: LÄCKA skadar en tråd, KRAV får ett parti att kräva något nytt av det ledande spåret, FÖRHALA stoppar allt några dagar. Varje drag gör partierna otåligare – och otåliga partier ger vika.",
        "Extraval 20 nov är vinst. Fyra släckta lampor före dess är fullträff. Allt simuleringen hittar på är märkt TÄNK OM.",
    ]

    public let hardLinesCanFall: Bool
    public private(set) var day = 0
    public private(set) var paused: NewsItem?
    public private(set) var effect: Effect?
    public private(set) var ending: Ending?
    public private(set) var ticker: String?
    public private(set) var lamps = 4
    public private(set) var charges: [Stamp: Int] = [.leak: 0, .demand: 0, .delay: 0]
    public private(set) var moves = 0
    public private(set) var gifts = 0
    var rel: [Pair: Double] = [:]
    var formed: [Pair: Int] = [:]
    var patience: [P: Double] = [:]
    var constraints: [Constraint] = []
    public private(set) var tracks: [String: Track] = [:]
    var votes: [ScheduledVote] = []
    var tryckBonus = 0.0
    var freezeUntil = -1
    var rottSurgeFrom = 999
    private var recharged: [Stamp: Int] = [.leak: 0, .demand: 0, .delay: 0]
    private var noise: [Pair: Double] = [:]
    private var frozen = frozenStart
    private var yields: [P: Int] = [:]
    private var previousKinds: [Pair: RelationKind] = [:]
    private var kindsChangedOn: [Pair: Int] = [:]

    public init(seed: UInt64, hardLinesCanFall: Bool = false) {
        self.hardLinesCanFall = hardLinesCanFall
        var rng = SeededRandom(seed: seed)
        for (i, a) in P.allCases.enumerated() { for b in P.allCases.dropFirst(i + 1) { rel[Pair(a, b)] = 0 } }
        for (pair, v) in startRel { rel[pair] = v }
        for pair in rel.keys.sorted(by: { ($0.a.rawValue, $0.b.rawValue) < ($1.a.rawValue, $1.b.rawValue) }) {
            noise[pair] = 1 + rng.uniform(-SystemTuning.driftNoise, SystemTuning.driftNoise)
            if rel[pair]! >= SystemTuning.lockAt { formed[pair] = -99 }
        }
        let j = SystemTuning.patienceJitter
        for p in [P.S, .M, .SD, .V, .C, .KD, .MP, .L] {
            patience[p] = max(10, min(100, startPatience[p]! + rng.uniform(-j, j)))
        }
        precondition(ceilings.count == 28, "ett tak per par")
        tracks = [
            "Rött": Track(name: "Rött", leader: .S, members: [.S], active: true),
            "Blått": Track(name: "Blått", leader: .M, members: [.M, .KD, .L], active: true),
            "Mitten": Track(name: "Mitten", leader: .C, members: [.C], active: false),
        ]
        constraints = [
            Constraint(id: "C-inteV", party: .C, kind: .red, hard: true, applies: { $0.members.contains(.V) }),
            Constraint(id: "V-iRegeringen", party: .V, kind: .demand, hard: false, applies: { !$0.members.contains(.V) }),
            Constraint(id: "V-aldrigKristersson", party: .V, kind: .red, hard: true, applies: { $0.leader == .M }),
            Constraint(id: "SD-ministrar", party: .SD, kind: .demand, hard: false, applies: { !$0.members.contains(.SD) }),
            Constraint(id: "L-Kristersson", party: .L, kind: .demand, hard: false, applies: { $0.leader != .M }),
            Constraint(id: "KD-borgerligt", party: .KD, kind: .demand, hard: false, applies: { $0.leader == .S }),
        ]
        previousKinds = Dictionary(uniqueKeysWithValues: shownRelations().map { ($0.pair, $0.kind) })
        beginDay()
    }

    // MARK: Läsning

    func f(_ r: Double) -> Double { max(0, min(1, (r + 30) / 100)) }

    /// Hur stor andel av X:s mandat som inte röstar nej till spåret.
    func support(_ x: P, _ t: Track) -> Double {
        if x == t.leader { return 1 }
        var cap = 1.0
        for c in constraints where c.party == x && c.applies(t) && day <= c.until {
            cap = min(cap, c.kind == .red ? 0 : SystemTuning.demandCap)
        }
        let others = t.members.filter { $0 != x }
        guard !others.isEmpty else { return cap }
        return min(cap, others.map { f(rel[Pair(x, $0)]!) }.min()!)
    }

    /// (fast, streckad) fyllnad för ett spår.
    public func meter(_ t: Track) -> (solid: Double, ghost: Double) {
        var solid = 0.0, ghost = 0.0
        for x in P.allCases {
            let s = support(x, t)
            if s >= SystemTuning.ghostFrom { ghost += Double(x.seats) * s }
            if s >= 1 { solid += Double(x.seats) }
        }
        return (solid, ghost)
    }

    public var leading: Track {
        tracks.values.filter(\.active).sorted { $0.name < $1.name }
            .max { let a = meter($0), b = meter($1); return (a.solid, a.ghost) < (b.solid, b.ghost) }!
    }

    var tryck: Double {
        SystemTuning.tryckStart + (SystemTuning.tryckEnd - SystemTuning.tryckStart) * Double(day) / Double(SystemTuning.days) + tryckBonus
    }

    // MARK: Klockan

    public mutating func tick(days: Int) {
        for _ in 0..<days {
            guard ending == nil, paused == nil else { return }
            endDay()
            guard ending == nil else { return }
            if day >= SystemTuning.days { finish(); return }
            day += 1
            beginDay()
        }
    }

    public mutating func resume() {
        paused = nil
    }

    /// Början av dagen: laddning, verkliga händelser, spår, omröstningar.
    mutating func beginDay() {
        recharge()
        applyEvents()
        reshapeTracks()
        runVotes()
        noteKindChanges()
    }

    /// Slutet av dagen: trådarna driver, tålamodet brinner, talmannens gräddfil.
    mutating func endDay() {
        drift()
        burnPatience()
        graddfil()
        noteKindChanges()
    }

    private mutating func recharge() {
        for m in Stamp.allCases {
            let (mx, per, unlock) = m.charging
            if day < unlock { continue }
            if day == unlock && charges[m] == 0 && recharged[m] == 0 {
                charges[m] = 1
                recharged[m] = day
                continue
            }
            if charges[m]! < mx && day - recharged[m]! >= per {
                charges[m]! += 1
                recharged[m] = day
            } else if charges[m]! >= mx {
                recharged[m] = day
            }
        }
    }

    private mutating func gift(_ m: Stamp) {
        charges[m] = min(m.charging.max, charges[m]! + 1)
        gifts += 1
    }

    private mutating func dropConstraint(_ id: String) { constraints.removeAll { $0.id == id } }

    private mutating func raise(_ a: P, _ b: P, _ by: Double) { rel[Pair(a, b)] = min(100, rel[Pair(a, b)]! + by) }

    private mutating func calm(_ p: P, _ by: Double) { patience[p] = min(100, patience[p]! + by) }

    private mutating func news(_ title: String, _ source: String) {
        paused = NewsItem(day: day, kind: .real, title: title, source: source, tag: .none, changes: [])
    }

    private mutating func applyEvents() {
        switch day {
        case 5:
            rel[Pair(.S, .L)]! -= 20
            news("Andersson ringer alla partiledare utom Åkesson. L: ”behöver inte ringa mig”.", "Händelse #4, 18 sep")
        case 29:
            votes.append(ScheduledVote(day: 32, track: "Rött", real: true))
        case 32:
            raise(.C, .S, 20); calm(.V, 10); gift(.demand)
            news("C öppnar för en S-regering utan egna ministrar. V avvisar rollen som stödparti. Gåva: KRAV.", "Händelse #9, 15 okt")
        case 43:
            raise(.C, .S, 10); calm(.L, 15); gift(.leak)
            news("C: ”Det finns idag en majoritet för mittenpolitik, men ingen majoritet för en mittenregering.” Gåva: LÄCKA.", "Händelse #11, 26 okt")
        case 46:
            tracks["Mitten"]!.members = [.C, .S, .KD, .MP, .L]
            tracks["Mitten"]!.active = true
            votes.append(ScheduledVote(day: 51, track: "Mitten", real: true))
            news("Talmannen föreslår Thand Ringqvist (C) som statsminister för C, S, KD, MP och L.", "Händelse #12, 29 okt")
        case 52:
            tracks["Mitten"]!.active = false
        case 54:
            let hadDemand = constraints.contains { $0.id == "SD-ministrar" }
            dropConstraint("SD-ministrar")
            constraints.append(Constraint(id: "C-totalpaket", party: .C, kind: .demand, hard: false, applies: { $0.leader != .C }, until: 62))
            news("SD släpper kravet på ministerposter. C kräver ett ”totalpaket” av Andersson och Kristersson.", "Händelse #14 och #15, 6 nov")
            if !hadDemand { ticker = "TÄNK OM: SD hade redan gett vika i det här bordet." }
        case 56:
            calm(.S, 30)
            constraints.append(Constraint(id: "S-inteTidö2", party: .S, kind: .red, hard: true, applies: { $0.leader == .M }))
            tracks["Rött"]!.members = [.S, .MP, .C]
            rel[Pair(.S, .V)]! -= 15
            calm(.V, 10); gift(.demand)
            news("S: full opposition mot Tidö 2, vill regera med MP och C. V: kravet ”går inte att påverka”. Gåva: KRAV.", "Händelse #17, #19, #20, 8 nov")
        case 57:
            tracks["Mitten"] = Track(name: "Mitten", leader: .S, members: [.S, .M], active: true)
            news("Thomas Bodström (S, f.d. minister) vill pröva S och M. I spelet blir det mittenspåret – TÄNK OM.", "Händelse #22, 9 nov")
        case 58:
            raise(.MP, .S, 15); raise(.MP, .C, 15)
            news("MP: om det blir en stabil överenskommelse ”kommer vi att rösta ja”.", "Händelse #24, 10 nov")
        case 60:
            calm(.V, 10); gift(.leak)
            news("V: ”Vårt kongressbeslut ligger ju fast.” Gåva: LÄCKA.", "Händelse #28, 12 nov")
        case 63:
            constraints.append(Constraint(id: "C-valdeS", party: .C, kind: .demand, hard: false, applies: { $0.leader == .M }))
            raise(.C, .S, 20)
            news("C väljer S:s totalpaket.", "Händelse #32, 15 nov")
        case 64:
            raise(.S, .V, 10); calm(.V, 5)
            news("S och V möts i två timmar. V: ”samma besked som tidigare”.", "Händelse #34, 16 nov")
        case 65:
            for i in votes.indices { votes[i].day += 7 }
            rottSurgeFrom = 65
            news("Talmannen ger alla partiledare en veckas anstånd. De rödgröna förhandlar intensivt.", "Händelse #35, 17 nov")
        case 66:
            calm(.C, 20); gift(.leak)
            news("C: nej till V i regeringen – även för att undvika extraval. Gåva: LÄCKA.", "Händelse #37, 18 nov")
        default:
            break
        }
    }

    private mutating func reshapeTracks() {
        guard day >= 56 else { return }
        var base: [P] = [.S, .MP, .C]
        if !constraints.contains(where: { $0.id == "C-inteV" }) { base.append(.V) }
        tracks["Rött"]!.members = base
    }

    private mutating func drift() {
        guard day > freezeUntil else { return }
        let tr = tryck
        let rott = tracks["Rött"]!.members
        for pair in rel.keys.sorted(by: { ($0.a.rawValue, $0.b.rawValue) < ($1.a.rawValue, $1.b.rawValue) }) where !frozen.contains(pair) {
            let r = rel[pair]!, a = pair.a, b = pair.b
            let restless = ((100 - patience[a]!) + (100 - patience[b]!)) / 200
            let imp = SystemTuning.impFloor + (1 - SystemTuning.impFloor) * restless
            let mediated = a != .MP && b != .MP && rel[Pair(.MP, a)]! >= 0 && rel[Pair(.MP, b)]! >= 0
            let med = mediated ? SystemTuning.mediatorBonus : 1
            let surge = day >= rottSurgeFrom && rott.contains(a) && (rott + [.V]).contains(b) ? 2.0 : 1.0
            let ceil = ceilings[pair]! + SystemTuning.desperation * restless
            var dr = r < ceil ? SystemTuning.driftK * tr * imp * (ceil - r) / 100 * med * surge * noise[pair]! : -SystemTuning.overCeilDecay
            if r >= SystemTuning.lockAt { dr -= SystemTuning.handshakeDecay }
            let new = max(-100, min(100, r + dr))
            if r < SystemTuning.lockAt && SystemTuning.lockAt <= new { formed[pair] = day }
            rel[pair] = new
        }
    }

    private mutating func burnPatience() {
        let tr = tryck
        for x in P.allCases {
            if day <= freezeUntil { continue }
            patience[x]! -= SystemTuning.patienceDrain * tr
            guard patience[x]! <= 0 else { continue }
            // Bara mjuka krav ger vika av tålamod. Hårda röda linjer faller aldrig av sig själva (förval A).
            if let c = constraints.first(where: { $0.party == x && !$0.player && !$0.hard }) {
                dropConstraint(c.id)
                yields[x, default: 0] += 1
                ticker = "TÄNK OM: \(x.rawValue) släpper ett krav (\(c.id))."
                patience[x] = SystemTuning.patienceAfterYield
            } else if hardLinesCanFall, yields[x, default: 0] >= 2,
                      let c = constraints.first(where: { $0.party == x && !$0.player && $0.hard }) {
                // Inställning B: efter två eftergifter kan även en hård linje falla.
                dropConstraint(c.id)
                yields[x, default: 0] += 1
                ticker = "TÄNK OM: \(x.rawValue) släpper en röd linje (\(c.id))."
                patience[x] = SystemTuning.patienceAfterYield
            } else {
                patience[x] = SystemTuning.patienceAfterBreakingPoint
            }
        }
    }

    private mutating func runVotes() {
        for v in votes.sorted(by: { ($0.day, $0.track) < ($1.day, $1.track) }) where v.day == day {
            votes.removeAll { $0.day == v.day && $0.track == v.track && $0.real == v.real }
            let t = tracks[v.track]!
            let (solid, _) = meter(t)
            if solid >= Double(majority) {
                effect = Effect(title: "GÅR IGENOM", tone: .bad, chips: ["\(v.track): \(Int(solid)) av 175"])
                ending = Ending(title: "TÄNK OM: EN REGERING",
                                text: "Den \(dateText(day: day)) gick spåret \(v.track) (\(t.members.map(\.rawValue).joined(separator: " + "))) igenom: \(Int(solid)) mandat tryckte inte nej. Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                                isExtraval: false, footnote: "Det hände inte i verkligheten. " + fiction)
                return
            }
            lamps -= 1
            effect = Effect(title: "FÖLL", tone: .good, chips: ["\(v.track): \(Int(solid)) av 175", "Lampa −1"])
            if !v.real { ticker = "TÄNK OM: talmannens omröstning om \(v.track) föll." }
            tracks[v.track]!.cooldownUntil = day + SystemTuning.voteCooldownDays
            tryckBonus += SystemTuning.failedVoteTryck
            for x in P.allCases where !t.members.contains(x) {
                for y in t.members where !frozen.contains(Pair(x, y)) {
                    rel[Pair(x, y)] = max(-100, rel[Pair(x, y)]! - SystemTuning.failedVoteHit)
                }
            }
            if lamps == 0 {
                ending = Ending(title: "EXTRAVAL – FULLTRÄFF",
                                text: "Fyra förslag föll. Knuten höll. Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                                isExtraval: true, footnote: fiction)
                return
            }
        }
    }

    private mutating func graddfil() {
        guard votes.isEmpty else { return }
        for t in tracks.values.sorted(by: { $0.name < $1.name }) where t.active && day >= t.cooldownUntil {
            if meter(t).solid >= SystemTuning.graddfilSolid {
                votes.append(ScheduledVote(day: day + SystemTuning.graddfilDays, track: t.name, real: false))
                ticker = "TÄNK OM: \(t.name) har 175. Talmannen kallar till omröstning \(dateText(day: day + SystemTuning.graddfilDays))."
                return
            }
        }
    }

    private mutating func finish() {
        guard ending == nil else { return }
        if let lost = tracks.values.sorted(by: { $0.name < $1.name }).first(where: { meter($0).solid >= Double(majority) }) {
            ending = Ending(title: "TÄNK OM: EN REGERING",
                            text: "Hösten tog slut med \(lost.name) på \(Int(meter(lost).solid)). Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                            isExtraval: false, footnote: "Det hände inte i verkligheten. " + fiction)
        } else {
            ending = Ending(title: "EXTRAVAL",
                            text: "20 nov och inget spår har 175. Du gjorde \(moves) drag. Partiledarna gjorde \(gifts) åt dig.",
                            isExtraval: true, footnote: fiction)
        }
    }

    // MARK: Spelarens stämplar

    private mutating func use(_ m: Stamp) {
        charges[m]! -= 1
        if charges[m] == m.charging.max - 1 { recharged[m] = day }
        moves += 1
    }

    @discardableResult
    mutating func leak(_ a: P, _ b: P) -> Bool {
        guard charges[.leak]! > 0 else { return false }
        use(.leak)
        let pair = Pair(a, b)
        let fresh = rel[pair]! >= SystemTuning.lockAt && day - (formed[pair] ?? -99) <= SystemTuning.freshDays
        let hit = fresh ? SystemTuning.freshLeakHit : SystemTuning.leakHit
        rel[pair] = max(-100, rel[pair]! - hit)
        for x in [a, b] { patience[x] = max(1, patience[x]! - SystemTuning.leakPatienceCost) }
        effect = Effect(title: "LÄCKA", tone: .good, chips: ["\(a.rawValue)–\(b.rawValue) −\(Int(hit))" + (fresh ? " (färskt handslag)" : ""), "Tålamod −7 för båda"])
        ticker = "RYKTE (påhittat): något om \(a.rawValue) och \(b.rawValue) har läckt."
        noteKindChanges()
        return true
    }

    @discardableResult
    mutating func demand(_ x: P) -> Bool {
        guard charges[.demand]! > 0 else { return false }
        use(.demand)
        if constraints.contains(where: { $0.player && $0.party == x && day <= $0.until }) {
            constraints.removeAll { $0.party == x && ($0.player || !$0.hard) }
            patience[x] = SystemTuning.burstPatience
            effect = Effect(title: "\(x.rawValue) SPRICKER", tone: .bad, chips: ["Alla mjuka krav släppta"])
            return true
        }
        let target = leading.name
        constraints.append(Constraint(id: "spelare-\(x.rawValue)-\(day)", party: x, kind: .demand, hard: false,
                                      applies: { $0.name == target }, until: day + SystemTuning.kravDays, player: true))
        patience[x] = min(100, patience[x]! + SystemTuning.kravPatience)
        effect = Effect(title: "KRAV", tone: .good, chips: ["\(x.rawValue) kräver något av \(target)", "\(SystemTuning.kravDays) dagar"])
        return true
    }

    @discardableResult
    mutating func delay() -> Bool {
        guard charges[.delay]! > 0 else { return false }
        use(.delay)
        freezeUntil = day + SystemTuning.forhalaDays - 1
        for i in votes.indices where !votes[i].real { votes[i].day += SystemTuning.forhalaVotePush }
        tryckBonus += SystemTuning.forhalaTryck
        effect = Effect(title: "FÖRHALA", tone: .good, chips: ["Allt står still \(SystemTuning.forhalaDays) dagar", "Trycket +0,1"])
        return true
    }

    /// Läckor som skulle sänka spårets fasta stöd: (mandat bort, tålamodsrisk, X, Y).
    func swingOptions(_ t: Track) -> [(seats: Int, risk: Double, x: P, y: P)] {
        var opts: [(Int, Double, P, P)] = []
        for x in P.allCases where x != t.leader && support(x, t) >= 0.8 {
            for y in t.members where y != x && !frozen.contains(Pair(x, y)) {
                let r = rel[Pair(x, y)]!
                let fresh = r >= SystemTuning.lockAt && day - (formed[Pair(x, y)] ?? -99) <= SystemTuning.freshDays
                let hit = fresh ? SystemTuning.freshLeakHit : SystemTuning.leakHit
                if r - hit < SystemTuning.lockAt - 10 {
                    opts.append((x.seats, min(patience[x]!, patience[y]!), x, y))
                }
            }
        }
        return opts.map { (seats: $0.0, risk: $0.1, x: $0.2, y: $0.3) }
    }

    func wouldLockSoon(_ t: Track) -> (solid: Double, soon: Double) {
        let solid = meter(t).solid
        let near = P.allCases.filter { let s = support($0, t); return s >= 0.8 && s < 1 }.reduce(0) { $0 + Double($1.seats) }
        return (solid, solid + near)
    }

    /// Förslag: den läcka som tar flest mandat från det ledande spåret.
    private var leakSuggestion: (P, P)? {
        let t = leading
        if let o = swingOptions(t).sorted(by: { ($0.seats, $0.risk) > ($1.seats, $1.risk) }).first { return (o.x, o.y) }
        return rel.filter { !frozen.contains($0.key) && $0.value >= SystemTuning.lockAt }
            .sorted { $0.value > $1.value }.first.map { ($0.key.a, $0.key.b) }
    }

    /// Förslag: kravet läggs på det största partiet som nästan stöder det ledande spåret.
    private var demandSuggestion: P? {
        let t = leading
        return P.allCases.filter { $0 != t.leader && support($0, t) >= 0.8 }.max { $0.seats < $1.seats }
    }

    public var cards: [Choice] {
        guard ending == nil, paused == nil else { return [] }
        var list: [Choice] = []
        if charges[.leak]! > 0, let (a, b) = leakSuggestion {
            list.append(Choice(id: "leak.\(a.rawValue).\(b.rawValue)", title: "LÄCKA: \(a.rawValue)–\(b.rawValue)",
                               quip: "Tråden får sig en törn. Båda blir otåligare.", icon: "stampel-lacka"))
        }
        if charges[.demand]! > 0, let x = demandSuggestion {
            list.append(Choice(id: "demand.\(x.rawValue)", title: "KRAV: \(x.rawValue)",
                               quip: "\(x.rawValue) kommer på något det måste ha. Två krav i rad får det att spricka.", icon: "stampel-krav"))
        }
        if charges[.delay]! > 0 {
            list.append(Choice(id: "delay", title: "FÖRHALA",
                               quip: "Allt står still några dagar. Trycket stiger.", icon: "stampel-forhala"))
        }
        return list
    }

    public mutating func play(_ id: String) {
        guard cards.contains(where: { $0.id == id }) else { return }
        let parts = id.split(separator: ".").map(String.init)
        switch parts[0] {
        case "leak": if let a = P(rawValue: parts[1]), let b = P(rawValue: parts[2]) { leak(a, b) }
        case "demand": if let x = P(rawValue: parts[1]) { demand(x) }
        case "delay": delay()
        default: break
        }
    }

    // MARK: Visning

    public var meters: [Meter] {
        let t = leading, m = meter(t)
        var caption = "Mandat som trycker ja eller gult för \(t.name) (\(t.members.map(\.rawValue).joined(separator: "+"))). 175 = regering."
        if let v = votes.filter({ !$0.real }).min(by: { $0.day < $1.day }) {
            caption += " Talmannen kallar till omröstning om \(v.track) \(dateText(day: v.day))."
        }
        return [Meter(name: "Datum", value: dateText(day: day)),
                Meter(name: "Ribban", value: "\(t.name) \(Int(m.solid))", caption: caption),
                Meter(name: "Lampor", value: String(repeating: "●", count: lamps) + String(repeating: "○", count: 4 - lamps)),
                Meter(name: "Stämplar", value: "L\(charges[.leak]!) K\(charges[.demand]!) F\(charges[.delay]!)")]
    }

    public var bars: [Bar] {
        let lead = leading.name
        return tracks.values.filter(\.active).sorted { $0.name < $1.name }.map { t in
            let m = meter(t)
            return Bar(label: "\(t.name) (\(t.members.map(\.rawValue).joined(separator: "+")))", value: m.solid,
                       ghost: m.ghost, max: Double(349), marks: [Double(majority)], isLeading: t.name == lead)
        }
    }

    public var figure: String? { nil }

    /// Bordets trådar som linjer: handslag (🤝), nära samtal (💬) och hårda röda linjer (✋).
    func shownRelations() -> [KeyRelation] {
        rel.compactMap { pair, r -> KeyRelation? in
            let kind: RelationKind
            if frozen.contains(pair) || constraints.contains(where: { c in c.hard && c.kind == .red && ((c.party == pair.a) || (c.party == pair.b)) && redLinePair(c) == pair }) {
                kind = .conflict
            } else if r >= SystemTuning.lockAt {
                kind = .attraction
            } else if r >= 50 {
                kind = .negotiating
            } else {
                return nil
            }
            let label = kind == .attraction ? "Handslag" : (kind == .negotiating ? "Samtal" : "Röd linje")
            return KeyRelation(pair: pair, kind: kind, label: label, isNew: kindsChangedOn[pair] == day && day > 0)
        }
        .sorted { ($0.pair.a.rawValue, $0.pair.b.rawValue) < ($1.pair.a.rawValue, $1.pair.b.rawValue) }
    }

    /// Den hårda röda linje som ett krav motsvarar i nätet.
    private func redLinePair(_ c: Constraint) -> Pair? {
        switch c.id {
        case "C-inteV": return Pair(.C, .V)
        case "V-aldrigKristersson": return Pair(.V, .M)
        case "S-inteTidö2": return Pair(.S, .M)
        default: return nil
        }
    }

    public var relations: [KeyRelation] { shownRelations() }

    private mutating func noteKindChanges() {
        let now = Dictionary(uniqueKeysWithValues: shownRelations().map { ($0.pair, $0.kind) })
        for pair in Set(now.keys).union(previousKinds.keys) where now[pair] != previousKinds[pair] {
            kindsChangedOn[pair] = day
        }
        previousKinds = now
    }
}
