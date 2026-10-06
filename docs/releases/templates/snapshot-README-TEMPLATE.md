# Snapshot for release `<version>`

This directory holds the **exact bytes** involved in release `<version>`, kept so the
release can be reversed without reconstructing anything.

- **Taken:** <YYYY-MM-DD> at <time>, before the install wrote anything.
- **Contains:** <what was copied: the affected core paths, or the whole `.claude/` tree
  plus the charter file>.
- **Layout:** the same relative layout as core, so a restore is a copy back and not a
  reassembly.
- **Manifest:** `../snapshot-hashes.csv`, with one row per file: snapshot path, installed
  path, bytes, sha256, and the pre-release state of the target
  (`did-not-exist`, or its prior sha256 for an overwrite).

## Restore

```powershell
<the exact restore command for this release>
```

For an **overwrite**, restoring means copying the snapshot bytes back over core. For an
**addition**, restoring means removing what was added; the snapshot then exists only as a
record and as a spare copy of the bytes.

## Rules

- **Never edited after the cut.** This directory is the record. If it changes, it proves
  nothing.
- Reverting also means reverting the bookkeeping: the `CHANGELOG.md` entry, the
  `docs/activity-log.md` entry, and moving the items back from Released to Scheduled in
  `docs/releases/RELEASE-QUEUE.md`.
- **No secrets, credentials, or PII in a snapshot.** It syncs to the whole team like
  everything else in the folder.
