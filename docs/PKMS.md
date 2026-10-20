# PKMS Dropbox — contract and operation

The PKMS tab is a folder tree, not a sidebar. Only Markdown files (.md/.markdown) are indexed; folders expand inline. Tapping a document opens a single always-editable, syntax-styled Markdown document. No separate reading/editing modes, note-link graph or automatic migration of Bloom's media library.

Original Markdown lives on Dropbox. Bloom caches opened documents, not every document body or media attachment. Local drafts are written atomically in Application Support/PKMS with iOS data protection. The file index is paginated, recursive only within the user-selected root, and refreshed incrementally using Dropbox cursors. The app synchronizes while active; iOS suspension does not guarantee immediate cloud delivery. Pending local changes are explicitly shown and retried on foreground/reconnection/manual refresh. Do not describe the cache as an independent off-device backup.

## Dropbox application setup (required once)

1. In https://www.dropbox.com/developers/apps create a Scoped access app with Full Dropbox access so existing PKMS folders can be selected. App-folder access would only expose an isolated /Apps folder, requiring migration.
2. Enable files.metadata.read, files.content.read, files.content.write.
3. Register exact redirect URI `bloom-dropbox://oauth`.
4. Enter the public App key in Bloom > PKMS > Settings, then authorize Dropbox and choose the root folder. No App secret or password is bundled. Development apps may require enabling additional users; public distribution is subject to Dropbox review/production requirements.

Authentication uses ASWebAuthenticationSession, random state, SHA256 PKCE, short-lived access tokens and a refresh token kept in the iOS Keychain. A cached workspace is bound to its first account. Disconnect retains local content; reconnecting a different account is rejected. OAuth callbacks are not treated as captured links. Re-signing may change Keychain access: reauthorization may be necessary, but document cache is separate.

## Integrity

Uploads use file IDs (survive renames) and update mode with the exact base revision, strict conflict checking, no autorename or unconditional overwrite. Acknowledgment updates only the uploaded baseline; typing during the request remains dirty. New remote revisions are reconciled against the local baseline. Divergence preserves local and remote text and stops upload until the user chooses. Choosing a version creates a local recovery snapshot. Another remote edit after that choice is checked again.

Remote deletion never triggers recreation or automatic local deletion. The original cached text can be shared/exported. This version deliberately provides no remote delete/rename/create actions. Changing the selected folder is blocked while drafts are pending. Cursor reset rebuilds metadata without discarding drafts. Local storage failure blocks cloud sync and reports unsaved in-memory edits. UTF-8 is preserved (including frontmatter, line endings and unknown Markdown); unsupported encodings and documents larger than 8 MB are rejected before editing.

## Local category pins

Pins are per note/category, not global favorites. A pinned note becomes a full-width title/disclosure row above the category grid, with no body or image preview and no duplicate grid tile. Removing the category assignment clears that pin. Optional stored fields and backup records remain backward compatible. PKMS documents themselves are not duplicated into the media library or implicitly assigned its categories.

## Verification

Automated tests use a Dropbox protocol fixture: offline draft persistence/restart, successful conditional upload, concurrent remote edit and explicit conflict resolution, remote deletion, acknowledgment while typing, Unicode HTTP headers, corrupt-cache reporting, category pin scoping and backup roundtrip. Native UI tests cover PKMS setup and live Markdown editing against an isolated local cache, with no user account/network. These do not replace a live OAuth/Dropbox smoke test: authorization, two-device edits, offline resume, revoked token and conflict must be checked with a configured Dropbox app/account before claiming stable end-to-end sync.

Future web UI can authorize against the same Dropbox files. No web app is included in this change. File attachments/images are not fetched or rendered as embedded media in the initial native Markdown editor; Markdown source is retained.
