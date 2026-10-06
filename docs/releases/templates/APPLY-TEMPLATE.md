# Release `<version>`: APPLY

**Status: <STAGED, NOT INSTALLED | INSTALLED AND VERIFIED | ROLLED BACK>.** One sentence on
the bottom line: what is in core now and whether every hash matched.

- **Version:** `<YYYY.MM.DD>`
- **Baseline:** `<prior version>` (the last entry in `CHANGELOG.md`, and the last release
  actually installed)
- **Cut:** <YYYY-MM-DD> at <time and timezone>, <off-hours | in-window>, <attended | unattended>
- **Cut by:** `release-manager`, on <name>'s install approval, recorded in the queue item
- **Items:** <N> (`<QUEUE IDs and one-line descriptions>`)
- **Deliberately NOT in this release:** `<QUEUE IDs>` (see section 6)
- **Shape:** <N new directories, N new files, N overwrites>. State zeros explicitly:
  zero deletions, zero moves, zero renames, no charter-file edit.

---

## 0. Flag for the operator and owner (delete this section if there is nothing to flag)

**Anything that departs from the written record goes here, first, before the detail.** A
cut outside the scheduled window, an authorization relayed into a session rather than
written in the queue, a scope change decided mid-run.

Say what the record said, what happened instead, on whose instruction, and why proceeding
was defensible on risk (or was not). Then point at the rollback. The purpose of this
section is that the operator and the workspace owner read it rather than discover it.

---

## 1. Pre-install gates, all passed before anything was written

| Gate | Expected | Observed | Result |
|---|---|---|---|
| Staged tree exists | `docs/requests/<slug>/staged/` | | |
| Staged file count | exactly <N> | | |
| Staged hashes | all <N> match the queue pins | | |
| No build artifacts in staged | 0 `__pycache__`, 0 temp files | | |
| Target state | <absent for additive / matches baseline for overwrite> | | |
| Core undrifted since baseline | matches `<prior version>` post-cut state: <N> files, charter `<hash>` | | |
| Secret / PII / credential scan | 0 hits | 0 hits | |
| Hardcoded user paths or usernames | 0 hits | 0 hits | |

The core-undrifted check is worth naming explicitly: the baseline CHANGELOG entry records
a file count and a charter hash as the state it left behind. Reproducing both proves nobody
live-edited core between the two releases.

## 2. Install method

`Copy-Item` throughout. **No file-writing tool, no file-editing tool, and no line-ending
normalization, at any step.**

```powershell
$staged = "<WORKSPACE_ROOT>\docs\requests\<slug>\staged"
$target = "<WORKSPACE_ROOT>\.claude\skills\<name>"
New-Item -ItemType Directory -Force -Path $target
Copy-Item -Path "$staged\*" -Destination $target -Recurse -Force
```

**Why byte-exactness is mandatory:** note here which staged files are CRLF and which are
LF. The pins were taken over those bytes as they stand, so any normalizing step invalidates
them.

### Corrections made during the run (delete if none)

Record any mistake and its fix: what the wrong command did, how the blast radius was
confirmed, what was removed, and that verification was re-run against the corrected state
only. A record that hides an intermediate state is worthless the day someone needs it.

## 3. Post-install verification, all passed

| Installed path | Bytes | sha256 | Pin match |
|---|---|---|---|
| | | | |

Full values in `snapshot-hashes.csv`.

**Full before-and-after sha256 inventory of core (the configured corePaths plus the charter file)**,
since this is not a git repository:

| Measure | Value |
|---|---|
| Files before | |
| Files after | |
| Added | |
| Removed | |
| Modified | |
| Charter file across the cut | <byte-identical at N bytes, `<hash>`> or <changed from X to Y, intentionally> |

Note anything pre-existing that was deliberately left alone (stray build artifacts
elsewhere in the tree, for instance), because removing them would show up as core
modifications in this diff.

**Live confirmation of harness pickup:** whether the new skill or agent actually appeared
in the session roster. Direct proof, not an assumption.

## 4. Anything shipped verbatim that carries a decision (delete if none)

Where a piece of the change encodes a policy or an exception, state that it shipped
unedited and give the mechanical proof: the file hash held through the cut. Then restate
the exception in its narrow form, so a later reader cannot widen it by misremembering.

## 5. Rollback

```powershell
<the exact command>
```

What state core returns to, and what else has to be reverted with it: the `CHANGELOG.md`
entry, the `docs/activity-log.md` entry, and moving the items back from Released to
Scheduled.

**If rollback deletes a skill or agent from the shared folder, it needs the workspace owner's
explicit go-ahead.** List the independent surviving copies of the bytes (this release's
`snapshot/`, the staged tree, core itself until the command runs), so the risk of the
rollback is visible too.

## 6. What was deliberately left out

For each item not included: that it was deliberate, that it was never approved for install
(or the reason it was held), that it remains Scheduled with its staged tree and pins
untouched, and whether this release makes it any harder to ship next time. If a defect it
fixes is still live in core, say that plainly here.

## 7. Follow-ups carried forward, not part of this cut

Anything expected later that does not block this release, with what it will take when it
arrives.
