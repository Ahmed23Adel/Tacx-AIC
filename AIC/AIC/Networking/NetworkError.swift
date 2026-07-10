//
//  NetworkError.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case transport(URLError)
    case serverError(statusCode: Int)
    case decodingFailed(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The request URL could not be built.")
        case .transport(let urlError):
            return urlError.localizedDescription
        case .serverError(let statusCode):
            return String(localized: "The server responded with an error (code \(statusCode)).")
        case .decodingFailed:
            return String(localized: "The server response could not be read.")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
