// Perspektiv 3: du leder C, vågmästarpartiet. Båda sidor uppvaktar dig.
// Extraval går att undvika – men bara genom att bryta ett löfte.

public struct KingmakerGame: PerspectiveGame {
    public static let title = "Vågmästarpartiet"
    public static let role = "Du leder C. Båda sidor uppvaktar dig. Släpp fram någon – men till vilket pris?"
    public static let tips = [
        "Med dina 25 mandat kan båda sidor nå 175.",
        "Du har lovat väljarna två saker: inget V i regeringen och inget SD-inflytande. Varje knapp visar om ett löfte bryts.",
        "Ställ krav för att vinna mer – men fyra fallna omröstningar ger extraval.",
    ]

    private var turns = Turns()
    public private(set) var attemptsLeft = 4
    public private(set) var promisesKept = 2
    public private(set) var demandsWon = 0

    public init() {}

    public var headlineIndex: Int { turns.headlineIndex }
    public var outcome: String? { turns.outcome }
    public var ending: Ending? { turns.ending }
    public var question: String { "Vem släpper du fram?" }

    public var meters: [Meter] {
        [Meter(name: "Löften hållna", value: "\(promisesKept) av 2"),
         Meter(name: "Krav vunna", value: "\(demandsWon)"),
         Meter(name: "Försök kvar", value: "\(attemptsLeft) av 4")]
    }

    public var choices: [Choice] {
        guard turns.canChoose else { return [] }
        var list = Candidate.allCases.map { c in
            let (r, broken, _) = release(c)
            let cost: String
            if r.passed {
                cost = supportText(r) + " – går igenom" + (broken.map { ", men \($0.cost): bryter löftet om \($0.promise)" } ?? "")
            } else {
                cost = supportText(r) + " – faller, kostar ett försök"
            }
            return Choice(id: c.rawValue, title: "Släpp fram \(c.name)", cost: cost)
        }
        if !turns.isLastHeadline {
            list.append(Choice(id: "demand", title: "Kräv mer – vänta på ett bättre bud",
                               cost: "Ingen omröstning. Krav +1. Buden kan ändras när nästa rubrik slår ner."))
        }
        return list
    }

    public mutating func choose(_ id: String) {
        guard choices.contains(where: { $0.id == id }) else { return }
        if id == "demand" {
            demandsWon += 1
            turns.resolve("Båda sidor får höja sina bud. Du har vunnit \(demandsWon) krav.")
            return
        }
        guard let c = Candidate(rawValue: id) else { return }
        let (r, broken, whyFailed) = release(c)
        if r.passed {
            var text = "\(c.name) blev statsminister. Du fick igenom \(demandsWon) krav"
            if let broken {
                promisesKept -= 1
                text += " – men bröt löftet om \(broken.promise). Löften hållna: \(promisesKept) av 2."
            } else {
                text += "."
            }
            turns.resolve(voteText(r), ending: Ending(title: "REGERING BILDAD", text: text, isExtraval: false))
            return
        }
        attemptsLeft -= 1
        let extraval = Ending(
            title: "EXTRAVAL",
            text: "Du höll alla löften och fick igenom \(demandsWon) krav – men ingen fick ihop 175.",
            isExtraval: true)
        turns.resolve(voteText(r) + " " + whyFailed,
                      ending: attemptsLeft == 0 ? extraval : nil)
    }

    public mutating func proceed() { turns.proceed() }

    /// Ett löfte som bryts om C släpper fram kandidaten.
    private struct BrokenPromise {
        let promise: String
        let cost: String
    }

    /// Hur omröstningen går om C röstar ja, vilket löfte det i så fall bryter,
    /// och vem som fäller kandidaten om den faller.
    private func release(_ c: Candidate) -> (VoteResult, BrokenPromise?, whyFailed: String) {
        var votes = historicVotes(for: c, after: headlineIndex)
        votes[.C] = .ja
        switch c {
        case .andersson:
            let vInside = votes[.V] == .ja
            return (tally(votes),
                    vInside ? BrokenPromise(promise: "inget V i regeringen", cost: "V kommer in i regeringen") : nil,
                    "V röstade nej – V kräver ministerposter.")
        case .kristersson:
            let sdPromise = "inget SD-inflytande"
            if headlineIndex == 0 {
                // Före rubrik 1 kräver SD ministrar; då vill L inte vara med.
                votes[.SD] = .ja
                votes[.L] = .nej
                return (tally(votes), BrokenPromise(promise: sdPromise, cost: "SD får ministrar"),
                        "L röstade nej – L vill inte ha SD-ministrar.")
            }
            return (tally(votes), BrokenPromise(promise: sdPromise, cost: "SD släpper fram regeringen"),
                    "S, V och MP röstade nej.")
        }
    }
}
