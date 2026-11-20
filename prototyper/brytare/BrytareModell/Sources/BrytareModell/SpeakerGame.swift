// Perspektiv 2: du är talmannen. Du väljer vem som får försöka och när det blir omröstning.
// Väntar du för länge tar tålamodet slut; fyra fallna omröstningar ger extraval.

public struct SpeakerGame: PerspectiveGame {
    public static let title = "Talmannen"
    public static let role = "Du är talmannen. Välj vem som får försöka – och när. Undvik extraval."
    public static let tips = [
        "En kandidat går igenom om färre än 175 röstar nej.",
        "Varje knapp visar hur många kandidaten har just nu.",
        "Att vänta kostar tålamod. Fyra fallna omröstningar ger extraval.",
    ]

    private var turns = Turns()
    public private(set) var attemptsLeft = 4
    public private(set) var patience = 3
    /// Det försök som kom närmast 175, för slutskärmen.
    private var closest: (candidate: Candidate, support: Int)?

    public init() {}

    public var headlineIndex: Int { turns.headlineIndex }
    public var outcome: String? { turns.outcome }
    public var ending: Ending? { turns.ending }
    public var question: String { "Vem får försöka bilda regering?" }

    public var meters: [Meter] {
        [Meter(name: "Försök kvar", value: "\(attemptsLeft) av 4"),
         Meter(name: "Tålamod", value: "\(patience) av 3"),
         Meter(name: "Datum", value: headline.date)]
    }

    public var choices: [Choice] {
        guard turns.canChoose else { return [] }
        var list = Candidate.allCases.map { c in
            let r = result(for: c)
            return Choice(id: c.rawValue, title: "Låt \(c.name) försöka",
                          cost: supportText(r) + (r.passed ? " – går igenom" : " – faller, kostar ett försök"))
        }
        if patience > 0 && !turns.isLastHeadline {
            list.append(Choice(id: "wait", title: "Ge partierna en vecka till",
                               cost: "Tålamod −1 (\(patience - 1) kvar efteråt). Nästa rubrik slår ner."))
        }
        return list
    }

    public mutating func choose(_ id: String) {
        guard choices.contains(where: { $0.id == id }) else { return }
        if id == "wait" {
            patience -= 1
            turns.resolve("Partierna får en vecka till. Tålamodet sjunker.")
            return
        }
        guard let c = Candidate(rawValue: id) else { return }
        let r = result(for: c)
        if r.supportSeats > (closest?.support ?? -1) { closest = (c, r.supportSeats) }
        if r.passed {
            turns.resolve(voteText(r), ending: Ending(
                title: "REGERING", text: "\(c.name) blev statsminister.", isExtraval: false))
            return
        }
        attemptsLeft -= 1
        let missing = majority - r.supportSeats
        turns.resolve(voteText(r) + " \(c.name) saknade \(missing) mandat.",
                      ending: attemptsLeft == 0 ? extraval() : nil)
    }

    public mutating func proceed() { turns.proceed() }

    private func result(for c: Candidate) -> VoteResult {
        tally(historicVotes(for: c, after: headlineIndex))
    }

    private func extraval() -> Ending {
        let text = closest.map { "Ingen fick ihop 175. Närmast kom \($0.candidate.name) med \($0.support) – \(majority - $0.support) mandat för lite." }
            ?? "Ingen fick ihop 175."
        return Ending(title: "EXTRAVAL", text: text, isExtraval: true)
    }
}
