//
//  Unpaywall.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  Unpaywall as typed values. One question, answered well: given a DOI,
//  is there a legal free copy and where is it. 30-odd million DOIs, no
//  API key — but an email address is mandatory, and it is identification
//  rather than a secret, which is why it is a parameter here and not a
//  credential in a keychain.
//
//  The API also documents a `/v2/search` endpoint. It is NOT wrapped
//  here: probed on 2026-09-03 it answered HTTP 500 for every query tried,
//  including the example from its own documentation. Shipping a verb that
//  cannot work would be worse than not shipping it.
//

import Foundation

/// A keyless client for Unpaywall.
public struct Unpaywall: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// How a retry waits — injectable so rate-limit tests cost no wall-clock.
    public typealias Sleeper = @Sendable (_ seconds: Int) async throws -> Void

    /// The User-Agent sent when none is chosen.
    public static let defaultUserAgent = "swift-unpaywall/0.1 (+https://github.com/arraypress/swift-unpaywall-metadata)"

    /// The address sent with every request. Unpaywall requires it and uses
    /// it to contact heavy users rather than silently blocking them.
    public let email: String

    /// The User-Agent every request carries.
    public let userAgent: String

    private let transport: Transport
    private let sleeper: Sleeper

    /// A client.
    ///
    /// - Parameters:
    ///   - email: A real address you read. Unpaywall's terms ask for one,
    ///     and it is how they warn you before cutting you off.
    ///   - userAgent: Identify yourself; keyless endpoints stay keyless
    ///     because callers do.
    ///   - transport: Leave `nil` for the shared URLSession.
    ///   - sleeper: How a 429 retry waits; leave `nil` for real sleeping.
    public init(email: String, userAgent: String = Unpaywall.defaultUserAgent,
                transport: Transport? = nil, sleeper: Sleeper? = nil) {
        self.email = email
        self.userAgent = userAgent
        self.sleeper = sleeper ?? { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(seconds, 1)) * 1_000_000_000)
        }
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw UnpaywallError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Lookup

    /// What Unpaywall knows about one DOI.
    ///
    /// - Parameter doi: Any common form — bare, `doi:`-prefixed, or a
    ///   doi.org URL. Normalised before the request is built.
    /// - Throws: ``UnpaywallError/notFound(_:)`` when the DOI is unknown,
    ///   which is a real answer rather than a failure — plenty of valid
    ///   DOIs are simply not in the index.
    public func work(for doi: String) async throws -> Work {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw UnpaywallError.emailRequired
        }
        guard DOI.isValid(doi) else { throw UnpaywallError.badDOI(doi) }
        let data = try await perform(try Endpoint.work(doi: doi, email: email))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(Work.self, from: data)
        } catch {
            throw UnpaywallError.malformed("\(error)")
        }
    }

    /// Several DOIs, looked up one at a time.
    ///
    /// Unpaywall has no batch endpoint, so this is a loop — but it is a
    /// *sequential* loop on purpose. Firing thirty concurrent requests at
    /// a free service is how a keyless endpoint stops being keyless.
    ///
    /// - Returns: Results keyed by normalised DOI. DOIs the index does not
    ///   know are absent from the dictionary rather than throwing, so one
    ///   miss does not lose the other twenty-nine answers.
    public func works(for dois: [String]) async throws -> [String: Work] {
        var found: [String: Work] = [:]
        for doi in dois {
            do {
                let work = try await work(for: doi)
                found[DOI.normalized(doi)] = work
            } catch UnpaywallError.notFound, UnpaywallError.badDOI {
                continue
            }
        }
        return found
    }

    // MARK: - Plumbing

    /// Performs a GET with the User-Agent, retrying a 429 twice with the
    /// service's own Retry-After (capped at ten seconds) before giving up.
    func perform(_ url: URL, retriesLeft: Int = 2) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200...299:
            return data
        case 404:
            throw UnpaywallError.notFound(url.lastPathComponent)
        case 422:
            // What the API returns for a syntactically unacceptable DOI.
            throw UnpaywallError.badDOI(url.lastPathComponent)
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            guard retriesLeft > 0 else { throw UnpaywallError.rateLimited(retryAfter: after) }
            try await sleeper(min(after ?? 1, 10))
            return try await perform(url, retriesLeft: retriesLeft - 1)
        default:
            throw UnpaywallError.http(response.statusCode)
        }
    }
}
