# Claude Code Release Manager

Change control for a shared Claude Code workspace that lives in a synced folder.

## The problem

A team shares one Claude Code workspace (agents in `.claude/agents/`, skills in
`.claude/skills/`, a `CLAUDE.md` charter) through OneDrive, Dropbox, Google Drive, or a
network share. Those tools copy files; they do not merge them. When two people edit the same
agent or skill file, the sync client keeps both as "conflicted copy" files, or one edit wins
and the other is lost without anyone noticing. Over a few weeks the shared agents drift: each
person's copy behaves a little differently, and nobody can say what changed or when.

A `.gitignore` does nothing here, and moving everyone to git is often not realistic for a
team of non-developers.

## What this does

It treats the workspace core as a product that ships in releases:

```
request  ->  staged build  ->  queue  ->  scheduled cut  ->  (rollback if needed)
           (pinned by sha256)         (gates, snapshot, Copy-Item install,
                                       hash-verified inventory diff, records)
```

1. **Request.** Anyone drops a one-file request in `docs/requests/`. One file per request, so
   intake never conflicts.
2. **Staged build.** The change is built in `docs/requests/<slug>/staged/`, laid out exactly as
   it will land in core, and every file is pinned with its byte count and sha256.
3. **Queue.** The `release-manager` Claude Code agent records the item in
   `docs/releases/RELEASE-QUEUE.md` with its pins, shape, rollback, and two separate approvals:
   approved to queue, approved to install.
4. **Scheduled cut.** Off-hours, a scheduled task runs `claude -p "run the nightly release"`.
   The agent runs the gates (pins still match, core has not drifted since the last release, no
   secrets or user paths), takes a rollback snapshot, installs with `Copy-Item` (bytes, never
   rewritten), re-hashes everything, and diffs a full before/after inventory of core to prove
   nothing else changed. It writes `CHANGELOG.md`, `docs/activity-log.md`, and
   `docs/releases/<version>/APPLY.md`.
5. **Rollback.** Each release keeps a snapshot of exactly the bytes it replaced, plus a hash
   manifest, so reverting is one copy command.

If nothing is approved to install, the nightly run checks for drift, reports, and changes
nothing.

## What is in the repo

```
release-manager.config.json        all workspace-specific settings
CLAUDE-snippet.md                  paste into your CLAUDE.md
.claude/agents/release-manager.md  the agent
docs/FOLDER-GUIDE.md               governance: core vs open, roles, versioning, rules
docs/activity-log.md               starter
docs/requests/README.md            how to file a request
docs/requests/_TEMPLATE.md         request template
docs/releases/RELEASE-QUEUE.md     empty queue with format
docs/releases/templates/           APPLY, queue item, release notes, snapshot README
docs/releases/scripts/             PowerShell proof layer (inventory, diff, pins, snapshot)
scripts/nightly-release.cmd        launcher the scheduled task runs
scripts/Register-NightlyRelease.ps1    creates the two scheduled tasks
scripts/Unregister-NightlyRelease.ps1  removes them
CHANGELOG.md                       starter
```

## Requirements

- Windows with PowerShell 5.1 or later (the scripts use `Get-FileHash`, `Copy-Item`, and the
  ScheduledTasks module that ships with Windows).
- Claude Code installed and signed in on the machine that runs the nightly cut.

## Install

1. Copy these into your workspace root, keeping the paths:
   `release-manager.config.json`, `.claude/agents/release-manager.md`, `docs/`, `scripts/`,
   and `CHANGELOG.md` (skip `CHANGELOG.md` or `docs/activity-log.md` if you already have one
   and add the entry shape from ours).
2. Paste `CLAUDE-snippet.md` into your `CLAUDE.md`.
3. Edit `release-manager.config.json` (see below).
4. If the files came from a zip download, read the scripts, then clear the download flag:
   `Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File`.
5. Take the first baseline, so the first release has something to prove drift against:

   ```powershell
   cd <workspace>\docs\releases\scripts
   .\Get-CoreInventory.ps1 -OutFile ..\baseline-inventory-initial.csv
   ```

   Record the printed file count, total bytes, and charter hash at the top of
   `CHANGELOG.md` as an initial baseline entry.
6. Optional: schedule the nightly run (below).

Then announce it: core changes go through `docs/requests/` from now on.

## Configuration

Everything workspace-specific is in `release-manager.config.json`. Relative paths resolve
against the workspace root, and a relative `workspaceRoot` resolves against the folder that
holds the config, so the default `"."` works when the config sits at the root.

| Key | Meaning |
|---|---|
| `workspaceRoot` | The shared folder. `"."` means the config's own folder. |
| `charterFile` | The charter, usually `CLAUDE.md`. Always inventoried. |
| `corePaths` | Files and folders that only change through a release. |
| `excludePaths` | Prefixes under `corePaths` that people may write outside a release (a log folder, for example). Reported with a count on every run. |
| `skillsPath` | Where `Test-SkillReferences.ps1` looks for `SKILL.md` files. |
| `requestsDir`, `releasesDir`, `queueFile`, `changelogFile`, `activityLogFile` | Where the records live. |
| `roles.owner` | Name of the role that approves destructive moves (the agent uses this wording). |
| `version` | Version scheme. Default: date-based `yyyy.MM.dd`, letter suffix for a second same-day release. |
| `schedule.timezone` | `Local`, or a Windows time zone id such as `Eastern Standard Time`. Cut and retry times are read in this zone and converted to the machine clock. |
| `schedule.cutTime`, `schedule.retryTime` | `HH:mm`. Main run and the retry that only works if the main run failed. |
| `schedule.taskFolder`, `schedule.taskName` | Where the tasks appear in Task Scheduler. |
| `schedule.wakeToRun` | Wake the machine for the run. |
| `schedule.claudeExe`, `schedule.claudeArgs`, `schedule.prompt` | What the launcher runs. `claudeExe` can be a full path if `claude` is not on the task's PATH. |
| `schedule.logFile` | Run log, relative to the workspace. |
| `schedule.stampFile` | Success stamp used by the retry. Empty means a per-machine file under `%LOCALAPPDATA%\claude-release-manager\`. |

Changing `corePaths` or `excludePaths` changes what an inventory counts. Take a new baseline
in the same release that changes the scope, or the next drift gate compares unlike with like.

## Schedule the nightly run (Windows)

From the workspace root:

```powershell
.\scripts\Register-NightlyRelease.ps1 -WhatIf   # shows what it would create
.\scripts\Register-NightlyRelease.ps1
```

This registers two tasks under `schedule.taskFolder`:

- `<taskName>` at `cutTime`: runs `scripts\nightly-release.cmd scheduled`.
- `<taskName>-Retry` at `retryTime`: runs `scripts\nightly-release.cmd retry`, which exits
  immediately if this machine already logged a successful run today.

Each run appends to `schedule.logFile`. To test without waiting:
`Start-ScheduledTask -TaskPath '\ClaudeReleaseManager\' -TaskName 'NightlyRelease'`.
To remove: `.\scripts\Unregister-NightlyRelease.ps1`.

Things to know:

- **Register on one machine only.** Two machines cutting the same synced folder at once is
  the conflict this exists to prevent.
- **The tasks run only while you are signed in**, because Claude Code keeps its sign-in in
  your user profile. They are set to start when available, so a trigger missed while the
  machine was asleep or off fires when it comes back. A trigger missed while you were signed
  out (after an update reboot, for example) is not recovered. Check the log if a night is
  missing.
- **The run is unattended**, so Claude Code cannot ask for permission. Any tool the agent
  needs (PowerShell for the scripts, file writes for the records) must be allowed in your
  project's `.claude/settings.json`, or passed through `schedule.claudeArgs`. Without that it
  can still read, gate, and report. Decide deliberately how much an unattended run may write.
- The schedule is a convenience. Any operator can open the workspace in Claude Code and say
  "run the nightly release" at any time.

### macOS and Linux (untested)

The PowerShell scripts run on PowerShell 7 (`pwsh`) in principle, but they were written and
tested on Windows with backslash paths and have not been tested elsewhere. The launcher and
scheduler scripts are Windows-only. To schedule on macOS or Linux, run the equivalent of the
launcher from cron or launchd, for example:

```
0 1 * * *  cd /path/to/workspace && claude -p "run the nightly release" >> docs/releases/nightly.log 2>&1
```

and add your own retry and success-stamp logic if you need it.

## Using it day to day

- "File a release request for a skill that summarizes meeting notes." Creates a request file.
- "Build and stage REQ-20260115-summarize-skill." Builds and pins it, queues it as Pending.
- "What is unreleased?" Lists Pending and Scheduled items and any unqueued drift in core.
- "Approve QUEUE-20260115-A to install tonight." Records install approval in the queue item.
- "Run the nightly release." Gates, and installs only what is approved.
- "Roll back 2026.01.15." Restores from the snapshot after the owner confirms.

## Limits

- This is not version control. There is no branching or merging. It gives you one ordered
  stream of releases, each provable and reversible. If you need merges, use git.
- The agent follows the procedure; the scripts provide the evidence. Read the `APPLY.md`
  records, especially early on.
- Secrets must never live in the synced folder. Nothing here can protect a secret once the
  sync client has copied it.

## License

MIT. See `LICENSE`.
