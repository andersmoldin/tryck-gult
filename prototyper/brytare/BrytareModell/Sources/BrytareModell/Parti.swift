// PROTOTYP för ärende #4 (talmannen). Slängkod – inte produktionskod.
// Mandat och händelser kommer från researchen i ärende #2 (kommentaren "Resolution (research)").

/// Ett riksdagsparti.
public enum P: String, CaseIterable, Identifiable, Hashable, Sendable {
    case V, S, MP, C, L, KD, M, SD
    public var id: String { rawValue }
}

/// Namn, mandat och färger. Färgerna är RGB-hex så att modellen slipper SwiftUI.
public struct PartyInfo: Sendable {
    public let name: String
    public let seats: Int
    public let color: UInt32
    public let textColor: UInt32
}

extension P {
    public var info: PartyInfo {
        switch self {
        case .S:  return PartyInfo(name: "Socialdemokraterna", seats: 99, color: 0xE8112D, textColor: 0xFFFFFF)
        case .M:  return PartyInfo(name: "Moderaterna", seats: 70, color: 0x52BDEC, textColor: 0x000000)
        case .SD: return PartyInfo(name: "Sverigedemokraterna", seats: 62, color: 0xDDDD00, textColor: 0x000000)
        case .V:  return PartyInfo(name: "Vänsterpartiet", seats: 30, color: 0xAF0000, textColor: 0xFFFFFF)
        case .C:  return PartyInfo(name: "Centerpartiet", seats: 25, color: 0x009933, textColor: 0xFFFFFF)
        case .KD: return PartyInfo(name: "Kristdemokraterna", seats: 22, color: 0x231977, textColor: 0xFFFFFF)
        case .MP: return PartyInfo(name: "Miljöpartiet", seats: 22, color: 0x83CF39, textColor: 0x000000)
        case .L:  return PartyInfo(name: "Liberalerna", seats: 19, color: 0x006AB3, textColor: 0xFFFFFF)
        }
    }
    public var seats: Int { info.seats }
}

/// Så många nej fäller en statsministerkandidat (negativ parlamentarism).
public let majority = 175
/// Ordningen från vänster till höger.
public let leftToRight: [P] = [.V, .S, .MP, .C, .L, .KD, .M, .SD]

/// Två partier. Ordningen spelar ingen roll.
public struct Pair: Hashable, Sendable {
    public let a: P
    public let b: P
    public init(_ x: P, _ y: P) {
        if x.rawValue < y.rawValue { a = x; b = y } else { a = y; b = x }
    }
}

public enum Vote: Sendable { case ja, gult, nej }
