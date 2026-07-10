//
//  SwiftDataArtworkLocalStore.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import SwiftData

actor SwiftDataArtworkLocalStore: ModelActor, SearchResultsLocalStoreProtocol, ArtworkDetailLocalStoreProtocol {

    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    private let dateProvider: DateProviding

    init(modelContainer: ModelContainer, dateProvider: DateProviding = SystemDateProvider()) {
        self.dateProvider = dateProvider
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
    }

    // MARK: - SearchResultsLocalStoreProtocol

    func fetchPage(_ pageNumber: Int) async throws -> CachedSearchPage? {
        guard let entity = try pageEntity(pageNumber) else { return nil }
        let artworks = entity.artworks
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { $0.toDomain() }
        return CachedSearchPage(pageNumber: entity.pageNumber, artworks: artworks, insertedAt: entity.insertedAt)
    }

    func savePage(_ pageNumber: Int, artworks: [Artwork]) async throws {
        if let existing = try pageEntity(pageNumber) {
            modelContext.delete(existing) // cascade removes its artworks
        }

        let page = CachedSearchPageEntity(pageNumber: pageNumber, insertedAt: dateProvider.now)
        modelContext.insert(page)
        for (index, artwork) in artworks.enumerated() {
            modelContext.insert(CachedArtworkEntity(artwork: artwork, sortIndex: index, page: page))
        }
        try persist()
    }

    func deletePage(_ pageNumber: Int) async throws {
        guard let entity = try pageEntity(pageNumber) else { return }
        modelContext.delete(entity)
        try persist()
    }

    // MARK: - ArtworkDetailLocalStoreProtocol

    func fetchDetail(id: Int) async throws -> CachedArtworkDetail? {
        guard let entity = try detailEntity(id) else { return nil }
        return CachedArtworkDetail(detail: entity.toDomain(), insertedAt: entity.insertedAt)
    }

    func saveDetail(_ detail: ArtworkDetail) async throws {
        if let existing = try detailEntity(detail.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(CachedArtworkDetailEntity(detail: detail, insertedAt: dateProvider.now))
        try persist()
    }

    func deleteDetail(id: Int) async throws {
        guard let entity = try detailEntity(id) else { return }
        modelContext.delete(entity)
        try persist()
    }

    // MARK: - Fetch helpers

    private func pageEntity(_ pageNumber: Int) throws -> CachedSearchPageEntity? {
        var descriptor = FetchDescriptor<CachedSearchPageEntity>(
            predicate: #Predicate { $0.pageNumber == pageNumber }
        )
        descriptor.fetchLimit = 1
        return try fetchFirst(descriptor)
    }

    private func detailEntity(_ id: Int) throws -> CachedArtworkDetailEntity? {
        var descriptor = FetchDescriptor<CachedArtworkDetailEntity>(
            predicate: #Predicate { $0.artworkId == id }
        )
        descriptor.fetchLimit = 1
        return try fetchFirst(descriptor)
    }

    // MARK: - Error boundary

    private func fetchFirst<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            throw LocalStoreError.fetchFailed(underlying: error)
        }
    }

    private func persist() throws {
        do {
            try modelContext.save()
        } catch {
            throw LocalStoreError.saveFailed(underlying: error)
        }
    }
}
