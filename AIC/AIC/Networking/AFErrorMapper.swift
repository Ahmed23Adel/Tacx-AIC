//
//  AFErrorMapper.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Alamofire

/// Translates Alamofire's AFError into the app's NetworkError so no layer
/// above the requester ever sees Alamofire types. Checks run from most
/// specific to most general — reordering them can misclassify errors.
struct AFErrorMapper {
    func networkError(from error: AFError, statusCode: Int?) -> NetworkError {
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
