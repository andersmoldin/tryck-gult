// Rubrikerna: verkliga händelser, tidslinjens ankare.

public struct Headline: Identifiable, Sendable {
    public let id: Int
    public let date: String
    public let title: String
    public let quote: String
    public let source: String
}

public let startHeadline = Headline(
    id: 0, date: "13 sep",
    title: "Valresultatet: S+V+MP+C 176 – M+KD+L+SD 173",
    quote: "Ingen sida har egen majoritet. C blir tungan på vågen.",
    source: "val.se (fastställt 19 sep)")

// Sex verkliga händelser ur ärende #2 (numren inom parentes är punkterna i researchens kronologi).
public let headlines: [Headline] = [
    Headline(id: 1, date: "6 nov",
             title: "SD släpper kravet på ministerposter (#14)",
             quote: "Åkesson: SD tolererar Kristersson – ”vi kan närsomhelst spela det kortet”.",
             source: "SVT 6 nov"),
    Headline(id: 2, date: "6 nov",
             title: "C kräver ett ”totalpaket” av både Andersson och Kristersson (#15)",
             quote: "Thand Ringqvist: ”Vilken politik vill ni genomföra för Sverige?” Deadline fredag.",
             source: "Nyhetsbyrån Direkt 6 nov"),
    Headline(id: 3, date: "8 nov",
             title: "S vill regera med MP och C – V utanför (#19–20)",
             quote: "V: regeringskravet ”går inte att påverka”.",
             source: "SVT 8 nov, Nyhetsbyrån Direkt 9 nov"),
    Headline(id: 4, date: "15 nov",
             title: "C väljer S:s totalpaket (#32)",
             quote: "C: ”Socialdemokraternas alternativ är det vi väljer att förhandla vidare om.”",
             source: "SVT 15 nov"),
    Headline(id: 5, date: "16 nov",
             title: "Två timmars S–V-möte om ministerkravet (#34)",
             quote: "Gabrielsson (V) efteråt: ”samma besked som tidigare”.",
             source: "SVT 16 nov"),
    Headline(id: 6, date: "18 nov",
             title: "C: nej till V i regeringen – även om alternativet är extraval (#37)",
             quote: "Ådahl (C): satsar ”med full kraft på Magdalena Anderssons regering”.",
             source: "SVT 18 nov"),
]
