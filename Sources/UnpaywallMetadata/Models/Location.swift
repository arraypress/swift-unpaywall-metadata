//
//  Location.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  One place a copy of the paper actually sits. A DOI can have several —
//  the publisher's own page, a university repository, PubMed Central —
//  and they are not equally useful: only some carry a direct PDF, and
//  only some carry a licence that permits reuse.
//

import Foundation

/// Somewhere a free copy of the paper can be read.
public struct Location: Codable, Sendable, Equatable {

    /// Where the copy lives — `publisher` or `repository`.
    public let hostType: String?
    /// The landing page a person should be sent to.
    public let urlForLandingPage: String?
    /// A direct link to the PDF, when one is known.
    public let urlForPdf: String?
    /// The best single URL Unpaywall has for this copy.
    public let url: String?
    /// The licence, e.g. `cc-by`; `nil` means no reuse rights are granted.
    public let license: String?
    /// Which version this is — `publishedVersion`, `acceptedVersion`, `submittedVersion`.
    public let version: String?
    /// The repository holding it, when it is a repository copy.
    public let repositoryInstitution: String?
    /// When this copy became open, `yyyy-MM-dd`.
    public let oaDate: String?

    /// Whether this is the peer-reviewed version of record, rather than a
    /// preprint or an author manuscript.
    public var isPublishedVersion: Bool { version == "publishedVersion" }

    /// The most directly useful link: the PDF if there is one, else the
    /// landing page, else whatever single URL was given.
    public var bestURL: URL? {
        for candidate in [urlForPdf, url, urlForLandingPage] {
            if let candidate, let url = URL(string: candidate) { return url }
        }
        return nil
    }
}
