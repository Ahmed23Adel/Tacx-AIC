//
//  AlamofireAPIRequester.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Alamofire

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

        let response = await session
            .request(url, method: endpoint.method, parameters: endpoint.parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingDecodable(E.Response.self)
            .response

        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            throw errorMapper.networkError(from: error, statusCode: response.response?.statusCode)
        }
    }
}
