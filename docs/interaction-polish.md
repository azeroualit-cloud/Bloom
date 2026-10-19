# Interaction pass — build 14

The structure and data schema remain unchanged. This increment bundles capture,
editing, tagging and gesture improvements in one release.

From Library, + opens the composer directly and focuses the text. Save returns
to Library without opening the saved content; Save & add another stays ready for
the next note. The explicit native Paste control can paste and save a bare link
in two taps (+ then Paste). No clipboard reads happen before the user's action.
Invalid input stays in the composer with an error. A photo toolbar shortcut
opens the composer and system picker. Tags appear before attachment controls.

Incomplete notes and edits are saved as private local drafts, including attached
bytes. Writes are debounced and serialized off the UI actor. Session invalidation
and increasing revisions prevent delayed writes from resurrecting a discarded
draft or overwriting a newer snapshot. Closing dirty content offers Keep draft,
Discard, or Continue editing. Backgrounding also requests a draft flush. Drafts
are separate from saved notes and excluded from Library backup.

Card title/text opens the note; image/document opens its viewer directly. Generic
documents launch Quick Look after staging when supported, otherwise they remain
shareable. Editing a note focuses text automatically. Tapping card tags opens a
dedicated tag picker, with one explicit Done action to persist changes.

Long press selects the first note. Batch tag actions default to Add, with Remove
and Replace available explicitly; all modes validate tag IDs before changing
notes and save once. Archive/restore offers Undo of the most recent operation.
The prior context menu is replaced with a visible actions menu to avoid competing
long-press handlers. Preview height stays constant while metadata loads, and
repeated homepage occurrences have separate row identities.

Tap counts exclude typing, scrolling, loading and system permission/selection
prompts: plain note 2; quick link 2; note editing 3; quick tagging 3 for one tag;
primary image/document opening 1. Selecting N notes and assigning K tags via
long press takes N + K + 2 actions. Archive remains swipe + tap, with Undo.

Verification includes existing migrations/backups and new tests for draft
persistence, stale writes, independent draft keys, additive/removal tag semantics,
quick paste, save-and-add, discard, draft relaunch recovery, swipe/Undo, quick tags
and long-press selection. UI fixtures use an in-memory library; the draft relaunch
test uses a UUID-isolated temporary directory available only in DEBUG.
