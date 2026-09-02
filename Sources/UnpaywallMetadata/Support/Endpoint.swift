//
//  Endpoint.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  Building the request URL, split from the client so it can be asserted
//  without a network. The email is a query parameter rather than a header
//  because that is what the API documents; it is identification, not a
//  secret, but it is mandatory — requests without it are refused.
//

import Foundation

/// Unpaywall's REST surface.
enum Endpoint {

    /// The API root. Versioned in the path, so a v3 would be a new case
    /// rather than a silent behaviour change.
    static let base = "https://api.unpaywall.org/v2"

    /// The lookup URL for one DOI.
    ///
    /// The DOI goes in the path unescaped apart from the characters a URL
    /// path genuinely forbids — DOIs legitimately contain `/`, `(`, `)`
    /// and `;`, and percent-encoding the separating slash breaks lookup.
    static func work(doi: String, email: String) throws -> URL {
        let doi = DOI.normalized(doi)
        guard !doi.isEmpty else { throw UnpaywallError.badDOI(doi) }
        var components = URLComponents(string: "\(base)/\(doi)")
        components?.queryItems = [URLQueryItem(name: "email", value: email)]
        guard let url = components?.url else { throw UnpaywallError.badDOI(doi) }
        return url
    }
}
