<#
.SYNOPSIS
    Checks that every references/... path a skill's SKILL.md names resolves to a real file.

.DESCRIPTION
    Read-only. Scans every SKILL.md under the skills folder (recursively), finds each path
    of the form references/<name>.<ext> in its text, and resolves it relative to the folder
    that holds that SKILL.md. Prints one line per missing target and a one-line result for
    the gate record.

    Why it exists: a skill that names a reference file which never shipped fails quietly,
    and the person using it finds out mid-task. This turns that class of defect into a gate
    result.

    Report-only by default: it exits 0 even when targets are missing, because a missing
    reference is a content defect to queue, not evidence that a release would corrupt core.
    Pass -FailOnMissing to exit 1 instead.

.PARAMETER WorkspaceRoot
    Top of the shared workspace. Defaults to the config's workspaceRoot.

.PARAMETER SkillsPath
    Skills folder relative to the root. Defaults to the config's skillsPath, or
    .claude/skills.

.PARAMETER FailOnMissing
    Exit 1 when any target is missing.

.PARAMETER ConfigPath
    Path to release-manager.config.json.

.EXAMPLE
    .\Test-SkillReferences.ps1
#>
[CmdletBinding()]
param(
    [string] $WorkspaceRoot,
    [string] $SkillsPath,
    [switch] $FailOnMissing,
    [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

. (Join-Path $PSScriptRoot 'ReleaseConfig.ps1')

$cfg = $null
try { $cfg = Get-ReleaseConfig -ConfigPath $ConfigPath }
catch { if ($ConfigPath -or -not $WorkspaceRoot) { throw } }

if (-not $PSBoundParameters.ContainsKey('WorkspaceRoot')) { $WorkspaceRoot = $cfg.ResolvedRoot }
if (-not $PSBoundParameters.ContainsKey('SkillsPath')) {
    $SkillsPath = if ($cfg -and $cfg.skillsPath) { [string] $cfg.skillsPath } else { '.claude/skills' }
}

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) { throw "WorkspaceRoot not found: $WorkspaceRoot" }
$root = (Get-Item -LiteralPath $WorkspaceRoot -Force).FullName.TrimEnd('\')
$skillsDir = Join-Path $root ($SkillsPath.Replace('/', '\'))
if (-not (Test-Path -LiteralPath $skillsDir)) {
    Write-Host "SKILL REFERENCES SKIPPED: no skills folder at $SkillsPath"
    exit 0
}

# references/ followed by a relative path ending in a file extension. Trailing prose
# punctuation (a closing backtick, period, or parenthesis) is not captured.
$pattern = 'references/[A-Za-z0-9_\-./]*[A-Za-z0-9_\-]\.[A-Za-z0-9]+'

$skillFiles = @(Get-ChildItem -LiteralPath $skillsDir -Recurse -File -Force -Filter 'SKILL.md')
$checked = 0
$missing = New-Object System.Collections.Generic.List[string]

foreach ($sf in $skillFiles) {
    $text = [System.IO.File]::ReadAllText($sf.FullName, [System.Text.Encoding]::UTF8)
    $refs = @([regex]::Matches($text, $pattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    foreach ($ref in $refs) {
        $checked++
        $target = Join-Path $sf.DirectoryName ($ref.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $skillRel = $sf.FullName.Substring($root.Length).TrimStart('\').Replace('\', '/')
            $missing.Add(("{0}  ->  {1}" -f $skillRel, $ref))
        }
    }
}

Write-Host ""
Write-Host ("Skill references: {0} SKILL.md file(s), {1} distinct reference(s) checked" -f $skillFiles.Count, $checked)
if ($missing.Count -eq 0) {
    Write-Host "SKILL REFERENCES PASSED: every references/ path named in a SKILL.md resolves."
    exit 0
}

Write-Host ("Missing ({0}):" -f $missing.Count)
foreach ($m in $missing) { Write-Host ("  " + $m) }
if ($FailOnMissing) {
    Write-Host ("SKILL REFERENCES FAILED: {0} missing target(s)." -f $missing.Count)
    exit 1
}
Write-Host ("SKILL REFERENCES WARN: {0} missing target(s). Report-only; queue the fix, do not halt the cut." -f $missing.Count)
exit 0
