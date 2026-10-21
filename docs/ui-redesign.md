# Bloom: compact, consistent UI

This revision addresses the October 21 spacing review. The shared rhythm is 4/8/12/16/24 pt with 44 pt touch targets.

- Library: two compact smart destinations (all notes / Da organizzare), smaller category cards containing a distinct symbol, title and note count; no misleading stack/trash badge or random note excerpt. Search remains visible. Selection moves to the actions menu, with a visible completion action during selection. The existing three-column note grid is preserved.
- Map: equal-width action columns around the centered title; smaller coordinate-centered points and native clusters with no external badges or thumbnails. Cluster numbers count places; note counts and media appear in the compact selected-place panel. Existing reset, saved-place list and note navigation remain available.
- Appunti: replaces the public PKMS label without renaming persistence keys, Dropbox paths or recovery files. Source editing has bounded scrolling, consistent text margins, no overlaid mode banner and a compact truthful save status below the title. The keyboard strip has six evenly distributed 44 pt actions, including direct bold/list/checklist/link, the complete format menu and Done.
- Navigation: semantic solid backgrounds and a bottom foundation separate scrolling content from tab labels.
- Identity: the new five-petal Bloom flower uses one continuous diagonal blue/lavender/berry color field over the complete mark. The generated artwork was inspected and packaged as matching opaque RGB 1024-square PNG assets for default and dark appearances.

Storage, tagging, recovery, conflicts, offline editing, original media and exact map coordinates are unchanged. Geometry checks cover compact cards, symmetric map actions, bounded editing and keyboard target spacing. Unit coverage checks the keyboard at 320 and 390 pt and verifies selection formatting. Full XCTest execution, exported screenshot review and released IPA integrity are required before completion; Linux syntax checks alone are not native validation.
