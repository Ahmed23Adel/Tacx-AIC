//
//  HTMLTextTests.swift
//  AICTests
//
//  The HTML → AttributedString renderer: structure preserved, fonts
//  normalized to the body text style with only bold/italic surviving.
//  The parser is injectable, so the (practically-unreachable) importer
//  failure path is covered by stubbing a throwing parse step.
//

import XCTest
import UIKit
@testable import AIC

final class HTMLTextTests: XCTestCase {

    private func firstFont(in attributed: AttributedString) -> UIFont? {
        for run in attributed.runs {
            if let font = run.uiKit.font { return font }
        }
        return nil
    }

    private func font(forSubstring substring: String, in attributed: AttributedString) -> UIFont? {
        guard let range = attributed.range(of: substring) else { return nil }
        return attributed[range].runs.first?.uiKit.font
    }

    // MARK: - Text content

    func test_plainText_passesThrough() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "Just plain text"))
        XCTAssertEqual(String(result.characters), "Just plain text")
    }

    func test_paragraphTags_becomeTextWithoutTags() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "<p>Hello world</p>"))
        XCTAssertEqual(String(result.characters), "Hello world")
    }

    func test_trailingNewlinesFromBlockTags_areTrimmed() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "<p>One</p><p>Two</p>"))
        XCTAssertFalse(String(result.characters).hasSuffix("\n"), "block-tag trailing newlines must be trimmed")
    }

    func test_htmlEntities_areDecoded() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "Wood&#39;s &amp; more"))
        XCTAssertEqual(String(result.characters), "Wood's & more")
    }

    // MARK: - Traits preserved

    func test_strongTag_rendersBold() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "normal <strong>bold</strong>"))

        let boldFont = try XCTUnwrap(font(forSubstring: "bold", in: result))
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.traitBold))

        let normalFont = try XCTUnwrap(font(forSubstring: "normal", in: result))
        XCTAssertFalse(normalFont.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func test_emTag_rendersItalic() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "normal <em>italic</em>"))

        let italicFont = try XCTUnwrap(font(forSubstring: "italic", in: result))
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_linkTag_preservesLinkAttribute() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(
            fromHTML: #"see <a href="https://www.artic.edu/artists/1">the artist</a>"#
        ))

        let linkRange = try XCTUnwrap(result.range(of: "the artist"))
        XCTAssertEqual(result[linkRange].runs.first?.link?.absoluteString, "https://www.artic.edu/artists/1")
    }

    // MARK: - Font normalization (Dynamic Type / dark mode survival)

    func test_fonts_areRefontedToBodyStyleNotTimes() throws {
        let result = try XCTUnwrap(HTMLText.attributedString(fromHTML: "<p>Some text</p>"))

        let font = try XCTUnwrap(firstFont(in: result))
        XCTAssertFalse(font.fontName.contains("Times"), "importer's Times New Roman must be replaced")
        XCTAssertEqual(font.pointSize, UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    // MARK: - Parse failure (injected)

    private struct StubParseError: Error {}

    func test_attributedString_whenParserThrows_returnsNil() {
        let result = HTMLText.attributedString(fromHTML: "anything") { _ in
            throw StubParseError()
        }
        XCTAssertNil(result)
    }

    // MARK: - bodyFont trait paths

    func test_bodyFont_withNilFont_returnsBodyWithoutTraits() {
        let font = HTMLText.bodyFont(preserving: nil)

        XCTAssertEqual(font.pointSize, UIFont.preferredFont(forTextStyle: .body).pointSize)
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_bodyFont_withPlainFont_returnsBodyWithoutTraits() {
        // A font carrying no bold/italic traits: the intersection is empty,
        // so the guard's else path (return body) is taken.
        let plain = UIFont.systemFont(ofSize: 12)

        let font = HTMLText.bodyFont(preserving: plain)

        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func test_bodyFont_withBoldFont_preservesBoldAtBodySize() {
        let bold = UIFont.boldSystemFont(ofSize: 12)

        let font = HTMLText.bodyFont(preserving: bold)

        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertEqual(font.pointSize, UIFont.preferredFont(forTextStyle: .body).pointSize)
    }

    func test_bodyFont_withItalicFont_preservesItalic() throws {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let italicDescriptor = try XCTUnwrap(body.fontDescriptor.withSymbolicTraits(.traitItalic))
        let italic = UIFont(descriptor: italicDescriptor, size: 0)

        let font = HTMLText.bodyFont(preserving: italic)

        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }
}
