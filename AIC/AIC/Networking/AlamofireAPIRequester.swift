//
//  AlamofireAPIRequester.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Alamofire
import os

final class AlamofireAPIRequester: APIRequester {
    private let baseURL: URL
    private let session: Session
    private let errorMapper = AFErrorMapper()

    init(baseURL: URL, session: Session = .default) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<E: Endpoint>(_ endpoint: E) async throws -> E.Response {
        let url = baseURL.appendingPathComponent(endpoint.path)
        AppLogger.network.debug("-> \(endpoint.method.rawValue, privacy: .public) \(endpoint.path, privacy: .public) \(endpoint.parameters, privacy: .public)")

        let response = await session
            .request(url, method: endpoint.method, parameters: endpoint.parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingDecodable(E.Response.self)
            .response

        switch response.result {
        case .success(let value):
            let statusCode = response.response?.statusCode ?? -1
            AppLogger.network.debug("<- \(statusCode, privacy: .public) \(endpoint.path, privacy: .public)")
            return value
        case .failure(let error):
            let statusCode = response.response?.statusCode ?? -1
            AppLogger.network.error("<- \(statusCode, privacy: .public) \(endpoint.path, privacy: .public) — \(String(describing: error), privacy: .public)")
            throw errorMapper.networkError(from: error, statusCode: response.response?.statusCode)
        }
    }
}
