# Tag-first library — build 16

The initial Library presents the tag catalog, including empty tags, in two columns. All notes and Unspecified are explicit entry points. Opening a tag shows only its notes, also in two columns. Both category and content tiles have a 1:1 footprint. Search bypasses category browsing. Returning to tags clears the current filters; the app never restores an old category over the initial catalog.

Image and social poster thumbnails fill and clip their square container; the full image viewer retains original aspect and non-destructive framing. Note title opens the note, while video/image surface opens the content directly. Actions menu offers tags, archive/restore and delete. A direction-locked UIKit scroll container cancels taps during horizontal drags; vertical pans stay with the page. A horizontal drag reveals archive/restore plus delete inside the same clipped square, avoiding the former List row insets and swipe background mismatch. Full swipe never deletes; deletion requires explicit confirmation. The action surface and preview share one square clip; no full-swipe destructive action. Selection remains available through long press and toolbar, with an outline and checkmark per selected tile.

Rediscovery reuses the same square preview component, media opening and actions. Its organizer edits multiple manual tags instead of the obsolete single collection relation. Rediscovery history/exhaustion behavior remains intact.

Archive is accessible only through the Settings gear, not a home segmented control. The Tag back control returns from Archive to the tag catalog. The gear also retains tag management, sorting, backup and capture guidance.

CI selects Xcode 26.3 and the newest available iPhone simulator runtime to compile and test the native appearance. Glass containers use native glassEffect on iOS 26+ when compiled with Swift 6.2+ and system material otherwise. No custom simulated refraction. The icon is bundled as a 1024px opaque universal iOS AppIcon asset. Existing notes, tags and backup formats are unchanged.

The explicit Paste buttons read clipboard content only on tap. This avoids the non-delivering protected paste controls observed in SDK 26 simulator tests. iOS may request permission the first time clipboard content comes from another app; regular text-field paste remains available.
