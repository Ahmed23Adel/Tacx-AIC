//
//  Endpoint.swift
//  AIC
//
//  Created by ahmed on 10/07/2026.
//

import Foundation
import Alamofire

protocol Endpoint {
    associatedtype Response: Decodable
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: String] { get }
}

extension Endpoint {
    var method: HTTPMethod { .get }
}
