<!--
Paste the section below into your workspace's CLAUDE.md (the charter file). Adjust the
owner wording if your config uses a different roles.owner value.
-->

## Core ships in releases

This workspace is synced to several people through a sync client that cannot merge. Two
people editing the same file produces a conflicted copy or silent drift. So **core** is not
live-edited. Core is every path listed in `corePaths` and `charterFile` in
`release-manager.config.json` (by default `CLAUDE.md`, `.claude/agents/`, `.claude/skills/`,
`.claude/settings.json`, `docs/FOLDER-GUIDE.md`, and the release tooling).

- A core change is requested in `docs/requests/`, built in a staged tree under
  `docs/requests/<slug>/staged/`, pinned by sha256, queued by the `release-manager` agent in
  `docs/releases/RELEASE-QUEUE.md`, and installed in the scheduled off-hours release with a
  rollback snapshot and a hash-verified inventory diff. Process: `docs/FOLDER-GUIDE.md`.
  History: `CHANGELOG.md`.
- Everyone still gets the full assistant for normal work: drafts, research, deliverables,
  anything outside core. Only systemic change to the workspace itself is gated.
- A new or changed skill, agent, or doc is **not shipped** until it is released. Queue it via
  the `release-manager` agent rather than calling it done.
- The release operator is whoever runs the cut. Approval to queue is not approval to install,
  and approval to install is not an instruction to cut early.
- Destructive or irreversible moves (deleting an agent or skill, a rollback that discards
  newer work, folder-wide permission or sharing changes) need the **workspace owner's**
  explicit go-ahead, not the current user's.
- Install by copying bytes (`Copy-Item`). Any tool that rewrites or normalizes line endings
  invalidates the sha256 pins, which are the only proof available outside a git repository.
- Never write secrets, credentials, or PII into the folder. The sync client pushes it to the
  whole team, and a `.gitignore` protects nothing here.
