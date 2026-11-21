// Byggstenar för talmannens skärm: valkort, mätare, effektruta och slut.

public struct Choice: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    /// En kort, torr rad (spelledarens röst). Hör till valet, aldrig till rubriken. Följderna syns först efteråt.
    public let quip: String
    /// Bild i asset-katalogen (t.ex. en stämpel), om kortet har en.
    public var icon: String? = nil
    /// Vad knappen gör och kostar, före valet (t.ex. "▼ Vänster ca −8 · 1 spaltmeter").
    public var preview: String? = nil
}

public struct Meter: Equatable, Sendable {
    public let name: String
    public let value: String
    /// En rad som förklarar vad mätaren betyder.
    public let caption: String?
    public init(name: String, value: String, caption: String? = nil) {
        self.name = name; self.value = value; self.caption = caption
    }
}

public struct Ending: Equatable, Sendable {
    public let title: String
    public let text: String
    public let isExtraval: Bool
    /// En liten rad längst ner (t.ex. brasklappen).
    public var footnote: String? = nil
}

/// Vad ett val ledde till, för effektrutan som visas direkt efter valet.
public struct Effect: Equatable, Sendable {
    public enum Tone: Sendable { case bad, neutral, good }
    public let title: String
    public let tone: Tone
    /// Korta rader om vad som ändrades, t.ex. "Tålamod −1".
    public let chips: [String]
    /// Varför det blev så, i en mening.
    public var reason: String? = nil
}

func voteText(_ r: VoteResult) -> String {
    r.passed ? "Omröstningen går igenom: \(r.supportSeats) stöd, \(r.nej) nej."
             : "Omröstningen faller: \(r.supportSeats) stöd, \(r.nej) nej."
}
