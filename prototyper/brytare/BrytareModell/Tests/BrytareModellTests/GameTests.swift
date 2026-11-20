import Testing
@testable import BrytareModell

@Suite("Startläget")
struct StartTests {
    @Test("Riksdagens 349 mandat fördelas enligt valresultatet")
    func mandat() {
        let seats: [P: Int] = [.S: 99, .M: 70, .SD: 62, .V: 30, .C: 25, .KD: 22, .MP: 22, .L: 19]
        for (p, n) in seats { #expect(p.seats == n) }
        #expect(P.allCases.reduce(0) { $0 + $1.seats } == 349)
    }

    @Test("Spelet börjar på valnatten utan stöd och med fyra försök")
    func start() {
        let g = Game()
        #expect(g.backing.isEmpty)
        #expect(g.backingSeats == 0)
        #expect(g.nejSeats == 349)
        #expect(!g.wouldPass)
        #expect(g.headline.id == 0)
        #expect(g.headline.date == "13 sep")
        #expect(g.attemptsLeft == 4)
        #expect(g.eventsLeft == 6)
        #expect(!g.locked)
        #expect(!g.isExtraval)
    }
}

@Suite("Brytarna")
struct ToggleTests {
    @Test("Ett påslaget parti stöder med ja, C med gult, och kan slås av igen")
    func paOchAv() {
        var g = Game()
        g.toggle(.S)
        g.toggle(.C)
        #expect(g.backing == [.S, .C])
        #expect(g.vote(of: .S) == .ja)
        #expect(g.vote(of: .C) == .gult)
        #expect(g.vote(of: .M) == .nej)
        #expect(g.jaSeats == 99)
        #expect(g.gultSeats == 25)
        #expect(g.backingSeats == 124)
        #expect(g.nejSeats == 225)
        g.toggle(.S)
        #expect(g.backing == [.C])
        #expect(g.log.first == "S av")
    }

    @Test("Krockande partier slås av, och det syns vem som slog av dem")
    func krock() {
        var g = Game()
        g.toggle(.S)
        g.toggle(.MP)
        g.toggle(.M)
        #expect(g.backing == [.M])
        #expect(g.kick.by == .M)
        #expect(g.kick.parties == [.S, .MP])   // störst först
        #expect(g.kick.serial == 1)
        #expect(g.log.first == "M på → S, MP slogs av")
    }

    @Test("Ett parti utan krockar slår inte av någon")
    func ingenKrock() {
        var g = Game()
        g.toggle(.S)
        g.toggle(.MP)
        #expect(g.backing == [.S, .MP])
        #expect(g.kick.serial == 0)
        #expect(g.log.first == "MP på")
    }
}

@Suite("Rubrikerna")
struct HeadlineTests {
    @Test("Under 150 i stöd händer inget")
    func underNara() {
        var g = Game()
        #expect(g.toggle(.S) == nil)
        #expect(g.toggle(.MP) == nil)   // 121
        #expect(!g.pendingEvent)
    }

    @Test("Når stödet 150 kommer nästa rubrik efter 0,9 s, och bara en åt gången")
    func nara() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP)
        #expect(g.toggle(.V) == .headline(after: 0.9))   // 151
        #expect(g.isNear)
        #expect(g.pendingEvent)
        #expect(g.toggle(.MP) == nil)   // redan på väg
    }

    @Test("Rubrik 1: SD trycker gult och krockar inte längre med C och L")
    func rubrik1() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP); g.toggle(.V)
        g.fireEvent()
        #expect(g.headline.id == 1)
        #expect(g.nextEvent == 1)
        #expect(!g.pendingEvent)
        #expect(g.rules.supportVote[.SD] == .gult)
        #expect(!g.rules.clash(.SD, .C))
        #expect(!g.rules.clash(.SD, .L))
        #expect(g.rules.clash(.SD, .S))
        #expect(g.backing == [.S, .MP, .V])   // ingen sparkas ut
    }

    @Test("Rubrik 2 sparkar ut C, och det syns att det var rubriken")
    func utsparkad() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP); g.toggle(.V)
        g.fireEvent()                              // rubrik 1
        g.toggle(.M)                               // slår av S, MP och V
        g.toggle(.KD)
        #expect(g.toggle(.SD) == .headline(after: 0.9))   // 154
        g.toggle(.C)                               // 179
        g.fireEvent()                              // rubrik 2
        #expect(g.headline.id == 2)
        #expect(g.backing == [.M, .KD, .SD])
        #expect(g.kick.by == nil)
        #expect(g.kick.parties == [.C])
        #expect(g.log.first == "Rubrik: C hoppade av")
    }

    @Test("Historien låter dig aldrig vinna: står majoriteten kvar kommer nästa rubrik efter 2,6 s")
    func kedja() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP); g.toggle(.V)
        g.fireEvent()                                          // 1
        g.toggle(.M); g.toggle(.KD); g.toggle(.SD); g.toggle(.L); g.toggle(.C)
        g.fireEvent()                                          // 2: C hoppar av
        #expect(g.toggle(.C) == .headline(after: 0.9))         // 198
        #expect(g.wouldPass)
        #expect(g.fireEvent() == .headline(after: 2.6))        // 3: majoriteten står kvar
        #expect(g.pendingEvent)
        #expect(g.fireEvent() == nil)                          // 4: C krockar med M, KD, L och SD
        #expect(g.headline.id == 4)
        #expect(g.backing == [.M, .KD, .SD, .L])
        #expect(!g.wouldPass)
        #expect(!g.pendingEvent)
    }

    @Test("Rubrik 3 sparkar ut V när S och V krockar")
    func rubrik3() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP); g.toggle(.V)
        g.fireEvent()                                          // 1
        g.toggle(.V); g.toggle(.V)
        g.fireEvent()                                          // 2
        g.toggle(.V); g.toggle(.V)
        g.fireEvent()                                          // 3
        #expect(g.headline.id == 3)
        #expect(g.backing == [.S, .MP])
        #expect(g.kick.parties == [.V])
        #expect(g.rules.clash(.S, .V))
    }

    @Test("Utan väntande rubrik händer inget")
    func ingenVantande() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP); g.toggle(.V)
        g.fireEvent()      // 1
        g.fireEvent()      // 2 – utan väntande rubrik händer inget
        #expect(g.headline.id == 1)
    }
}

@Suite("Omröstningen")
struct VoteTests {
    @Test("175 nej fäller kandidaten, 174 gör det inte")
    func regeln175() {
        #expect(!VoteResult(ja: 174, gult: 0, nej: 175).passed)
        #expect(VoteResult(ja: 175, gult: 0, nej: 174).passed)
        #expect(VoteResult(ja: 0, gult: 175, nej: 174).passed)   // gult räknas som stöd
    }

    @Test("En fallen omröstning kostar ett försök och låser brytarna i 2,8 s")
    func faller() {
        var g = Game()
        g.toggle(.S); g.toggle(.MP)             // 121
        #expect(g.callVote() == .finishVote(after: 2.8))
        #expect(g.lastVote == VoteResult(ja: 121, gult: 0, nej: 228))
        #expect(g.attemptsLeft == 3)
        #expect(g.locked)
        #expect(g.toggle(.C) == nil)
        #expect(!g.backing.contains(.C))        // låst
        #expect(g.callVote() == nil)            // ingen ny omröstning under låset
        #expect(g.log.first == "Omröstning: faller med 228 nej")
    }

    @Test("Efter omröstningen kommer nästa rubrik efter 0,4 s")
    func efter() {
        var g = Game()
        g.toggle(.S)
        g.callVote()
        #expect(g.finishVote() == .headline(after: 0.4))
        #expect(g.lastVote == nil)
        #expect(!g.locked)
        #expect(g.pendingEvent)
        #expect(g.callVote() == nil)            // inte medan en rubrik är på väg
    }

    @Test("Utan pågående omröstning gör finishVote inget")
    func ingenOmrostning() {
        var g = Game()
        #expect(g.finishVote() == nil)
        #expect(g.attemptsLeft == 4)
    }

    @Test("Fyra fallna omröstningar ger extraval, och då är spelet låst")
    func extraval() {
        var g = Game()
        for _ in 0..<3 {
            g.callVote()
            g.finishVote()
            g.fireEvent()
        }
        #expect(g.attemptsLeft == 1)
        #expect(g.headline.id == 3)
        #expect(g.callVote() == .finishVote(after: 2.8))
        #expect(g.attemptsLeft == 0)
        #expect(g.finishVote() == nil)
        #expect(g.isExtraval)
        #expect(g.locked)
        #expect(!g.pendingEvent)
        #expect(g.toggle(.S) == nil)
        #expect(g.backing.isEmpty)
    }
}

@Suite("Spela igen")
struct ResetTests {
    @Test("Spela igen börjar om från valnatten")
    func omstart() {
        var g = Game()
        for _ in 0..<4 { g.callVote(); g.finishVote(); g.fireEvent() }
        #expect(g.isExtraval)
        g.reset()
        #expect(!g.isExtraval)
        #expect(g.attemptsLeft == 4)
        #expect(g.headline.id == 0)
        #expect(g.eventsLeft == 6)
        #expect(g.log.isEmpty)
        #expect(g.rules.supportVote[.SD] == .ja)
        #expect(g.toggle(.S) == nil)
        #expect(g.backing == [.S])
    }
}

@Suite("Historien")
struct HistoryTests {
    /// Enkel deterministisk slump så att ett fel går att återskapa.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @Test("Ingen omröstning går igenom, hur man än spelar, och spelet slutar i extraval")
    func gårInteAttVinna() {
        for seed in 1...300 {
            var rng = Seeded(state: UInt64(seed))
            var g = Game()
            var waiting: FollowUp?
            var steps = 0
            while !g.isExtraval {
                steps += 1
                #expect(steps < 2_000, "seed \(seed) tog aldrig slut")
                if steps >= 2_000 { break }
                switch Int.random(in: 0..<10, using: &rng) {
                case 0..<6:
                    let p = P.allCases.randomElement(using: &rng)!
                    if let f = g.toggle(p) { waiting = f }
                case 6..<8:
                    if let f = g.callVote() {
                        waiting = f
                        #expect(g.lastVote?.passed == false, "seed \(seed): omröstningen gick igenom")
                    }
                default:
                    // Tiden går: appen kör det som väntar.
                    switch waiting {
                    case .headline: waiting = g.fireEvent()
                    case .finishVote: waiting = g.finishVote()
                    case nil: break
                    }
                }
            }
        }
    }
}
