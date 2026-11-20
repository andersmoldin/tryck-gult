import Testing
@testable import BrytareModell

@Suite("Kommentatorn")
struct CommentatorGameTests {
    @Test("Tre gissningar per steg, och varje gissning visar insatsen")
    func start() {
        let g = CommentatorGame()
        #expect(g.choices.count == 3)
        #expect(g.choices.allSatisfy { $0.cost.hasSuffix("· Fel: trovärdighet −1") })
        #expect(g.question == "Vad händer härnäst?")
    }

    @Test("Varje steg har exakt en rätt gissning, och den är nästa verkliga rubrik")
    func enRatt() {
        for (i, step) in commentatorSteps.enumerated() {
            #expect(step.options.filter(\.isCorrect).count == 1, "steg \(i)")
        }
        #expect(commentatorSteps.count == timelineEnd)
    }

    @Test("Rätt gissning ger poäng och nästa rubrik slår ner")
    func ratt() {
        var g = CommentatorGame()
        let right = g.choices.first { $0.id == g.correctChoiceID }!
        g.choose(right.id)
        #expect(g.score == commentatorSteps[0].options.first(where: \.isCorrect)!.points)
        #expect(g.credibility == 3)
        #expect(g.outcome?.hasPrefix("Rätt!") == true)
        g.proceed()
        #expect(g.headlineIndex == 1)
    }

    @Test("Tre fel och du får sparken")
    func sparken() {
        var g = CommentatorGame()
        for _ in 0..<3 {
            let wrong = g.choices.first { $0.id != g.correctChoiceID }!
            g.choose(wrong.id)
            #expect(g.outcome?.hasPrefix("Fel.") == true)
            g.proceed()
        }
        #expect(g.credibility == 0)
        #expect(g.ending?.title == "SPARKEN")
        #expect(g.ending?.isExtraval == false)
    }

    @Test("Sex rätt ger full pott när säsongen är slut")
    func fullPott() {
        var g = CommentatorGame()
        for _ in 0..<6 {
            g.choose(g.correctChoiceID!)
            g.proceed()
        }
        let max = commentatorSteps.reduce(0) { $0 + $1.options.first(where: \.isCorrect)!.points }
        #expect(g.score == max)
        #expect(g.ending?.title == "SÄSONGEN ÄR SLUT")
        #expect(g.ending?.text == "Du fick \(max) av \(max) poäng.")
    }
}
