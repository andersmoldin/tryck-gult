// Perspektiv 1: du är S:s statsministerkandidat. Du behöver både V och C,
// men V kräver ministerposter och C vill inte ha V i regeringen.

public struct CandidateGame: PerspectiveGame {
    public static let title = "Statsministerkandidaten"
    public static let role = "Du leder S. Få ihop 175 som släpper fram dig – V och C vill olika saker."
    public static let tips = [
        "Du har S (99) och MP (22). Det är 121 – du behöver 175 som röstar ja eller gult.",
        "V (30) och C (25) räcker precis. Varje löfte visar hur många du får.",
        "Fyra fallna omröstningar ger extraval.",
    ]

    private var turns = Turns()
    public private(set) var attemptsLeft = 4

    public init() {}

    public var headlineIndex: Int { turns.headlineIndex }
    public var outcome: String? { turns.outcome }
    public var ending: Ending? { turns.ending }
    public var question: String { "Vad lovar du för att få ihop 175?" }

    public var meters: [Meter] {
        [Meter(name: "Försök kvar", value: "\(attemptsLeft) av 4"), Meter(name: "Datum", value: headline.date)]
    }

    public var choices: [Choice] {
        guard turns.canChoose else { return [] }
        var list = [
            Choice(id: "promiseV", title: "Lova V ministerposter",
                   cost: "V röstar ja, C röstar nej → \(supportText(result(promiseToV: true)))"),
            Choice(id: "promiseC", title: "Lova C att V hålls utanför",
                   cost: "C röstar ja, V röstar nej → \(supportText(result(promiseToV: false)))"),
        ]
        if !turns.isLastHeadline {
            list.append(Choice(id: "wait", title: "Vänta en vecka",
                               cost: "Ingen omröstning. Nästa rubrik slår ner."))
        }
        return list
    }

    public mutating func choose(_ id: String) {
        guard choices.contains(where: { $0.id == id }) else { return }
        switch id {
        case "wait":
            turns.resolve("Du väntar. Ingen omröstning den här veckan.")
        default:
            let toV = id == "promiseV"
            let r = result(promiseToV: toV)
            if !r.passed { attemptsLeft -= 1 }
            let why = toV ? "C röstade nej – C vill inte ha V i regeringen."
                          : "V röstade nej – V kräver ministerposter."
            turns.resolve(voteText(r) + " " + why, ending: attemptsLeft == 0 ? Self.extraval : nil)
        }
    }

    public mutating func proceed() { turns.proceed() }

    private func result(promiseToV: Bool) -> VoteResult {
        var votes = historicVotes(for: .andersson, after: 0)
        votes[.V] = promiseToV ? .ja : .nej
        votes[.C] = promiseToV ? .nej : .ja
        return tally(votes)
    }

    private static let extraval = Ending(
        title: "EXTRAVAL",
        text: "Du behövde både V (30) och C (25): 121 + 30 + 25 = 176. Men V krävde ministerposter och C sa nej till V i regeringen. Båda gick inte att få.",
        isExtraval: true)
}
