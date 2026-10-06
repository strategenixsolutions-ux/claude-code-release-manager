# Release Queue

Maintained by the `release-manager` agent. See `../FOLDER-GUIDE.md` for the process and
`../../CHANGELOG.md` for shipped history. Item format:
`templates/QUEUE-ITEM-TEMPLATE.md`.

Version scheme: date-based `YYYY.MM.DD`, letter suffix for a same-day second release.

**Standing release window:** nightly at the time in `release-manager.config.json`
(`schedule.cutTime`, retry at `schedule.retryTime`). A scheduled task starts it, or any
release operator can say "run the nightly release".

**Standing note:** starting the window is not install approval. "Run the nightly release"
runs the gates and reports. Only items whose record says "Approved to install" are written
to core.

**Baseline:** none yet. The first release records its post-install file count, total bytes,
and charter hash here and in `CHANGELOG.md`.

---

## Just shipped

_Nothing yet._

## Scheduled

_Nothing scheduled._

| ID | Problem | Target version | Window | Approved to install |
|---|---|---|---|---|

## Pending

_Nothing pending._

| ID | Problem | Files | State | Queued |
|---|---|---|---|---|

---

## Item records

Full records, newest last. Never renumbered or removed; an item's heading changes from
PENDING to SCHEDULED to RELEASED as it moves.

<!--
### QUEUE-YYYYMMDD-A - <the problem in one line> (additive, 3 files, STAGED) - PENDING
(copy the rest from templates/QUEUE-ITEM-TEMPLATE.md)
-->
