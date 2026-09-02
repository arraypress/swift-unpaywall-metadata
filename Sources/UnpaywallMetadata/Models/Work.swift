//
//  Work.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  One DOI's open-access answer. Unpaywall's job is narrow and it does it
//  well: not "what is this paper" but "can I legally read it, and where".
//  The bibliographic fields are present but thin — for rich metadata the
//  right source is Crossref or OpenAlex, and this library does not pretend
//  otherwise.
//

import Foundation

/// What Unpaywall knows about one DOI.
public struct Work: Codable, Sendable, Equatable {

    /// The DOI, lower-cased, without a resolver prefix.
    public let doi: String
    /// The resolver URL, `https://doi.org/…`.
    public let doiUrl: String?
    /// The article title. `nil` happens; Unpaywall mirrors Crossref's gaps.
    public let title: String?
    /// Publication year.
    public let year: Int?
    /// Publication date, `yyyy-MM-dd`.
    public let publishedDate: String?
    /// The journal or venue name.
    public let journalName: String?
    /// The publisher.
    public let publisher: String?
    /// The journal's linking ISSN.
    public let journalIssnL: String?
    /// Crossref's type, e.g. `journal-article`, `posted-content`.
    public let genre: String?

    /// Whether a free-to-read copy exists anywhere Unpaywall can see.
    public let isOa: Bool
    /// How it is free, as a colour. See ``OAStatus``.
    public let oaStatus: OAStatus?
    /// The copy Unpaywall recommends — best licence, best version.
    public let bestOaLocation: Location?
    /// The earliest free copy it found.
    public let firstOaLocation: Location?
    /// Every free copy it knows about.
    public let oaLocations: [Location]?
    /// Whether any repository holds a copy.
    public let hasRepositoryCopy: Bool?
    /// Whether the whole journal is open access.
    public let journalIsOa: Bool?
    /// Whether the journal is listed in the DOAJ.
    public let journalIsInDoaj: Bool?

    /// The authors, as Unpaywall mirrors them from Crossref.
    public let zAuthors: [Author]?

    /// One author.
    ///
    /// Unpaywall mirrors whatever Crossref holds, and that is not one
    /// shape: some records carry split `given`/`family` names, others
    /// carry only a `raw_author_name` string. Both were observed on live
    /// records the day this was written, so both are decoded and ``short``
    /// papers over the difference.
    public struct Author: Codable, Sendable, Equatable {
        /// Given name(s), when Crossref split them.
        public let given: String?
        /// Family name, when Crossref split it.
        public let family: String?
        /// The name as printed, when Crossref did not split it.
        public let rawAuthorName: String?
        public let orcid: String?
        /// `first`, `middle` or `last`.
        public let authorPosition: String?
        /// Whether this author is the corresponding one.
        public let isCorresponding: Bool?

        /// `Family I.` — the form a citation line wants.
        ///
        /// Falls back to the raw name when the record was never split, and
        /// to an empty string when there is no name at all, so a caller
        /// joining these never has to filter `nil`.
        public var short: String {
            if let family, !family.isEmpty {
                let initials = (given ?? "")
                    .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "." })
                    .compactMap(\.first)
                    .map(String.init)
                    .joined()
                return initials.isEmpty ? family : "\(family) \(initials)"
            }
            guard let raw = rawAuthorName?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return "" }
            // "G. Kucsko" is already the printed form; reorder to "Kucsko G."
            let parts = raw.split(separator: " ")
            guard let last = parts.last, parts.count > 1 else { return raw }
            let initials = parts.dropLast().compactMap(\.first).map(String.init).joined()
            return "\(last) \(initials)"
        }
    }
}
