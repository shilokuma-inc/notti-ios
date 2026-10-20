//
//  LinkURLTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

struct LinkURLTests {
    @Test
    func universalLinkIsAccepted() {
        #expect(LinkURL.url(from: "https://example.com/path?q=1") == URL(string: "https://example.com/path?q=1"))
        #expect(LinkURL.url(from: "http://example.com") == URL(string: "http://example.com"))
        #expect(LinkURL.problem(of: "https://example.com") == nil)
    }

    @Test
    func customSchemeIsAccepted() {
        #expect(LinkURL.url(from: "examplebank://") == URL(string: "examplebank://"))
        #expect(LinkURL.url(from: "examplebank://open/balance") == URL(string: "examplebank://open/balance"))
        #expect(LinkURL.problem(of: "examplebank://") == nil)
    }

    @Test
    func surroundingWhitespaceIsTrimmed() {
        #expect(LinkURL.normalized("  https://example.com\n") == "https://example.com")
        #expect(LinkURL.url(from: " examplebank:// ") == URL(string: "examplebank://"))
    }

    @Test
    func emptyMeansNoLink() {
        #expect(LinkURL.normalized(nil) == nil)
        #expect(LinkURL.normalized("") == nil)
        #expect(LinkURL.normalized(" \n") == nil)
        #expect(LinkURL.problem(of: " \n") == nil)
        #expect(LinkURL.url(from: " \n") == nil)
    }

    @Test
    func textWithoutSchemeCannotBeSaved() {
        #expect(LinkURL.problem(of: "example.com") == .unreadable)
        #expect(LinkURL.problem(of: "銀行のアプリ") == .unreadable)
        #expect(LinkURL.problem(of: "://example.com") == .unreadable)
        #expect(LinkURL.url(from: "example.com") == nil)
    }

    @Test
    func webURLWithoutHostCannotBeSaved() {
        #expect(LinkURL.problem(of: "https://") == .unreadable)
        #expect(LinkURL.problem(of: "http:example") == .unreadable)
    }

    @Test
    func unsafeSchemesCannotBeSaved() {
        #expect(LinkURL.problem(of: "javascript:alert(1)") == .unsupportedScheme)
        #expect(LinkURL.problem(of: "JavaScript:alert(1)") == .unsupportedScheme)
        #expect(LinkURL.problem(of: "file:///etc/hosts") == .unsupportedScheme)
        #expect(LinkURL.problem(of: "data:text/html,hello") == .unsupportedScheme)
        #expect(LinkURL.url(from: "javascript:alert(1)") == nil)
    }

    @Test
    func unsafeSchemeWithSurroundingWhitespaceCannotBeSaved() {
        #expect(LinkURL.problem(of: "  javascript:alert(1)") == .unsupportedScheme)
        #expect(LinkURL.problem(of: "javascript:alert(1)\n") == .unsupportedScheme)
        #expect(LinkURL.url(from: "  javascript:alert(1)") == nil)
    }

    @Test
    func uppercaseUnsafeSchemesCannotBeSaved() {
        #expect(LinkURL.problem(of: "FILE:///etc/hosts") == .unsupportedScheme)
        #expect(LinkURL.problem(of: "DATA:text/html,hello") == .unsupportedScheme)
    }

    @Test
    func whitespaceInsideHostCannotBeSaved() {
        #expect(LinkURL.problem(of: "https://exa mple.com") == .unreadable)
        #expect(LinkURL.problem(of: "https://exa\nmple.com") == .unreadable)
        #expect(LinkURL.problem(of: "examplebank://open balance") == .unreadable)
        #expect(LinkURL.url(from: "https://exa mple.com") == nil)
    }

    /// パスの空白は `URL(string:)` が `%20` にするので受け付ける（開けば動く）
    @Test
    func whitespaceInsidePathIsEncoded() {
        #expect(LinkURL.problem(of: "https://example.com/a b") == nil)
        #expect(LinkURL.url(from: "https://example.com/a b")?.absoluteString == "https://example.com/a%20b")
    }
}
