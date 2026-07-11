//
//  KingfisherConfiguratorTests.swift
//  AICTests
//

import XCTest
import Kingfisher
@testable import AIC

final class KingfisherConfiguratorTests: XCTestCase {

    func test_browserHeadersModifier_stampsAllThreeHeaders() throws {
        // force unwrap OK: static, known-valid URL literal
        let bare = URLRequest(url: URL(string: "https://www.artic.edu/iiif/2/abc/full/200,/0/default.jpg")!)

        let modified = try XCTUnwrap(KingfisherConfigurator.browserHeadersModifier.modified(for: bare))

        let userAgent = try XCTUnwrap(modified.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertTrue(userAgent.contains("Safari"), "User-Agent must present as a browser")
        XCTAssertTrue(userAgent.contains("iPhone"))

        let accept = try XCTUnwrap(modified.value(forHTTPHeaderField: "Accept"))
        XCTAssertTrue(accept.contains("image/"), "Accept must announce image formats")

        XCTAssertEqual(modified.value(forHTTPHeaderField: "Referer"), "https://www.artic.edu/")
    }

    func test_browserHeadersModifier_preservesOriginalURL() throws {
        // force unwrap OK: static, known-valid URL literal
        let original = URL(string: "https://www.artic.edu/iiif/2/xyz/full/843,/0/default.jpg")!

        let modified = try XCTUnwrap(KingfisherConfigurator.browserHeadersModifier.modified(for: URLRequest(url: original)))

        XCTAssertEqual(modified.url, original, "the modifier must only touch headers, never the URL")
    }

    func test_configure_registersARequestModifierGlobally() {
        let countBefore = KingfisherManager.shared.defaultOptions.count

        KingfisherConfigurator.configure()

        XCTAssertEqual(KingfisherManager.shared.defaultOptions.count, countBefore + 1)
    }
}
