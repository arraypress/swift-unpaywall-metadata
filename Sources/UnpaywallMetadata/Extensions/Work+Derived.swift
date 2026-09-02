//
//  Work+Derived.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  The questions a caller actually asks, answered from the decoded record
//  rather than recomputed at every call site. Kept out of the model file
//  so ``Work`` stays a description of the API's shape and nothing else.
//

import Foundation

public extension Work {

    /// The single best link to read this paper free, or `nil` if there
    /// isn't one. Prefers the recommended location, falls back to the
    /// earliest, then to anything at all.
    var readableURL: URL? {
        bestOaLocation?.bestURL ?? firstOaLocation?.bestURL ?? oaLocations?.compactMap(\.bestURL).first
    }

    /// A direct PDF link, when one is known anywhere in the record.
    /// Distinct from ``readableURL``: a landing page is readable but is
    /// not a file a pipeline can download.
    var pdfURL: URL? {
        for location in [bestOaLocation, firstOaLocation].compactMap({ $0 }) + (oaLocations ?? []) {
            if let pdf = location.urlForPdf, let url = URL(string: pdf) { return url }
        }
        return nil
    }

    /// The licence on the recommended copy, e.g. `cc-by`.
    ///
    /// `nil` is meaningful: bronze open access is free to read but grants
    /// no reuse rights, so absence here is a legal fact, not missing data.
    var license: String? { bestOaLocation?.license }

    /// Whether the free copy is the version of record rather than a
    /// preprint or accepted manuscript.
    var isPublishedVersion: Bool { bestOaLocation?.isPublishedVersion ?? false }

    /// A one-line citation: `Family I., Family I. (2013). Title. Journal.`
    var citation: String {
        let names = (zAuthors ?? []).prefix(3).map(\.short).filter { !$0.isEmpty }
        var parts: [String] = []
        if !names.isEmpty {
            // No trailing stop on "et al" — the join below supplies it.
            parts.append(names.joined(separator: ", ") + ((zAuthors?.count ?? 0) > 3 ? ", et al" : ""))
        }
        if let year { parts.append("(\(year))") }
        if let title { parts.append(title) }
        if let journalName { parts.append(journalName) }
        return parts.joined(separator: ". ")
    }
}
