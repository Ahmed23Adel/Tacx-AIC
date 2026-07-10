//
//  ArtworkRepositoryTests.swift
//  AICTests
//
//  Repository contract: correct endpoints built, envelopes unwrapped,
//  constants applied, errors propagated untouched.
//

import XCTest
@testable import AIC

final class ArtworkRepositoryTests: XCTestCase {

    private var sut: ArtworkRepository!
    private var mockRequester: MockAPIRequester!

    override func setUp() {
        super.setUp()
        mockRequester = MockAPIRequester()
        sut = ArtworkRepository(apiRequester: mockRequester)
    }

    override func tearDown() {
        sut = nil
        mockRequester = nil
        super.tearDown()
    }

    // MARK: searchArtworks

    func test_searchArtworks_onSuccess_returnsArtworksAndPagination() async throws {
        let expected = Fixtures.searchResponse(
            artworks: [Fixtures.artwork(id: 1), Fixtures.artwork(id: 2)],
            pagination: Fixtures.pagination(total: 2, totalPages: 1)
        )
        mockRequester.stubbedResult = .success(expected)

        let (artworks, pagination) = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(artworks.map(\.id), [1, 2])
        XCTAssertEqual(pagination.total, 2)
        XCTAssertEqual(pagination.totalPages, 1)
    }

    func test_searchArtworks_buildsSearchEndpointWithGivenPage() async throws {
        mockRequester.stubbedResult = .success(Fixtures.searchResponse())

        _ = try await sut.searchArtworks(page: 5)

        XCTAssertEqual(mockRequester.sendCallCount, 1)
        XCTAssertEqual(mockRequester.sentPaths, ["/artworks/search"])
        XCTAssertEqual(mockRequester.sentParameters[0]["page"], "5")
    }

    func test_searchArtworks_usesFeaturedArtistConstant() async throws {
        mockRequester.stubbedResult = .success(Fixtures.searchResponse())

        _ = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(
            mockRequester.sentParameters[0]["query[match_phrase][artist_title]"],
            AppConstants.Artist.featured
        )
    }

    func test_searchArtworks_usesPageLimitConstant() async throws {
        mockRequester.stubbedResult = .success(Fixtures.searchResponse())

        _ = try await sut.searchArtworks(page: 1)

        XCTAssertEqual(mockRequester.sentParameters[0]["limit"], "\(AppConstants.API.pageLimit)")
        XCTAssertEqual(AppConstants.API.pageLimit, 20)
    }

    func test_searchArtworks_onFailure_propagatesErrorUnchanged() async {
        mockRequester.stubbedResult = .failure(NetworkError.serverError(statusCode: 500))

        do {
            _ = try await sut.searchArtworks(page: 1)
            XCTFail("Expected error to propagate")
        } catch let error as NetworkError {
            guard case .serverError(let statusCode) = error else {
                return XCTFail("Expected .serverError, got \(error)")
            }
            XCTAssertEqual(statusCode, 500)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: artworkDetail

    func test_artworkDetail_onSuccess_unwrapsDataEnvelope() async throws {
        let expected = Fixtures.artworkDetail(id: 95998)
        mockRequester.stubbedResult = .success(Fixtures.detailResponse(detail: expected))

        let detail = try await sut.artworkDetail(id: 95998)

        XCTAssertEqual(detail.id, 95998)
        XCTAssertEqual(detail.title, expected.title)
    }

    func test_artworkDetail_buildsDetailEndpointWithGivenId() async throws {
        mockRequester.stubbedResult = .success(Fixtures.detailResponse())

        _ = try await sut.artworkDetail(id: 12345)

        XCTAssertEqual(mockRequester.sentPaths, ["/artworks/12345"])
    }

    func test_artworkDetail_onFailure_propagatesErrorUnchanged() async {
        mockRequester.stubbedResult = .failure(NetworkError.transport(URLError(.timedOut)))

        do {
            _ = try await sut.artworkDetail(id: 1)
            XCTFail("Expected error to propagate")
        } catch let error as NetworkError {
            guard case .transport(let urlError) = error else {
                return XCTFail("Expected .transport, got \(error)")
            }
            XCTAssertEqual(urlError.code, .timedOut)
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: Memory

    func test_repository_deallocates_noMemoryLeak() {
        var repository: ArtworkRepository? = ArtworkRepository(apiRequester: MockAPIRequester())
        weak var weakReference = repository

        repository = nil

        XCTAssertNil(weakReference, "Potential memory leak: ArtworkRepository not deallocated")
    }
}
