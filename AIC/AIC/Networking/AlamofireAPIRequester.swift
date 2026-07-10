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
            throw map(error, statusCode: response.response?.statusCode)
        }
    }

    private func map(_ error: AFError, statusCode: Int?) -> NetworkError {
        if case .responseValidationFailed = error, let statusCode {
            return .serverError(statusCode: statusCode)
        }
        if error.isResponseSerializationError {
            return .decodingFailed(error)
        }
        if let urlError = error.underlyingError as? URLError {
            return .transport(urlError)
        }
        if case .invalidURL = error {
            return .invalidURL
        }
        return .unknown(error)
    }
}
