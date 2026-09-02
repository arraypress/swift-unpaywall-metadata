# Swift Unpaywall

"Can I legally read this paper, and where?" — as typed values, keyless, on any Apple platform.

```swift
import UnpaywallMetadata

let unpaywall = Unpaywall(email: "you@example.com")
let work = try await unpaywall.work(for: "https://doi.org/10.1038/nature12373")

print(work.isOa)          // true
print(work.oaStatus)      // .bronze
print(work.readableURL)   // where a person can actually read it
print(work.license)       // nil — bronze grants no reuse rights
```

## Features

- 🔓 **One question, answered well** — given a DOI, is there a legal free copy and where is it. Not a bibliographic database; for rich metadata reach for Crossref or OpenAlex, and this library does not pretend otherwise
- 🎨 **OA status as a type** — gold, green, hybrid, bronze, closed. Decoded leniently, so a colour added upstream becomes `.unknown` rather than failing the whole record
- 📍 **Locations, ranked** — publisher copies and repository copies, with `readableURL` and `pdfURL` picking the most useful link so callers stop reimplementing the same fallback chain
- ⚖️ **`license` distinguishes absent from unknown** — `nil` on a bronze record is a legal fact (free to read, no reuse rights), not missing data
- 🔗 **DOIs in whatever form they arrive** — `doi:`, a doi.org URL, a trailing full stop dragged in from prose. Normalised to the character, and validated locally so a malformed DOI costs no round trip
- 🐌 **Batch is sequential on purpose** — firing thirty concurrent requests at a free service is how a keyless endpoint stops being keyless. Misses are skipped, so one unknown DOI does not lose the other twenty-nine answers
- 🚦 **429s handled like an adult** — Retry-After honoured and capped at ten seconds, two retries, then a typed `rateLimited` error
- 📼 **Tested on recordings** — 14 tests on real captured output with an injected transport. No network, no flakiness

## The email is required, and it is not a secret

Unpaywall refuses requests without an `email` parameter. It is identification, not a
credential — they use it to warn heavy users before cutting them off — which is why it
is an initialiser argument here rather than something hidden in a keychain. Use an
address you actually read.

## What this library deliberately does not wrap

The API documents a `/v2/search` endpoint. **It is not wrapped here.** Probed on
2026-09-03 it answered `HTTP 500` for every query attempted, including the example from
its own documentation. Shipping a verb that cannot work would be worse than not
shipping it. If it comes back, adding it is a small change.

## Requirements

macOS 14+ / iOS 16+ / tvOS 16+ / watchOS 9+ / visionOS 1+, Swift 6. Foundation only.

## License

MIT — see LICENSE.
