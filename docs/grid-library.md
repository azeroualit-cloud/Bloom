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
