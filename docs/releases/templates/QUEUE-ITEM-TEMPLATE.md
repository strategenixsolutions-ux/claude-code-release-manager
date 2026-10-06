### QUEUE-YYYYMMDD-<letter> - <the problem, in one line, not the solution> (<core | doc | additive>, <N> files, <STAGED | BUILT | NOT YET AUTHORED>) - <PENDING | SCHEDULED for `<version>` | RELEASED in `<version>`>

**The problem.** What is wrong or missing today, in terms of what it costs someone. If it
is a defect, how it shows up. If it is new capability, what nobody can do right now.

**Source.** `docs/requests/REQ-YYYYMMDD-<slug>.md`, or "found during <what>", or the
person who raised it.

**Shape of the change.**

| Path in core | Action | Bytes | sha256 pin |
|---|---|---|---|
| `.claude/skills/<name>/SKILL.md` | new / overwrite / delete | <bytes> | `<full sha256>` |

- **Staged at:** `docs/requests/<slug>/staged/`, laid out exactly as it lands in core.
- **File count:** <N>. **Line endings:** note any CRLF files, because the pins were taken
  over those bytes and a normalizing install would invalidate them.
- **Additive or not:** state plainly whether any existing file is touched. "Purely
  additive, zero existing files modified" is the cheapest possible release to reverse, and
  worth saying when it is true.
- **Charter file edit needed?** If a routing row or rule is required, that is a second file
  in the release and it changes the rollback. If the capability is discovered by the
  harness on its own, say so and skip the edit.

**Verification done at build time.** What was run, what the output was. Not "tested" but
the actual evidence: counts that matched, a render that was looked at, a regression example
whose expected values were reproduced.

**Risk and blast radius.** What breaks if this is wrong, and who notices.

**Rollback for this item.**

```powershell
<the exact command, or the exact prior bytes to restore from the snapshot>
```

**Approvals** (two separate gates, recorded separately):

- Approved to **queue**: <name>, <date>.
- Approved to **install**: <name>, <date>, or NOT YET APPROVED.
- Off-hours cut pre-authorized: <yes, scoped to what | no>.

**Do not cut ahead of the scheduled window on the agent's own initiative.** If the
release operator moves it up, that instruction is recorded here before the cut, or flagged at the
top of the release record if it was relayed into a session instead.
