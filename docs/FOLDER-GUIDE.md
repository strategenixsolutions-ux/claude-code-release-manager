# Folder Governance and Release Guide

**This folder is a shared product.** It is synced to a team and used as a shared Claude Code
workspace (agents, skills, the charter file). Because several people rely on it, changes to
its core are **requested, staged, and released**, not made live.

Read this before editing anything in the folder. Workspace-specific values (which paths are
core, where the queue lives, who the owner is, when the nightly cut runs) are in
`release-manager.config.json` at the workspace root.

---

## 1. The core rule: a synced folder has no merge

A sync client copies the whole tree and cannot merge two people's edits. If two people change
the same file, it keeps both as "conflicted copy" files, or one edit silently wins and the
other drifts away. A `.gitignore` protects **nothing**, because this is not a git repository:
the sync client copies every file regardless.

So core is not free-for-all edited. It ships in releases.

---

## 2. The flow: request to release

1. **Request.** Anyone files a change request: copy `docs/requests/_TEMPLATE.md` to
   `docs/requests/REQ-YYYYMMDD-<slug>.md`. One request is one file, so the intake never
   conflicts.
2. **Triage.** The release operator classifies it (new agent, new or updated skill, doc,
   fix), sets priority and risk, and asks questions on the request file itself.
3. **Build.** The change is staged in `docs/requests/<slug>/staged/`, laid out exactly as it
   will sit in core, and every staged file is pinned with its byte count and sha256. Core is
   not touched.
4. **Queue.** The `release-manager` agent records the item in
   `docs/releases/RELEASE-QUEUE.md` with its pins, shape, rollback, and approvals.
5. **Cut (off-hours).** On the scheduled run, approved items are gated, snapshotted, copied
   into core with `Copy-Item`, verified by hash and by a full inventory diff, and recorded in
   `CHANGELOG.md`, `docs/activity-log.md`, and `docs/releases/<version>/APPLY.md`.
6. **Rollback.** Each release keeps a snapshot of exactly what it replaced, so a bad change
   reverts to the previous release state with one command.

**Why off-hours:** writing to the folder while teammates have it open is when conflicted
copies appear. A quiet window keeps releases clean.

---

## 3. Roles

| Role | Who | Can |
|---|---|---|
| **Requester** | Anyone on the team | File requests, use released agents and skills, write to their own areas |
| **Release operator** | Whoever runs the cut, normally whoever is available that night | Triage, build staged changes, run gates, cut and roll back releases |
| **Workspace owner** | Named in `roles.owner` of the config | Signs off anything destructive or irreversible: deleting an agent or skill, a rollback that discards newer work, folder-wide permission or sharing changes |

There does not have to be a single maintainer. The operator role can rotate, which is why the
queue, the sha256 pins, and the inventory diff carry the proof instead of one person's memory.

Requesters do not live-edit core. A change reaches core through a release, whoever cuts it.

---

## 4. What is core

Core is whatever `corePaths` and `charterFile` in the config list. A typical set:

| Path | Contents | Change control |
|---|---|---|
| `CLAUDE.md` | The workspace charter | **Core**, via release |
| `.claude/agents/` | Agents | **Core**, via release |
| `.claude/skills/` | Skills | **Core**, via release |
| `.claude/settings.json` | Project settings and hooks | **Core**, via release |
| `.claude/settings.local.json` | Per-user local settings | **Local**, not shared, not core |
| `docs/FOLDER-GUIDE.md` | This file | **Core**, via release |
| `docs/releases/scripts/`, `docs/releases/templates/`, `scripts/` | The release tooling itself | **Core**, via release |
| `docs/requests/` | Intake queue, one file per request | **Open**: anyone adds a request file |
| `docs/requests/<slug>/staged/` | A built-but-unreleased change | Operator, at build time |
| `docs/releases/<version>/` | `APPLY.md`, `snapshot/`, `snapshot-hashes.csv` | Operator, at release. **Never edited afterward** |
| `docs/releases/RELEASE-QUEUE.md` | Pending, Scheduled, and shipped-item records | The `release-manager` agent |
| `CHANGELOG.md`, `docs/activity-log.md` | Release history and detail | Operator, at release |
| Everything else (working output, drafts, per-user areas) | Normal work | **Open**, no release needed |

Paths the team is allowed to write outside a release, but that sit under a core path, go in
`excludePaths` so they do not trip the drift gate. Every exclusion is reported with a file
count on every inventory run, so a stale one is visible.

You do not have to reorganize an existing folder to adopt this. Start with `.claude/` and the
charter, and widen `corePaths` in its own release later. Every inventory compared against a
baseline must use the same scope as that baseline.

---

## 5. Versioning and releases

- **Version scheme:** date-based `YYYY.MM.DD` by default. A second release in one day gets a
  letter suffix (`2026.01.15b`).
- **`CHANGELOG.md`** holds one summary entry per release. **`docs/activity-log.md`** holds the
  detail. **`docs/releases/<version>/APPLY.md`** holds the mechanical proof: gates, commands,
  hashes, inventory diff, rollback.
- **Baseline** is the last changelog entry: the last release **actually installed**. Its entry
  records the core file count, total bytes, and charter hash it left behind, and its
  post-install inventory CSV is kept in `docs/releases/`. The next cut proves core did not
  drift by reproducing those.
- **Rollback:** before installing, affected core is copied to
  `docs/releases/<version>/snapshot/` with a hash manifest. The changelog entry carries the
  restore command.
- **Cadence:** nightly at the configured `schedule.cutTime`, started by a scheduled task (see
  the README). Urgent fixes may ship out of band; everything else waits for the next cut.

### The release ritual

When the scheduled task fires, or an operator opens the folder in Claude Code and says
**"run the nightly release"**, the `release-manager` agent:

1. Reports what is Pending and Scheduled.
2. Runs the gates, including the drift check against the baseline.
3. If items are approved to install: snapshots, installs with `Copy-Item`, verifies pins and
   the inventory diff, writes the changelog, activity log, and `APPLY.md`, and moves items to
   Released.
4. Returns short release notes.

If nothing is approved, it reports and cuts nothing.

### Rules with teeth

- **Copy bytes, never rewrite them.** Install with `Copy-Item`. Any tool that normalizes line
  endings invalidates the hash pins, and the pins are the only proof available outside a
  repository.
- **Approval to queue is not approval to install, and approval to install is not an
  instruction to cut on demand.** Starting the nightly run is not install approval. Any
  departure from the recorded window is flagged at the top of the record.
- **A gate acceptance goes stale.** Accepting a drift delta covers exactly the deltas shown,
  from a gate run in the same session as the cut. Never carry an acceptance across sessions
  or days.

*(If the team outgrows this, with many concurrent contributors and real merge needs, move the
workspace to a git repository. A synced folder plus this queue is the lightweight option.)*

---

## 6. Secrets and safety

- **Never** place `.env` files, API keys, OAuth tokens, passwords, or any credential in this
  folder. The sync client pushes it to everyone.
- **Never** place customer data or PII in the folder.
- Secrets live in each user's local environment or a credential store.
- **No destructive actions** without the workspace owner's explicit go-ahead.
- If you spot a conflicted-copy file, do not guess. Flag it to the release operator to
  reconcile, then delete it.

---

## 7. Per-user setup

The shared folder carries the project-scoped parts: agents, skills, the charter, docs. It
does not carry machine-level installs. Each teammate sets up Claude Code, their own MCP
connector sign-ins, and their own memory, which is per user and not shared.

---

## 8. Quick reference

- **Want a change?** Copy `docs/requests/_TEMPLATE.md`, fill it in, save it in
  `docs/requests/`. Do not edit core directly.
- **Shipping a release?** Gates, snapshot, `Copy-Item`, verify, then changelog, activity log,
  `APPLY.md`, queue, announce.
- **Secrets?** Never in the folder.
