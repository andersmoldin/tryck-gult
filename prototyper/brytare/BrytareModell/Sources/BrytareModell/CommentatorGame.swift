// Perspektiv 4: du är kommentator i tv. Gissa nästa verkliga rubrik bland tre.
// Bara en av gissningarna hände på riktigt; de andra är påhittade.

public struct Prediction: Sendable {
    public let title: String
    /// Poäng om gissningen är rätt. Djärvare gissningar ger mer.
    public let points: Int
    public let isCorrect: Bool
}

public struct CommentatorStep: Sendable {
    public let options: [Prediction]
}

/// Steg k gissar rubrik k + 1.
public let commentatorSteps: [CommentatorStep] = [
    CommentatorStep(options: [
        Prediction(title: "V släpper kravet på ministerposter", points: 2, isCorrect: false),
        Prediction(title: "SD släpper kravet på ministerposter", points: 3, isCorrect: true),
        Prediction(title: "C går med i en regering med M", points: 1, isCorrect: false),
    ]),
    CommentatorStep(options: [
        Prediction(title: "C kräver ett totalpaket av båda sidor", points: 2, isCorrect: true),
        Prediction(title: "L lämnar Kristerssons sida", points: 3, isCorrect: false),
        Prediction(title: "S och M börjar förhandla med varandra", points: 3, isCorrect: false),
    ]),
    CommentatorStep(options: [
        Prediction(title: "S ger V ministerposter", points: 1, isCorrect: false),
        Prediction(title: "S vill regera med MP och C – utan V", points: 2, isCorrect: true),
        Prediction(title: "MP lämnar förhandlingarna", points: 3, isCorrect: false),
    ]),
    CommentatorStep(options: [
        Prediction(title: "C väljer Kristerssons totalpaket", points: 1, isCorrect: false),
        Prediction(title: "C ber om mer tid", points: 1, isCorrect: false),
        Prediction(title: "C väljer S:s totalpaket", points: 2, isCorrect: true),
    ]),
    CommentatorStep(options: [
        Prediction(title: "V släpper ministerkravet efter ett möte med S", points: 2, isCorrect: false),
        Prediction(title: "S och V möts – inget ändras", points: 3, isCorrect: true),
        Prediction(title: "V går över till Kristersson", points: 3, isCorrect: false),
    ]),
    CommentatorStep(options: [
        Prediction(title: "C öppnar för V i regeringen", points: 2, isCorrect: false),
        Prediction(title: "C byter sida till Kristersson", points: 2, isCorrect: false),
        Prediction(title: "C säger nej till V – även om det blir extraval", points: 3, isCorrect: true),
    ]),
]

public struct CommentatorGame: PerspectiveGame {
    public static let title = "Kommentatorn"
    public static let role = "Du kommenterar i tv. Gissa vad som händer härnäst – rätt gissning ger poäng."
    public static let tips = [
        "Läs rubriken och titta på grafen: vilka drar åt samma håll, vilka krockar?",
        "Bara en gissning hände på riktigt. Djärva gissningar ger fler poäng.",
        "Tre fel och kanalen byter kommentator.",
    ]

    private var turns = Turns()
    public private(set) var score = 0
    public private(set) var credibility = 3

    public init() {}

    public var headlineIndex: Int { turns.headlineIndex }
    public var outcome: String? { turns.outcome }
    public var ending: Ending? { turns.ending }
    public var question: String { "Vad händer härnäst?" }

    public var meters: [Meter] {
        [Meter(name: "Poäng", value: "\(score)"),
         Meter(name: "Trovärdighet", value: "\(credibility) av 3"),
         Meter(name: "Datum", value: headline.date)]
    }

    private var step: CommentatorStep? {
        turns.canChoose && headlineIndex < commentatorSteps.count ? commentatorSteps[headlineIndex] : nil
    }

    public var choices: [Choice] {
        guard let step else { return [] }
        return step.options.enumerated().map { i, p in
            Choice(id: String(i), title: p.title, cost: "Rätt: +\(p.points) p · Fel: trovärdighet −1")
        }
    }

    /// Id för den gissning som är rätt i det här steget (nil när inget kan väljas).
    var correctChoiceID: String? {
        step?.options.firstIndex(where: \.isCorrect).map(String.init)
    }

    public mutating func choose(_ id: String) {
        guard let step, let i = Int(id), step.options.indices.contains(i) else { return }
        let guess = step.options[i]
        let real = headlines[headlineIndex]
        let text: String
        if guess.isCorrect {
            score += guess.points
            text = "Rätt! +\(guess.points) poäng. \(real.title)"
        } else {
            credibility -= 1
            text = "Fel. Det som hände: \(real.title). Trovärdighet −1."
        }
        let last = headlineIndex == commentatorSteps.count - 1
        let maxScore = commentatorSteps.reduce(0) { $0 + ($1.options.first(where: \.isCorrect)?.points ?? 0) }
        let ending: Ending?
        if credibility == 0 {
            ending = Ending(title: "SPARKEN", text: "Tre felgissningar. Kanalen byter kommentator. Du fick \(score) poäng.", isExtraval: false)
        } else if last {
            ending = Ending(title: "SÄSONGEN ÄR SLUT", text: "Du fick \(score) av \(maxScore) poäng.", isExtraval: false)
        } else {
            ending = nil
        }
        turns.resolve(text, ending: ending)
    }

    public mutating func proceed() { turns.proceed() }
}
