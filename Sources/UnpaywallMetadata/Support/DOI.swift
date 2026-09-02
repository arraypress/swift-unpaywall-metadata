//
//  DOI.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  DOIs arrive wearing whatever the copy-paste dragged in: a doi.org URL,
//  a `doi:` prefix, a trailing full stop from a sentence. Normalising is
//  a pure function so it can be asserted to the character, and so the
//  client never has to care which form a caller had to hand.
//

import Foundation

/// A DOI in, a DOI the API will accept out.
public enum DOI {

    /// Strips the wrappers a DOI usually arrives in and lower-cases it.
    ///
    /// DOIs are case-insensitive by specification, and Unpaywall keys them
    /// lower-cased — so `10.1038/Nature12373` and `10.1038/nature12373`
    /// must not become two cache entries.
    ///
    /// Handles `https://doi.org/…`, `http://dx.doi.org/…`, a bare `doi:`
    /// prefix, surrounding whitespace, and one trailing `.` or `,` picked
    /// up from prose.
    public static func normalized(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://doi.org/", "http://doi.org/",
                       "https://dx.doi.org/", "http://dx.doi.org/",
                       "doi:", "DOI:"] where text.lowercased().hasPrefix(prefix.lowercased()) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        while let last = text.last, last == "." || last == "," {
            text = String(text.dropLast())
        }
        return text.lowercased()
    }

    /// Whether `raw` looks like a DOI at all.
    ///
    /// The registered-agency form is `10.<registrant>/<suffix>` — a check
    /// worth doing locally, because a malformed DOI otherwise costs a
    /// round trip to be told nothing was found.
    public static func isValid(_ raw: String) -> Bool {
        let doi = normalized(raw)
        guard doi.hasPrefix("10.") else { return false }
        guard let slash = doi.firstIndex(of: "/") else { return false }
        let registrant = doi[doi.index(doi.startIndex, offsetBy: 3)..<slash]
        let suffix = doi[doi.index(after: slash)...]
        return !registrant.isEmpty && registrant.allSatisfy(\.isNumber) && !suffix.isEmpty
    }
}
