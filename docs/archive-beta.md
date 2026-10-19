# Archive beta, build 15

This release extends the existing local note archive; it introduces no service, App Group, AI classification or feed dependency.

## Consultation

Secondary image attachments use the same bounded decoder, pinch/double-tap zoom and non-destructive framing editor as primary images. Their framing is an optional field inside the existing Codable attachment payload, readable from older records without migration. Original bytes remain unchanged. Secondary Markdown/text documents can be edited directly; identity stays stable and reads resolve the latest persisted attachment. Other files open system Quick Look when supported, retaining file sharing as fallback.

Secondary links fetch posters only when their view appears. Posters use a rebuildable 32 MiB disk cache keyed by SHA-256 of the full URL, coalesce concurrent requests for the same URL, and suppress failed automatic retries for a day within a process. Primary posters retain their existing persistent cache. Site-provided previews remain best-effort: blocked/authenticated pages show a domain fallback. Video taps still attempt the native app, then the embedded browser; no video player is loaded in library cards.

## Reliability

Note-save limits now count existing primary attachments as well as new attachments and body text. Secondary-file updates validate the full note before mutation. Primary document/text edits also include other payloads in size checks. Backup validation counts attached-note text and rejects invalid secondary framing. Repeated URLs are collapsed for stable view identities, including legacy records. Last export date updates only after the system exporter reports success. Undo explicitly identifies the archive operation.

Backup limits remain 100 MiB encoded / 60 MiB payload, so larger entire libraries require a future streaming/export-format revision. Drafts, browser state and rebuildable previews are excluded. No silent partial export.

## Verification

ArchiveReadinessTests cover legacy attachment decoding, duplicate-link identity, secondary edits/framing through full backup restoration, validation before mutation, and a 1,000-note round trip with repeated restore and archive-state preservation. Existing unit and UI suites run on macOS CI. These are correctness checks, not a measured device scrolling benchmark. Signed-device social previews, app links and visual quality require actual iPhone use.
