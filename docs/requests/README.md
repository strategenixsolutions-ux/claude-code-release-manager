# Change requests

Core files in this workspace (see `corePaths` in `release-manager.config.json`) ship in
releases. To get a change into core, file a request here instead of editing core directly.

## How to file one

1. Copy `_TEMPLATE.md` to `REQ-YYYYMMDD-<short-slug>.md` in this folder, for example
   `REQ-20260115-summarize-skill.md`.
2. Fill in the front matter and the three sections. Leave `status: new` and
   `target_release` empty.
3. Save. That is the whole step. One request is one file, so two people filing at once never
   collide.

Or ask Claude in this workspace: "file a release request for <change>".

## What happens next

- The release operator triages it, sets `status: triaged`, and asks questions in the Notes
  section of your file.
- The change is built in `<slug>/staged/` next to the request and pinned by hash. Core is not
  touched.
- The `release-manager` agent adds it to `../releases/RELEASE-QUEUE.md`.
- Once approved to install, it ships in the next scheduled release and your file gets
  `status: released` and `target_release: <version>`.

## Rules

- No secrets, credentials, or customer data in a request or a staged tree.
- Do not edit a staged tree after it is pinned. Ask for a rebuild instead; the release stops
  if any pin does not match.
