//
//  SupportTests.swift
//  UnpaywallMetadataTests
//
//  Created by David Sherlock on 2026.
//
//  The extracted utilities on their own: DOI normalising to the
//  character, validation that refuses what the API would refuse anyway,
//  and the URL builder without a network.
//

import Foundation
import XCTest
@testable import UnpaywallMetadata

final class SupportTests: XCTestCase {

    func testDOINormalisingStripsEveryWrapperItArrivesIn() {
        let expected = "10.1038/nature12373"
        XCTAssertEqual(DOI.normalized("10.1038/nature12373"), expected)
        XCTAssertEqual(DOI.normalized("https://doi.org/10.1038/nature12373"), expected)
        XCTAssertEqual(DOI.normalized("http://dx.doi.org/10.1038/nature12373"), expected)
        XCTAssertEqual(DOI.normalized("doi:10.1038/nature12373"), expected)
        XCTAssertEqual(DOI.normalized("  10.1038/nature12373  "), expected)
        XCTAssertEqual(DOI.normalized("10.1038/nature12373."), expected, "a full stop dragged in from prose")
        XCTAssertEqual(DOI.normalized("10.1038/NATURE12373"), expected, "DOIs are case-insensitive")
    }

    func testDOINormalisingKeepsCharactersThatAreLegallyPartOfADOI() {
        // Parentheses and semicolons are legal in a DOI suffix and must survive.
        XCTAssertEqual(DOI.normalized("10.1002/(SICI)1097-0258"), "10.1002/(sici)1097-0258")
    }

    func testDOIValidationRefusesWhatTheAPIWouldRefuse() {
        XCTAssertTrue(DOI.isValid("10.1038/nature12373"))
        XCTAssertTrue(DOI.isValid("https://doi.org/10.1056/NEJMoa2034577"))
        XCTAssertFalse(DOI.isValid(""), "empty")
        XCTAssertFalse(DOI.isValid("nature12373"), "no registrant")
        XCTAssertFalse(DOI.isValid("10.1038"), "no suffix separator")
        XCTAssertFalse(DOI.isValid("10.1038/"), "empty suffix")
        XCTAssertFalse(DOI.isValid("10.abc/xyz"), "registrant must be digits")
        XCTAssertFalse(DOI.isValid("11.1038/x"), "DOIs start 10.")
    }

    func testEndpointCarriesTheEmailAndLeavesTheDOISlashAlone() throws {
        let url = try Endpoint.work(doi: "https://doi.org/10.1038/nature12373", email: "a@b.com")
        XCTAssertTrue(url.absoluteString.hasPrefix("https://api.unpaywall.org/v2/10.1038/nature12373?"),
                      "the DOI's own slash must not be percent-encoded: \(url)")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items, [URLQueryItem(name: "email", value: "a@b.com")])
    }

    func testAuthorNamesShortenFromEitherShapeUnpaywallMirrors() throws {
        func author(_ json: String) throws -> Work.Author {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Work.Author.self, from: Data(json.utf8))
        }
        // Crossref split the name.
        XCTAssertEqual(try author(#"{"given":"Georg","family":"Kucsko"}"#).short, "Kucsko G")
        XCTAssertEqual(try author(#"{"given":"P. C.","family":"Maurer"}"#).short, "Maurer PC")
        // Crossref did not — the shape live records actually returned.
        XCTAssertEqual(try author(#"{"raw_author_name":"G. Kucsko"}"#).short, "Kucsko G")
        XCTAssertEqual(try author(#"{"raw_author_name":"P. C. Maurer"}"#).short, "Maurer PC")
        // Nothing usable must not crash a citation line.
        XCTAssertEqual(try author(#"{}"#).short, "")
        XCTAssertEqual(try author(#"{"raw_author_name":"Cher"}"#).short, "Cher", "a single-word name stays as it is")
    }

    func testOAStatusDecodesLenientlySoANewColourCannotBreakARecord() throws {
        func status(_ raw: String) throws -> OAStatus {
            try JSONDecoder().decode(OAStatus.self, from: Data("\"\(raw)\"".utf8))
        }
        XCTAssertEqual(try status("gold"), .gold)
        XCTAssertEqual(try status("BRONZE"), .bronze, "case-insensitive")
        XCTAssertEqual(try status("diamond"), .unknown, "an unknown colour must not fail the record")
        XCTAssertTrue(OAStatus.bronze.isFree)
        XCTAssertFalse(OAStatus.closed.isFree)
        XCTAssertFalse(OAStatus.unknown.isFree, "unknown is not a promise of access")
    }
}
