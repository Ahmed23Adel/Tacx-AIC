//
//  AlamofireAPIRequesterIntegrationTests.swift
//  AICTests
//
//  Full-stack integration: real Alamofire Session + real URLSession machinery,
//  with the wire replaced by MockURLProtocol. Deterministic, no network.
//  Exhaustive error-branch coverage lives in AFErrorMapperTests.
//

import XCTest
import Alamofire
@testable import AIC

final class AlamofireAPIRequesterIntegrationTests: XCTestCase {

    private var sut: AlamofireAPIRequester!

    override func setUp() {
        super.setUp()
        // force unwrap OK: static, known-valid URL literal
        sut = AlamofireAPIRequester(
            baseURL: URL(string: "https://unit-test.invalid/api/v1")!,
            session: .stubbed()
        )
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: Helpers

    private func stub(statusCode: Int, data: Data) {
        MockURLProtocol.requestHandler = { request in
            // force unwrap OK: request.url is always set for requests Alamofire builds
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
    }

    // MARK: Success path

    func test_send_searchEndpoint_with200AndValidJSON_returnsDecodedResponse() async throws {
        stub(statusCode: 200, data: Fixtures.searchJSON)

        let response = try await sut.send(SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 1))

        XCTAssertEqual(response.data.count, 2)
        XCTAssertEqual(response.pagination.total, 247)
    }

    func test_send_detailEndpoint_with200AndValidJSON_returnsDecodedResponse() async throws {
        stub(statusCode: 200, data: Fixtures.detailJSON)

        let response = try await sut.send(ArtworkDetailEndpoint(id: 95998))

        XCTAssertEqual(response.data.id, 95998)
        XCTAssertEqual(response.data.artistDisplay, "Rembrandt van Rijn (Dutch, 1606-1669)")
    }

    func test_send_buildsURLFromBaseURLPathAndEncodedParameters() async throws {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url
            // force unwrap OK: request.url is always set for requests Alamofire builds
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Fixtures.searchJSON)
        }

        _ = try await sut.send(SearchArtworksEndpoint(artistTitle: "Rembrandt van Rijn", page: 2))

        let url = try XCTUnwrap(capturedURL)
        XCTAssertEqual(url.host, "unit-test.invalid")
        XCTAssertEqual(url.path, "/api/v1/artworks/search")

        let query = try XCTUnwrap(url.query)
        // Brackets and spaces must be percent-encoded exactly once
        XCTAssertTrue(query.contains("query%5Bmatch_phrase%5D%5Bartist_title%5D=Rembrandt%20van%20Rijn")
                   || query.contains("query%5Bmatch_phrase%5D%5Bartist_title%5D=Rembrandt+van+Rijn"),
                      "Unexpected artist encoding in: \(query)")
        XCTAssertTrue(query.contains("page=2"))
        XCTAssertTrue(query.contains("limit=20"))
    }

    // MARK: Error mapping through the full stack

    func test_send_with404_throwsServerErrorWithStatusCode() async {
        stub(statusCode: 404, data: Data())

        do {
            _ = try await sut.send(ArtworkDetailEndpoint(id: 0))
            XCTFail("Expected NetworkError.serverError")
        } catch let error as NetworkError {
            guard case .serverError(let statusCode) = error else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(statusCode, 404)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_send_with500_throwsServerErrorWithStatusCode() async {
        stub(statusCode: 500, data: Data())

        do {
            _ = try await sut.send(SearchArtworksEndpoint(artistTitle: "X", page: 1))
            XCTFail("Expected NetworkError.serverError")
        } catch let error as NetworkError {
            guard case .serverError(let statusCode) = error else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_send_with200AndMalformedJSON_throwsDecodingFailed() async {
        stub(statusCode: 200, data: Fixtures.notJSON)

        do {
            _ = try await sut.send(SearchArtworksEndpoint(artistTitle: "X", page: 1))
            XCTFail("Expected NetworkError.decodingFailed")
        } catch let error as NetworkError {
            guard case .decodingFailed = error else {
                return XCTFail("Expected .decodingFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    func test_send_whenOffline_throwsTransportWithURLError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await sut.send(SearchArtworksEndpoint(artistTitle: "X", page: 1))
            XCTFail("Expected NetworkError.transport")
        } catch let error as NetworkError {
            guard case .transport(let urlError) = error else {
                return XCTFail("Expected .transport, got \(error)")
            }
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: Memory

    func test_requester_deallocates_noMemoryLeak() {
        // force unwrap OK: static, known-valid URL literal
        var requester: AlamofireAPIRequester? = AlamofireAPIRequester(
            baseURL: URL(string: "https://unit-test.invalid")!,
            session: .stubbed()
        )
        weak var weakReference = requester

        requester = nil

        XCTAssertNil(weakReference, "Potential memory leak: AlamofireAPIRequester not deallocated")
    }
}
