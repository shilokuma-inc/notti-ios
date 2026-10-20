//
//  LinkCandidateTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct LinkCandidateTests {
    @Test(arguments: LinkCandidate.all)
    func candidateURLCanBeOpened(_ candidate: LinkCandidate) {
        #expect(LinkURL.problem(of: candidate.url) == nil)
        #expect(LinkURL.url(from: candidate.url) != nil)
        // 保存する形（前後の空白なし）で書いておかないと、保存した URL と一致しない
        #expect(LinkURL.normalized(candidate.url) == candidate.url)
    }

    @Test(arguments: LinkCandidate.all)
    func candidateHasNameURLAndOfficialSource(_ candidate: LinkCandidate) {
        #expect(!candidate.id.isEmpty)
        #expect(!candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!candidate.url.isEmpty)
        #expect(candidate.source.hasPrefix("https://"))
        #expect(URL(string: candidate.source)?.host() != nil)
    }

    @Test
    func idsAndURLsAreUnique() {
        let ids = LinkCandidate.all.map(\.id)
        let urls = LinkCandidate.all.map(\.url)
        #expect(Set(ids).count == ids.count)
        #expect(Set(urls).count == urls.count)
    }

    @Test
    func matchingFindsCandidateWithSameURL() {
        #expect(LinkCandidate.matching("https://line.me/R/nv/wallet") == LinkCandidate.line)
    }

    @Test
    func matchingIgnoresSurroundingWhitespace() {
        #expect(LinkCandidate.matching("  https://line.me/R/nv/wallet\n") == LinkCandidate.line)
    }

    @Test
    func matchingReturnsNilForOtherURL() {
        #expect(LinkCandidate.matching("https://example.com") == nil)
        #expect(LinkCandidate.matching("https://line.me/R/nv/chat") == nil)
    }

    @Test
    func matchingReturnsNilWithoutLink() {
        #expect(LinkCandidate.matching(nil) == nil)
        #expect(LinkCandidate.matching("") == nil)
        #expect(LinkCandidate.matching(" \n") == nil)
    }

    @Test
    func matchingLooksOnlyAtGivenCandidates() {
        let candidate = LinkCandidate(id: "example", name: "例", url: "examplebank://", source: "https://example.com")
        #expect(LinkCandidate.matching(" examplebank:// ", in: [candidate]) == candidate)
        #expect(LinkCandidate.matching(LinkCandidate.line.url, in: [candidate]) == nil)
        #expect(LinkCandidate.matching(LinkCandidate.line.url, in: []) == nil)
    }
}
