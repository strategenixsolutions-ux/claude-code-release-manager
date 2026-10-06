# Scripts: the proof layer

A synced folder is not a git repository: there is no history, no diff, and no way to answer
"did anything else change?" without computing it. These scripts compute it with sha256.

Every script reads defaults from `release-manager.config.json` at the workspace root (through
`ReleaseConfig.ps1`). An explicit parameter always wins over the config.

| Script | When | What it answers | Writes |
|---|---|---|---|
| `Get-StagedPins.ps1` | Build time, then again at install time | "Is this staged tree exactly what was built, and which files are CRLF?" | The pins CSV you name |
| `Get-CoreInventory.ps1` | Drift gate, and before and after an install | "What is in core right now, byte for byte?" | The inventory CSV you name |
| `Compare-CoreInventory.ps1` | Drift gate, and right after the install | "Did exactly the intended files change, and nothing else?" | Optional markdown report |
| `New-ReleaseSnapshot.ps1` | Before the install writes anything | "If this goes wrong, what bytes do I restore, and from where?" | Only `<releasesDir>/<version>/` |
| `Test-SkillReferences.ps1` | Gate, report only | "Does every `references/` file a SKILL.md names exist?" | Nothing |
| `ReleaseConfig.ps1` | Loaded by the others | Reads the config | Nothing (the `-AsCmd` mode creates the log and stamp folders) |

None of them reach the network, install anything, or touch anything outside the workspace,
except `ReleaseConfig.ps1 -AsCmd`, which creates the success-stamp folder under
`%LOCALAPPDATA%`. PowerShell 5.1 or later, no modules.

## A full cut, in order

```powershell
$ws   = "<WORKSPACE_ROOT>"
$rel  = "2026.01.15"
$slug = "my-change"
$base = "$ws\docs\releases\baseline-inventory-<previous version>.csv"
cd "$ws\docs\releases\scripts"
New-Item -ItemType Directory -Force -Path "$ws\docs\releases\$rel" | Out-Null

# 1. Gate: staged tree still matches the pins taken at build time.
.\Get-StagedPins.ps1 -StagedRoot "$ws\docs\requests\$slug\staged" `
  -VerifyAgainst "$ws\docs\requests\$slug\pins.csv"
if ($LASTEXITCODE -ne 0) { throw "Pins do not match. Stop." }

# 2. Gate: core has not drifted since the baseline release.
.\Get-CoreInventory.ps1 -OutFile "$ws\docs\releases\$rel\pre.csv"
.\Compare-CoreInventory.ps1 -Before $base -After "$ws\docs\releases\$rel\pre.csv" -ExpectedAdded 0
if ($LASTEXITCODE -ne 0) { throw "Core drifted since the baseline. Stop and report." }

# 3. Report-only gate.
.\Test-SkillReferences.ps1

# 4. Rollback snapshot, before anything is written.
.\New-ReleaseSnapshot.ps1 -Version $rel -TargetPath '.claude/skills/my-skill'

# 5. Install. Copy-Item only. No rewriting tool, no line-ending normalization.
$target = "$ws\.claude\skills\my-skill"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path "$ws\docs\requests\$slug\staged\*" -Destination $target -Recurse -Force

# 6. Verify: installed files match their pins, and nothing else moved.
.\Get-StagedPins.ps1 -StagedRoot $target -VerifyAgainst "$ws\docs\requests\$slug\pins.csv"
.\Get-CoreInventory.ps1 -OutFile "$ws\docs\releases\$rel\post.csv"
.\Compare-CoreInventory.ps1 -Before "$ws\docs\releases\$rel\pre.csv" `
  -After "$ws\docs\releases\$rel\post.csv" -ExpectedAdded 3 `
  -OutFile "$ws\docs\releases\$rel\inventory-diff.md"
Copy-Item "$ws\docs\releases\$rel\post.csv" "$ws\docs\releases\baseline-inventory-$rel.csv"

# 7. Only now write the CHANGELOG entry, the activity log, and APPLY.md.
```

The staged tree in step 1 mirrors the install target, so `staged/` here holds the contents
of `my-skill/`. For a release that touches several core locations, stage each under its full
core-relative path and copy per location.

`-ExpectedAdded` (with `-ExpectedRemoved` and `-ExpectedModified`, both defaulting to 0) makes
the diff fail with exit code 1 instead of printing something nobody reads. Use it on every
cut, especially an unattended one.

## Notes

- **Nothing is excluded from the inventory except `excludePaths`.** Build artifacts are
  supposed to show up: if a `__pycache__` appears in the diff, the install created it.
- **Relative paths come from `Get-Item`, not `Resolve-Path`.** `Get-Item` expands 8.3 short
  names to the long form that `Get-ChildItem` reports. Mixing the two silently truncates
  every relative path by the length difference.
- **The snapshot layout drops a leading `.claude\`**, so `snapshot/skills/x/SKILL.md` maps to
  `.claude/skills/x/SKILL.md`. The manifest records both paths.
- **A snapshot taken after the install proves nothing.** Take it first. Re-run with
  `-PostInstall` afterward to keep spare copies of the files the release added. It never
  touches the pre-install copy of a file the release overwrote: that copy is the rollback.
- **Scripts downloaded as a zip carry mark-of-the-web.** After reading them, clear it with
  `Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File`. A `RemoteSigned` execution policy
  then runs them.
