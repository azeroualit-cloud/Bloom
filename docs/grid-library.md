# Tag-first library — build 16

The initial Library presents the tag catalog, including empty tags, in two columns. All notes and Unspecified are explicit entry points. Opening a tag shows only its notes, also in two columns. Both category and content tiles have a 1:1 footprint. Search bypasses category browsing. Returning to tags clears the current filters; the app never restores an old category over the initial catalog.

Image and social poster thumbnails fill and clip their square container; the full image viewer retains original aspect and non-destructive framing. Note title opens the note, while video/image surface opens the content directly. Actions menu offers tags, archive/restore and delete. A direction-locked UIKit scroll container cancels taps during horizontal drags; vertical pans stay with the page. A horizontal drag reveals archive/restore plus delete inside the same clipped square, avoiding the former List row insets and swipe background mismatch. Full swipe never deletes; deletion requires explicit confirmation. The action surface and preview share one square clip; no full-swipe destructive action. Selection remains available through long press and toolbar, with an outline and checkmark per selected tile.

Rediscovery reuses the same square preview component, media opening and actions. Its organizer edits multiple manual tags instead of the obsolete single collection relation. Rediscovery history/exhaustion behavior remains intact.

Archive is accessible only through the Settings gear, not a home segmented control. The Tag back control returns from Archive to the tag catalog. The gear also retains tag management, sorting, backup and capture guidance.

CI selects Xcode 26.3 and the newest available iPhone simulator runtime to compile and test the native appearance. Glass containers use native glassEffect on iOS 26+ when compiled with Swift 6.2+ and system material otherwise. No custom simulated refraction. The icon is bundled as a 1024px opaque universal iOS AppIcon asset. Existing notes, tags and backup formats are unchanged.

Capture uses native PasteButton in the top toolbar and Link section, with data transferred only after a user tap. The footer is shown without the keyboard; Save and add another is also available in the keyboard toolbar. CI first exercises quick paste capture, then runs the entire unit and UI suite before packaging or publishing.

## Build 17 refinements

Home tiles use a recent available cached poster or a cropped local primary image, then a real Markdown excerpt, then a distinctive category icon for empty categories. The existing bounded thumbnail components are reused (512px); no secondary attachment JSON is decoded while choosing covers. Only the selected cover can request metadata through the existing deduplicated serial controller and retry policy; home does not crawl every note. The visible list is sorted once per home render before grouping.

Tag management is visible on home. Each row has explicit 44pt rename and delete controls, with confirmation explaining that notes and other tags remain. Rename preserves tag identity. Initial tags are seeded once in the production store, so deleting or renaming them persists across launches.

Note title footers use an opaque adaptive system surface, without Liquid Glass. Native navigation/toolbars keep the platform appearance. AppIcon includes a separate opaque 1024px dark-luminosity variant.

Deletion audit found a model read (`deleting.id`) after `context.delete` and save. Identity is now copied before deletion; saved-item CTA and selection are cleared by value. Tile rendering guards detached/deleted models, late swipe callbacks capture identity by value, and dismantling a swipe host detaches its delegate and callbacks. Library/Rediscovery discard routes to detached models. Existing preview tasks already recheck model attachment after asynchronous work. These address identified lifetime hazards; an intermittent device crash without its crash report cannot be claimed reproduced conclusively.

Regression checks include tag rename/deletion preserving other tags and note content after a new context, an end-to-end explicit tag-management flow, and the existing swipe cancel/confirm deletion and grid/navigation suite. See archive-navigation-proposal.md for the separate hierarchy/navigation proposal; the note schema is unchanged.

## Build 18 — collection density and blue identity

The home keeps two columns with 16pt horizontal gutters and square, clipped covers. Category names and counts now occupy their own stack underneath each image. An overlay constrains the cover to its proposed square before decoding; portrait posters cannot enlarge the image layout and push captions out of bounds. Category buttons include the caption region in their tap and VoiceOver target.

Inside a collection, All notes, search results and Archive use three columns with zero horizontal or vertical spacing, zero horizontal page padding and square corners. Media fills and crops each square. Video indicators move to the upper-right corner. Image/video tiles have no title panel over the poster. Text tiles retain compact title/excerpt previews. A long press opens native actions (open note, tags, selection, archive/restore, delete); swipe archive/delete and toolbar bulk selection remain. Rediscovery keeps its roomier card variant and title/action footer.

The composer now has a single Save action on the trailing toolbar. Native quick paste is in a separate top safe-area strip, above the Form and keyboard, with its own capsule shape. This removes the filled paste rectangle grouped into Save's glass capsule without introducing direct clipboard reads. The empty Save action stays correctly disabled. Preflight exercises paste-to-persistence and checks that paste and Save frames do not overlap.

AccentColor uses Meta-inspired blue #0866FF. Both opaque 1024px icon variants replace green with blue, retaining Bloom's own leaf mark and a neutral dark variant. Storage, tag identity, backup and capture routing are unchanged.

UI regression checks seed four cached portrait posters: category caption allocation, three equal-width columns reaching both page edges, no gaps between columns or rows, square cell frames, context-menu note/tag/selection actions, swipe confirmation/undo, and direct preview opening. Native screenshots of the category and content grids are retained in the test result bundle.
