//
//  APIRequester.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

protocol APIRequester {
    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response
}
