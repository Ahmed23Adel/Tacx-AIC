//
//  LocalStoreErrorMapper.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation


nonisolated enum LocalStoreErrorMapper {
    static func fetch<T>(_ operation: () throws -> T) throws -> T {
        do {
            return try operation()
        } catch {
            throw LocalStoreError.fetchFailed(underlying: error)
        }
    }

    static func save<T>(_ operation: () throws -> T) throws -> T {
        do {
            return try operation()
        } catch {
            throw LocalStoreError.saveFailed(underlying: error)
        }
    }
}
