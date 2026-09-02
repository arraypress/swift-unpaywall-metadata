//
//  UnpaywallMetadataTests.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  Everything runs on a recorded response — the fixture below is real
//  Unpaywall output for 10.1038/nature12373, captured 2026-09-03 — so the
//  suite needs no network and cannot be rate-limited into flakiness.
//

import Foundation
import XCTest
@testable import UnpaywallMetadata

final class UnpaywallMetadataTests: XCTestCase {

    /// Real Unpaywall output, verbatim apart from trimming the author and
    /// location lists to keep the fixture readable.
    static let recorded = #"""
    {"best_oa_location":{"endpoint_id":null,"evidence":"deprecated","host_type":"publisher","is_best":true,"license":null,"oa_date":"2013-07-30","pmh_id":null,"repository_institution":null,"updated":"deprecated","url":"https://www.nature.com/articles/nature12373.pdf","url_for_landing_page":"https://doi.org/10.1038/nature12373","url_for_pdf":"https://www.nature.com/articles/nature12373.pdf","version":"publishedVersion"},"data_standard":2,"doi":"10.1038/nature12373","doi_url":"https://doi.org/10.1038/nature12373","first_oa_location":{"endpoint_id":null,"evidence":"deprecated","host_type":"publisher","is_best":true,"license":null,"oa_date":"2013-07-30","pmh_id":null,"repository_institution":null,"updated":"deprecated","url":"https://www.nature.com/articles/nature12373.pdf","url_for_landing_page":"https://doi.org/10.1038/nature12373","url_for_pdf":"https://www.nature.com/articles/nature12373.pdf","version":"publishedVersion"},"genre":"journal-article","has_repository_copy":true,"is_oa":true,"is_paratext":false,"journal_is_in_doaj":false,"journal_is_oa":false,"journal_issn_l":"0028-0836","journal_issns":"0028-0836,1476-4687","journal_name":"Nature","oa_locations":[{"endpoint_id":null,"evidence":"deprecated","host_type":"publisher","is_best":true,"license":null,"oa_date":"2013-07-30","pmh_id":null,"repository_institution":null,"updated":"deprecated","url":"https://www.nature.com/articles/nature12373.pdf","url_for_landing_page":"https://doi.org/10.1038/nature12373","url_for_pdf":"https://www.nature.com/articles/nature12373.pdf","version":"publishedVersion"}],"oa_locations_embargoed":[],"oa_status":"bronze","published_date":"2013-07-30","publisher":"Springer Science and Business Media LLC","title":"Nanometre-scale thermometry in a living cell","updated":"2026-08-26T18:58:27Z","year":2013,"z_authors":[{"author_position":"first","is_corresponding":false,"raw_affiliation_strings":["Department of Physics, Harvard University, Cambridge, Massachusetts 02138, USA","Department of Physics, Harvard University, Cambridge, 02138, Massachusetts, USA"],"raw_author_name":"G. Kucsko"},{"author_position":"middle","is_corresponding":false,"raw_affiliation_strings":["Department of Physics, Harvard University, Cambridge, 02138, Massachusetts, USA"],"raw_author_name":"P. C. Maurer"}]}
    """#

    /// A transport that answers from a script and records what was asked.
    final class Script: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var requests: [URLRequest] = []
        let answer: @Sendable (URLRequest) -> (Int, Data, [String: String])

        init(_ answer: @escaping @Sendable (URLRequest) -> (Int, Data, [String: String])) {
            self.answer = answer
        }

        /// Sync on purpose: NSLock may not be taken directly in an async
        /// frame, but calling a synchronous method that locks is fine.
        private func record(_ request: URLRequest) {
            lock.lock(); requests.append(request); lock.unlock()
        }

        var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }

        func transport(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            record(request)
            let (code, data, headers) = answer(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code,
                                           httpVersion: nil, headerFields: headers)!
            return (data, response)
        }
    }

    /// Answers with the recording every time.
    static func ok() -> Script { Script { _ in (200, Data(Self.recorded.utf8), [:]) } }

    func makeClient(_ script: Script, sleeps: (@Sendable (Int) async throws -> Void)? = nil) -> Unpaywall {
        Unpaywall(email: "test@example.com", transport: script.transport,
                  sleeper: sleeps ?? { _ in })
    }

    // MARK: - Decoding

    func testDecodesARealRecord() async throws {
        let script = Self.ok()
        let work = try await makeClient(script).work(for: "10.1038/nature12373")

        XCTAssertEqual(work.doi, "10.1038/nature12373")
        XCTAssertEqual(work.title, "Nanometre-scale thermometry in a living cell")
        XCTAssertEqual(work.year, 2013)
        XCTAssertEqual(work.journalName, "Nature")
        XCTAssertTrue(work.isOa)
        XCTAssertEqual(work.oaStatus, .bronze)
    }

    func testDerivedAccessorsAnswerTheQuestionsCallersActuallyAsk() async throws {
        let script = Self.ok()
        let work = try await makeClient(script).work(for: "10.1038/nature12373")

        XCTAssertNotNil(work.readableURL, "a bronze record still has somewhere to read it")
        XCTAssertNil(work.license, "bronze grants no reuse rights — nil here is a legal fact, not a gap")
        XCTAssertTrue(work.citation.contains("2013"))
        XCTAssertTrue(work.citation.contains("Nature"))
        XCTAssertTrue(work.citation.hasPrefix("Kucsko G"), "authors lead the line: \(work.citation)")
        XCTAssertFalse(work.citation.contains(".."), "the join supplies the stop after et al")
    }

    // MARK: - Requests

    func testTheRequestCarriesTheEmailAndAUserAgent() async throws {
        let script = Self.ok()
        _ = try await makeClient(script).work(for: "https://doi.org/10.1038/nature12373")

        let request = try XCTUnwrap(script.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), Unpaywall.defaultUserAgent)
        XCTAssertTrue(request.url!.absoluteString.contains("email=test@example.com"))
        XCTAssertTrue(request.url!.absoluteString.contains("/v2/10.1038/nature12373"),
                      "the resolver prefix must be stripped before the request")
    }

    func testAMalformedDOINeverReachesTheNetwork() async {
        let script = Self.ok()
        do {
            _ = try await makeClient(script).work(for: "not-a-doi")
            XCTFail("expected badDOI")
        } catch {
            XCTAssertEqual(error as? UnpaywallError, .badDOI("not-a-doi"))
        }
        XCTAssertTrue(script.count == 0, "a local check must not cost a round trip")
    }

    func testAnEmptyEmailIsRefusedLocally() async {
        let script = Self.ok()
        let client = Unpaywall(email: "  ", transport: script.transport, sleeper: { _ in })
        do {
            _ = try await client.work(for: "10.1038/nature12373")
            XCTFail("expected emailRequired")
        } catch {
            XCTAssertEqual(error as? UnpaywallError, .emailRequired)
        }
        XCTAssertTrue(script.count == 0)
    }

    // MARK: - Failures

    func test404IsNotFoundRatherThanAnHTTPError() async {
        let script = Script { _ in (404, Data(), [:]) }
        do {
            _ = try await makeClient(script).work(for: "10.1038/nature12373")
            XCTFail("expected notFound")
        } catch {
            guard case .notFound = error as? UnpaywallError else {
                return XCTFail("got \(error)")
            }
        }
    }

    func testRateLimitRetriesThenGivesUpWithTheServersOwnRetryAfter() async {
        let script = Script { _ in (429, Data(), ["Retry-After": "3"]) }
        let waits = Waits()
        do {
            _ = try await makeClient(script, sleeps: { await waits.record($0) }).work(for: "10.1038/nature12373")
            XCTFail("expected rateLimited")
        } catch {
            XCTAssertEqual(error as? UnpaywallError, .rateLimited(retryAfter: 3))
        }
        XCTAssertEqual(script.count, 3, "the first attempt plus two retries")
    }

    func testTheRetryCapStopsAnAbsurdRetryAfterFromHangingACaller() async {
        let calls = Counter()
        let script = Script { _ in
            calls.bump() == 1
                ? (429, Data(), ["Retry-After": "86400"])
                : (200, Data(Self.recorded.utf8), [:])
        }
        let waits = Waits()
        _ = try? await makeClient(script, sleeps: { await waits.record($0) }).work(for: "10.1038/nature12373")
        let recorded = await waits.seconds
        XCTAssertEqual(recorded, [10], "a day-long Retry-After caps at ten seconds")
    }

    /// A call counter safe to touch from the transport closure.
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        /// Increments and returns the new count.
        func bump() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    }

    /// Records what the sleeper was asked to wait, without waiting.
    actor Waits {
        var seconds: [Int] = []
        func record(_ value: Int) { seconds.append(value) }
    }

    // MARK: - Batch

    func testBatchSkipsMissesRatherThanLosingTheWholeRun() async throws {
        let script = Script { request in
            request.url!.absoluteString.contains("nature12373")
                ? (200, Data(Self.recorded.utf8), [:])
                : (404, Data(), [:])
        }
        let found = try await makeClient(script).works(for: [
            "10.1038/nature12373", "10.9999/missing", "also-not-a-doi",
        ])
        XCTAssertEqual(Array(found.keys), ["10.1038/nature12373"])
        XCTAssertEqual(script.count, 2, "the invalid DOI is rejected before any request")
    }
}
