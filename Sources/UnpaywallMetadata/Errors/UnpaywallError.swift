//
//  UnpaywallError.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong asking Unpaywall about a DOI.
public enum UnpaywallError: Error, LocalizedError, Sendable, Equatable {
    /// The string given is not a DOI a request can be made from.
    case badDOI(String)
    /// Unpaywall has no record of this DOI.
    case notFound(String)
    /// The email parameter was missing or empty. The API refuses these.
    case emailRequired
    /// Unpaywall answered with an HTTP failure.
    case http(Int)
    /// Unpaywall is rate-limiting; retry after this many seconds if known.
    case rateLimited(retryAfter: Int?)
    /// A response did not have the shape the API documents.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .badDOI(let doi): return "\(doi) is not a DOI"
        case .notFound(let doi): return "Unpaywall has no record of \(doi)"
        case .emailRequired: return "Unpaywall requires an email address to identify the caller"
        case .http(let code): return "Unpaywall answered HTTP \(code)"
        case .rateLimited(let after):
            return "Unpaywall is rate-limiting" + (after.map { " (retry after \($0)s)" } ?? "")
        case .malformed(let what): return "unexpected response shape: \(what)"
        }
    }
}
