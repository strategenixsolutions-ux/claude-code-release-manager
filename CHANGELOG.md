# Release Changelog

Release summaries for this shared workspace. One entry per release, newest first. Detailed
records live in `docs/activity-log.md`; the mechanical record of each cut lives in
`docs/releases/<version>/APPLY.md`; the process is in `docs/FOLDER-GUIDE.md`.

Version scheme: date-based `YYYY.MM.DD` (a same-day second release gets a letter suffix).

**The newest entry in this file is the baseline**, meaning the last release actually
installed. Anything in core that changed after it and is not in the release queue is
unreleased drift.

Entry shape:

```
## YYYY.MM.DD - <what changed, in one line>

**Flagged at the top.** (delete if nothing departs from the record)
- <cut outside the window, relayed authorization, scope change mid-run>

Shipped YYYY-MM-DD at HH:MM <timezone>. Baseline: <prior version>. Items: <QUEUE IDs>.
Shape: <N new files, N overwrites, N deletions>, no charter edit.
- **Checks:** drift gate 0/0/0 vs baseline. Pins N of N. 0 secrets, PII, user paths.
  Inventory <before> to <after>, <added>/<removed>/<modified>, INVENTORY DIFF PASSED.
- **New baseline:** `docs/releases/baseline-inventory-YYYY.MM.DD.csv`, <N files>,
  <total bytes>. Charter <bytes> <sha256 prefix>...<suffix>.
- **Rollback:** `<exact command>`
- **Detail:** `docs/releases/YYYY.MM.DD/APPLY.md`
```

---

_No releases yet._
