// Gemensamt för de fyra perspektivspelen: en sak i taget, 2–3 val per steg,
// och varje val säger vad det kostar. Tiden går framåt en rubrik per val.

public struct Choice: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    /// Vad valet kostar eller ger, i klartext.
    public let cost: String
}

public struct Meter: Equatable, Sendable {
    public let name: String
    public let value: String
    public init(name: String, value: String) { self.name = name; self.value = value }
}

public struct Ending: Equatable, Sendable {
    public let title: String
    public let text: String
    public let isExtraval: Bool
}

public protocol PerspectiveGame: Sendable {
    init()
    static var title: String { get }
    /// En rad i startmenyn: vem du är och vad du vill.
    static var role: String { get }
    /// Starttipset som visas första gången.
    static var tips: [String] { get }
    /// Antal rubriker som slagit ner (0 = valnatten).
    var headlineIndex: Int { get }
    var question: String { get }
    /// Tomt medan ett utfall visas och när spelet är slut.
    var choices: [Choice] { get }
    var meters: [Meter] { get }
    /// Vad senaste valet ledde till. Visas tills `proceed()`.
    var outcome: String? { get }
    var ending: Ending? { get }
    mutating func choose(_ id: String)
    /// Spelaren har läst utfallet: visa slutet eller gå vidare till nästa rubrik.
    mutating func proceed()
}

extension PerspectiveGame {
    public var headline: Headline { BrytareModell.headline(after: headlineIndex) }
}

/// Turordningen alla spelen delar: välj, läs utfallet, gå vidare.
struct Turns: Sendable {
    private(set) var headlineIndex = 0
    private(set) var outcome: String?
    private(set) var ending: Ending?
    private var pendingEnding: Ending?

    var canChoose: Bool { outcome == nil && ending == nil }
    var isLastHeadline: Bool { headlineIndex >= timelineEnd }

    mutating func resolve(_ text: String, ending: Ending? = nil) {
        outcome = text
        pendingEnding = ending
    }

    mutating func proceed() {
        guard outcome != nil else { return }
        outcome = nil
        if !isLastHeadline { headlineIndex += 1 }
        ending = pendingEnding
    }
}

/// "151 av 175" – hur nära 175 i stöd ett utfall är.
func supportText(_ r: VoteResult) -> String { "\(r.supportSeats) av \(majority)" }

func voteText(_ r: VoteResult) -> String {
    r.passed ? "Omröstningen går igenom: \(r.supportSeats) stöd, \(r.nej) nej."
             : "Omröstningen faller: \(r.supportSeats) stöd, \(r.nej) nej."
}
