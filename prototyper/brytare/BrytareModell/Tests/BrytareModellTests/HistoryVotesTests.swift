import Testing
@testable import BrytareModell

@Suite("Historiska röster")
struct HistoryVotesTests {
    @Test("Andersson: 151 före rubrik 3, 121 när V åker ut, 146 när C väljer S")
    func andersson() {
        #expect(tally(historicVotes(for: .andersson, after: 0)).supportSeats == 151)
        #expect(tally(historicVotes(for: .andersson, after: 2)).supportSeats == 151)
        #expect(tally(historicVotes(for: .andersson, after: 3)).supportSeats == 121)
        #expect(tally(historicVotes(for: .andersson, after: 4)).supportSeats == 146)
        #expect(tally(historicVotes(for: .andersson, after: 6)).supportSeats == 146)
    }

    @Test("Kristersson: 111 på valnatten, 173 när SD trycker gult")
    func kristersson() {
        #expect(tally(historicVotes(for: .kristersson, after: 0)).supportSeats == 111)
        let h1 = tally(historicVotes(for: .kristersson, after: 1))
        #expect(h1.ja == 111)
        #expect(h1.gult == 62)
        #expect(h1.nej == 176)
        #expect(tally(historicVotes(for: .kristersson, after: 6)).supportSeats == 173)
    }

    @Test("Ingen kandidat går igenom någon gång i historien")
    func ingenGarIgenom() {
        for h in 0...6 {
            for c in Candidate.allCases {
                #expect(!tally(historicVotes(for: c, after: h)).passed, "\(c) efter \(h) rubriker")
            }
        }
    }

    @Test("Aktuell rubrik följer tidslinjen")
    func tidslinje() {
        #expect(headline(after: 0).id == 0)
        #expect(headline(after: 4).date == "15 nov")
        #expect(headline(after: 6).id == 6)
    }
}
