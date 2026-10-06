# Release notes template (what the team actually reads)

Short. The team does not need the hash tables; the operator has those in `APPLY.md`.
Aim for something that fits in a chat post or a five-line email.

---

**<WORKSPACE NAME> release `<version>`** shipped <day>, <time>.

**What is new**
- <Capability, in terms of what someone can now do, not what file changed.> Say it by
  asking for it: "ask for <the thing> and you get <the result>."

**What changed in something you already use**
- <The behavior difference, and whether you need to do anything. Usually you do not.>

**Nothing to install.** The folder syncs. Close and reopen the workspace in Claude Code if
you had it open during the release window.

**Known gaps / coming next**
- <Anything deliberately left for the next release, so nobody files a request for work
  already queued.>

**Something off?** <How to report it: file a request in `docs/requests/`, or message the
release operator.> Rollback for this release is one command, so say so if the change is riskier
than usual.

---

## Announcing a rollback

Same shape, shorter, and lead with the state:

**<WORKSPACE NAME> release `<version>` was rolled back <day>, <time>.** Core is back at
`<prior version>`. <One line on what went wrong, in plain terms.> <What, if anything, the
team should redo.> The fix is queued for `<next version>`.
