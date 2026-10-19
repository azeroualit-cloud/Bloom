# Archive navigation — research and proposal, 19 October 2026

Status: proposal for discussion. Build 17 retains the existing manual, multiple-tag data model. No category migration or AI/OCR classification is included.

## What the references actually support

- [Raindrop collections](https://help.raindrop.io/collections): one collection per bookmark, Unsorted inbox, icons and layout per collection. Grid crops into uniform squares; List is appropriate for sorting/scanning; Headlines minimizes imagery; Moodboard varies tile height. Its [official view comparison](https://raindrop.io/_next/static/media/view-modes.0907cc9c.png) separates preview, title and source rather than placing glass over every label. [Tags](https://help.raindrop.io/tags) are multiple independent keywords, editable during capture or later. Adopt the distinction between a destination and optional filters, not its collection deletion behavior (Bloom preserves notes).
- [Sprink](https://sprink.app/blog/one-app-to-save-everything-social-media.html): organize the library by topic instead of source app, with global search. Adopt topic-first browsing. Its claims about automatic understanding and permanent retention are marketing statements, not capabilities verified in Bloom. AI and reminders remain outside this change.
- [Stasht](https://stasht.app/app-to-save-and-organize-social-media-posts): useful cards and retrieval matter beyond capture. Its FAQ explicitly says it links back to original social videos rather than downloading them. This matches Bloom's native-app opening with browser fallback. Maps/calendar/extraction are not required for a general personal archive.
- [Save Social Posts in One App](https://apps.apple.com/us/app/save-social-posts-in-one-app/id6746639451): collection selection during capture, search and manual paste; consistent entry points across source platforms. The listing also contains a review requesting automatic thumbnails: a useful reminder that a saved URL alone is not a visual library. Listing claims are not a hands-on product test.
- [Tapfold](https://tapfold.com/blog/best-app-save-social-media/): page and root return HTTP 403 in this environment. No new claims about its screens or behavior are inferred. Preserve the user's stated preference for its clean, low-friction philosophy.

## Recommended structure

One primary category per note, optional until later (default **Da specificare**). Home: two-column visual category grid. Inside: optional category-scoped tag chips, then the existing square content grid. Example: **Psicologia → Dating**; other possible tags are Terapia and Abitudini. Tags never become a third navigation page: choosing one simply filters the same grid. Keep depth to two levels, unlike a nested folder tree.

Category means “where will I look for this?” Tag means “which aspect?” Avoid duplicating category names as tags. A category rename or deletion must preserve notes; removing a tag only removes that label. Search remains global from home and can be narrowed by category/type/tag. Archived content stays behind Settings.

The ticketing analogy is useful for one main destination plus optional attributes; do not add mandatory status, priority or assignment fields to saving. No mandatory filing step.

The current eleven tags must not be arbitrarily reassigned. Before migration, agree the parent map (Dating under Psicologia is the user's example, not an approved mapping of all areas). Existing notes can have several tags; selecting a primary category must preserve every old association, and offer explicit resolution of ambiguous notes. Backup compatibility and migration tests are prerequisites.

## Retrieval and presentation

- Visual material: keep two-column square grid, cropped previews, clear title and small source/type indicator. Uniform squares provide a stable scanning rhythm; do not introduce masonry by default.
- Text-heavy categories: offer an optional compact list with title, two-line excerpt and source/date, remembering the user's choice per category. Same note, same actions and destination. This is proposed, not shipped in build 17.
- Category covers: use a recent cached poster or local image; text excerpt if no image; distinctive icon for an empty category. Keep category names/counts visible. A fixed user-selected cover can come later if automatically changing covers becomes disorienting.
- Re-finding: global search, optional tag chips and newest-first sorting before adding more screens. A small Recent/Continue area or pinned notes can be evaluated after the category structure; do not duplicate the whole library on home.
- Interaction: media surface opens the media/source, title opens the note; keep this explicit in accessibility labels. Preserve scroll/filter position on back. Actions stay in the menu/swipe; permanent deletion requires confirmation.

## Interaction budget (proposed flows)

Counts start on home or inside the category, exclude typing and OS permission prompts.

| Task | Target taps | Flow |
| --- | --- | --- |
| Open a known item from home | 2 | Category → preview/title |
| Narrow to a subtopic | 1 additional | Tap a tag chip; no extra page |
| Search a remembered title/phrase | 2 plus typing | Search → result |
| Save copied link, file later | 2 plus paste permission if iOS asks | Add → Paste and save |
| Choose a category while composing | 1 | Visible category choice, no mandatory selector sheet |
| Add optional tags | 1–2 | Reveal chips → choose; save button unchanged |
| Rename/delete a tag now | 4/3 | Manage → pencil → edit → Save / Manage → trash → confirm |

Validation before category rollout: locate five known notes without knowing their platform; browse mixed text/image/video notes; save uncategorized offline; add/remove tags; delete a category without losing a note; restore a pre-migration backup. Compare successful retrieval and wrong turns, not just tap counts.
