# Screenshot-driven UI corrections

Scope: PKMS, map, Rediscover and Library observations from the October 21 screenshots. Preserve stored Markdown, note media, coordinates, Dropbox conflict handling, offline recovery and all existing navigation.

## Decisions and acceptance

- PKMS opens in rendered reading mode. Headings H1–H6, inline emphasis, checklist bullets and pipe tables render without source markers. Tables preserve columns, escaped pipes, inline-code pipes and incomplete rows; wide tables scroll horizontally. Extra blank source lines do not create large visual gaps.
- “Scrivi” explicitly enters Markdown source editing, with automatic local saving, a complete formatting menu and a permanently reachable keyboard Done action. “Leggi” returns to the formatted document. Source bytes are never rewritten by presentation. The tab bar hides while the keyboard has focus.
- Folder/file icons and aligned indentation distinguish tree rows. Document search is always visible. Sync status distinguishes local save failure, conflict, missing remote file, pending upload, upload in progress, offline and acknowledged Dropbox state.
- Native MapKit collision clustering replaces overlapping thumbnails at overview zoom. Counts represent saved notes, not just markers. Cluster taps zoom to members; individual anchored pins open the existing note panel. Place name and count appear in the panel, and the saved-places list remains available offline. Camera fitting includes marker padding.
- Use a muted flat basemap without extra POIs. Individual pins have bounded decoded thumbnails and a coordinate pointer. No app-added play icon appears on a map marker.
- Rediscover cards have their own title, source strip and separator. Card taps say “Apri nota”. Do not put another play control over a supplied video poster that may already contain one. Missing titles fall back to readable platform names, and metadata titles fill only empty user titles.
- Library category covers use category identity for social-video sources rather than a misleading playable poster. Real image covers remain supported. Reduce inter-row gaps; distinguish category navigation with a stack badge. Use “1 nota” / “N note” consistently and a visible “Seleziona” action.
- Native tab bar uses an opaque semantic background. Scroll views include final-row clearance, while retaining native safe-area handling.

## Verification

- `PresentationTests`: table parsing, malformed input, code fences, ragged rows, fallback labels, native pin clustering contract and camera fit.
- Existing PKMS UI test continues to edit, relaunch and restore the offline document; updated to enter the explicit source mode.
- New PKMS UI test verifies rendered table geometry, hidden source delimiters, source preservation, formatting-menu reachability and keyboard dismissal.
- New dense-map UI test verifies clustering, zoom, individual pins and note navigation through the saved-places list.
- Existing category/grid, note, rediscovery, attachment and recovery tests remain in the full suite.
- UI tests retain screenshots, exported as the `UI-screenshots` Actions artifact for visual inspection. Geometry and behavior assertions run in CI; this does not claim a pixel-perfect golden-image comparator.
- Native build/test and final IPA validation require the macOS Actions runner; the editing workspace is Linux.

## Checklist

- [x] Implement the changes and add regression coverage.
- [ ] Compile app and all test bundles on macOS.
- [ ] Pass navigation preflight and complete XCTest suite.
- [ ] Inspect exported screenshots and address material visual regressions.
- [ ] Verify archive, artifact, release and embedded commit in downloaded IPA.
