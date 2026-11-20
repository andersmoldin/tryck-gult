// Rubrikerna: verkliga händelser som ändrar kraven.

public struct Headline: Identifiable, Sendable {
    public let id: Int
    public let date: String
    public let title: String
    public let quote: String
    public let source: String
    public let effect: String
    /// Partier som rubriken sparkar ut ur stödet.
    public let ejects: [P]
    let apply: @Sendable (inout Rules) -> Void
}

public let startHeadline = Headline(
    id: 0, date: "13 sep",
    title: "Valresultatet: S+V+MP+C 176 – M+KD+L+SD 173",
    quote: "Ingen sida har egen majoritet. C blir tungan på vågen.",
    source: "val.se (fastställt 19 sep)",
    effect: "Få ihop minst 175 som trycker ja eller gult.",
    ejects: [], apply: { _ in })

// Sex verkliga händelser ur ärende #2 (numren inom parentes är punkterna i researchens kronologi).
public let headlines: [Headline] = [
    Headline(id: 1, date: "6 nov",
             title: "SD släpper kravet på ministerposter (#14)",
             quote: "Åkesson: SD tolererar Kristersson – ”vi kan närsomhelst spela det kortet”.",
             source: "SVT 6 nov",
             effect: "SD trycker gult i stället för att kräva ministrar. SD krockar inte längre med C och L.",
             ejects: [],
             apply: { r in
                 r.pairs.remove(Pair(.SD, .C))
                 r.pairs.remove(Pair(.SD, .L))
                 r.demand[.SD] = "Kristersson – SD avstår (gult)"
                 r.supportVote[.SD] = .gult
             }),
    Headline(id: 2, date: "6 nov",
             title: "C kräver ett ”totalpaket” av både Andersson och Kristersson (#15)",
             quote: "Thand Ringqvist: ”Vilken politik vill ni genomföra för Sverige?” Deadline fredag.",
             source: "Nyhetsbyrån Direkt 6 nov",
             effect: "C hoppar av och väntar på bästa paketet.",
             ejects: [.C],
             apply: { r in
                 r.demand[.C] = "Bästa totalpaketet – inget V"
             }),
    Headline(id: 3, date: "8 nov",
             title: "S vill regera med MP och C – V utanför (#19–20)",
             quote: "V: regeringskravet ”går inte att påverka”.",
             source: "SVT 8 nov, Nyhetsbyrån Direkt 9 nov",
             effect: "S och V krockar nu: V åker ut ur allt där S är med.",
             ejects: [.V],
             apply: { r in
                 r.pairs.insert(Pair(.S, .V))
                 r.allies.remove(Pair(.S, .V))
                 r.demand[.S] = "S + MP + C – V utanför"
                 r.demand[.V] = "Ministerposter – annars nej"
             }),
    Headline(id: 4, date: "15 nov",
             title: "C väljer S:s totalpaket (#32)",
             quote: "C: ”Socialdemokraternas alternativ är det vi väljer att förhandla vidare om.”",
             source: "SVT 15 nov",
             effect: "C krockar nu med M, KD, L och SD – och kräver fortfarande att V släpper ministerkravet.",
             ejects: [.C],
             apply: { r in
                 for p in kristerssonSide { r.pairs.insert(Pair(.C, p)) }
                 r.allies.insert(Pair(.C, .S))
                 r.allies.insert(Pair(.C, .MP))
                 r.demand[.C] = "S:s totalpaket – utan V i regeringen"
                 r.supportVote[.C] = .ja
             }),
    Headline(id: 5, date: "16 nov",
             title: "Två timmars S–V-möte om ministerkravet (#34)",
             quote: "Gabrielsson (V) efteråt: ”samma besked som tidigare”.",
             source: "SVT 16 nov",
             effect: "Inget ändras. V kräver fortfarande ministerposter.",
             ejects: [],
             apply: { r in
                 r.demand[.V] = "Ministerposter – ”samma besked som tidigare”"
             }),
    Headline(id: 6, date: "18 nov",
             title: "C: nej till V i regeringen – även om alternativet är extraval (#37)",
             quote: "Ådahl (C): satsar ”med full kraft på Magdalena Anderssons regering”.",
             source: "SVT 18 nov",
             effect: "Låst: V och C går inte att ha samtidigt.",
             ejects: [],
             apply: { r in
                 r.demand[.C] = "Nej till V – även inför extraval"
             }),
]
