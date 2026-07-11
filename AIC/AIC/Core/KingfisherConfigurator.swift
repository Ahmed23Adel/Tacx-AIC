//
//  KingfisherConfigurator.swift
//  AIC
//
//  Created by ahmed on 11/07/2026.
//

import Foundation
import Kingfisher

/// The AIC image CDN sits behind Cloudflare bot protection that 403s requests
/// with a bare header profile. Sending the standard headers a mobile browser
/// sends (User-Agent, Accept, Referer) passes the check. Applied globally so
/// every KFImage in the app inherits it.
enum KingfisherConfigurator {
    // Internal (not private): test seam — tests apply the modifier to a
    // request and assert the exact headers it stamps.
    static let browserHeadersModifier = AnyModifier { request in
        var modified = request
        modified.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        modified.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        modified.setValue("https://www.artic.edu/", forHTTPHeaderField: "Referer")
        return modified
    }

    static func configure() {
        KingfisherManager.shared.defaultOptions += [.requestModifier(browserHeadersModifier)]
    }
}
