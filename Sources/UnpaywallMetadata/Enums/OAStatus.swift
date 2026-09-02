//
//  OAStatus.swift
//  UnpaywallMetadata
//
//  Created by David Sherlock on 2026.
//
//  Unpaywall's open-access colours. Decoded leniently: an unrecognised
//  colour becomes ``unknown`` rather than failing the whole record,
//  because a new category appearing upstream should not stop a caller
//  reading the DOI and the URL it already asked for.
//

import Foundation

/// How, and whether, a paper is free to read.
public enum OAStatus: String, Codable, Sendable, CaseIterable {

    /// Free at the publisher, under an open licence.
    case gold
    /// Free in a repository, not necessarily at the publisher.
    case green
    /// Free at the publisher under an open licence, in a paywalled journal.
    case hybrid
    /// Free to read at the publisher, but with no licence granting reuse.
    /// The most fragile category — bronze can be withdrawn without notice.
    case bronze
    /// Not free anywhere Unpaywall can see.
    case closed
    /// A colour this library does not know. Upstream added something.
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = OAStatus(rawValue: raw.lowercased()) ?? .unknown
    }

    /// Whether this status means a reader can get the full text.
    public var isFree: Bool { self != .closed && self != .unknown }
}
