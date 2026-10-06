<#
.SYNOPSIS
    Takes the rollback snapshot for a release, before anything is installed.

.DESCRIPTION
    For each core path the release will touch, this copies the current bytes into
    <releasesDir>/<version>/snapshot/ in the same relative layout, and writes
    snapshot-hashes.csv recording the pre-release state of every target (its prior sha256
    for an overwrite, or did-not-exist for an addition).

    Run this BEFORE the install. A snapshot taken afterward records the new bytes and
    proves nothing.

    For an addition there is nothing to copy, so the row is written with
    pre_release_state = did-not-exist and the rollback is a removal. After the install,
    re-run with -PostInstall to capture spare copies of the NEWLY ADDED files.

    -PostInstall never touches the pre-install copy of a file that existed before the
    release: that copy is the rollback, and replacing it with the installed bytes would make
    the rollback restore nothing. A plain re-run without -PostInstall also refuses to
    overwrite a snapshot copy that holds different bytes.

    The snapshot layout drops a leading ".claude\", so snapshot/skills/x/SKILL.md maps to
    .claude/skills/x/SKILL.md. The manifest records both paths.

.PARAMETER WorkspaceRoot
    Top of the shared workspace. Defaults to the config's workspaceRoot.

.PARAMETER Version
    Release version, for example 2026.01.15.

.PARAMETER TargetPath
    Core-relative paths the release touches. A directory expands to its files.
    Example: '.claude/skills/my-skill','CLAUDE.md'

.PARAMETER PostInstall
    Run after the install to add spare copies of files that did NOT exist before the
    release. Rows for files that existed before are left exactly as the pre-install run
    wrote them. A file with no pre-install row is skipped with a warning.

.PARAMETER ReleasesDir
    Where release folders live, relative to the workspace root. Defaults to the config's
    releasesDir, or docs/releases.

.PARAMETER ConfigPath
    Path to release-manager.config.json.

.EXAMPLE
    .\New-ReleaseSnapshot.ps1 -Version 2026.01.15 -TargetPath '.claude/skills/my-skill','CLAUDE.md'
#>
[CmdletBinding()]
param(
    [string]   $WorkspaceRoot,
    [Parameter(Mandatory = $true)] [string]   $Version,
    [Parameter(Mandatory = $true)] [string[]] $TargetPath,
    [switch]   $PostInstall,
    [string]   $ReleasesDir,
    [string]   $ConfigPath
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

. (Join-Path $PSScriptRoot 'ReleaseConfig.ps1')

$cfg = $null
try { $cfg = Get-ReleaseConfig -ConfigPath $ConfigPath }
catch { if ($ConfigPath -or -not $WorkspaceRoot) { throw } }

if (-not $PSBoundParameters.ContainsKey('WorkspaceRoot')) { $WorkspaceRoot = $cfg.ResolvedRoot }
if (-not $PSBoundParameters.ContainsKey('ReleasesDir')) {
    $ReleasesDir = if ($cfg -and $cfg.releasesDir) { [string] $cfg.releasesDir } else { 'docs/releases' }
}

$root = (Get-Item -LiteralPath $WorkspaceRoot -Force).FullName.TrimEnd('\')

function Get-RelativeTo {
    param([string] $Root, [string] $Path)
    $full = (Get-Item -LiteralPath $Path -Force).FullName
    if (-not $full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the root and cannot be made relative: $Path"
    }
    return $full.Substring($Root.Length).TrimStart('\')
}

$releaseDir  = Join-Path (Join-Path $root ($ReleasesDir.Replace('/', '\'))) $Version
$snapshotDir = Join-Path $releaseDir 'snapshot'
$csvPath     = Join-Path $releaseDir 'snapshot-hashes.csv'

New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null

# Existing rows, so a -PostInstall run does not lose the pre-install state.
$existing = @{}
if (Test-Path -LiteralPath $csvPath) {
    Import-Csv -LiteralPath $csvPath | ForEach-Object { $existing[$_.installed_path] = $_ }
}

$rows = New-Object System.Collections.Generic.List[object]
$postAdded = 0; $postKept = 0; $postSkipped = 0

foreach ($rel in $TargetPath) {
    $relClean = $rel.Replace('/', '\').TrimStart('\')
    $full = Join-Path $root $relClean

    $files = @()
    if (Test-Path -LiteralPath $full) {
        $item = Get-Item -LiteralPath $full -Force
        if ($item.PSIsContainer) { $files = @(Get-ChildItem -LiteralPath $full -Recurse -File -Force) }
        else { $files = @($item) }
    }

    if ($files.Count -eq 0) {
        # Nothing in core yet: an addition. Record the intent so rollback is unambiguous.
        $key = $relClean.Replace('\', '/')
        if ($PostInstall -and $existing.ContainsKey($key)) { continue }
        $rows.Add([pscustomobject]@{
            snapshot_path     = ''
            installed_path    = $key
            bytes             = ''
            sha256            = ''
            pre_release_state = 'did-not-exist'
        })
        Write-Host ("ADDITION (nothing to snapshot): {0}" -f $relClean)
        continue
    }

    foreach ($f in $files) {
        $installedRel = Get-RelativeTo -Root $root -Path $f.FullName
        $snapRel      = $installedRel -replace '^\.claude\\', ''
        $dest         = Join-Path $snapshotDir $snapRel
        $installedKey = $installedRel.Replace('\', '/')

        $priorState = 'existed-at-this-hash'
        if ($PostInstall) {
            # Only files the release ADDED may be copied after the install. A file whose
            # pre-install row is not did-not-exist is an overwrite: its snapshot copy is the
            # rollback and must never be replaced by the installed bytes.
            $isNew = $false
            if ($existing.ContainsKey($installedKey)) {
                if ($existing[$installedKey].pre_release_state -eq 'did-not-exist') { $isNew = $true }
                else {
                    Write-Host ("KEPT (pre-install copy is the rollback, not touched): {0}" -f $installedKey)
                    $postKept++
                    continue
                }
            }
            else {
                foreach ($ek in $existing.Keys) {
                    if ($existing[$ek].pre_release_state -eq 'did-not-exist' -and
                        $installedKey.StartsWith($ek.TrimEnd('/') + '/', [System.StringComparison]::OrdinalIgnoreCase)) { $isNew = $true; break }
                }
                if (-not $isNew) {
                    Write-Warning ("SKIPPED (no pre-install row, so no prior state can be claimed): {0}" -f $installedKey)
                    $postSkipped++
                    continue
                }
            }
            $priorState = 'did-not-exist'
            $postAdded++
        }
        elseif (Test-Path -LiteralPath $dest) {
            $haveHash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
            $nowHash  = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
            if ($haveHash -ne $nowHash) {
                throw "Refusing to overwrite snapshot copy with different bytes: $installedKey. The existing copy may be the rollback. Investigate before re-running."
            }
        }

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null

        # Copy-Item only: byte-exact, no line-ending normalization.
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force

        $srcHash  = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        $destHash = (Get-FileHash -LiteralPath $dest       -Algorithm SHA256).Hash
        if ($srcHash -ne $destHash) { throw "Snapshot copy is not byte-exact: $installedRel" }

        $rows.Add([pscustomobject]@{
            snapshot_path     = $snapRel.Replace('\', '/')
            installed_path    = $installedKey
            bytes             = $f.Length
            sha256            = $srcHash
            pre_release_state = $priorState
        })
    }
}

# Preserve any rows from a prior run that this run did not revisit.
foreach ($key in $existing.Keys) {
    if (-not ($rows | Where-Object { $_.installed_path -eq $key })) { $rows.Add($existing[$key]) }
}

$rows | Sort-Object installed_path | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host ("Snapshot:  {0}" -f $snapshotDir)
Write-Host ("Manifest:  {0}" -f $csvPath)
Write-Host ("Rows:      {0}" -f $rows.Count)
if ($PostInstall) {
    Write-Host ("PostInstall: {0} new file(s) copied, {1} pre-install copy(ies) kept untouched, {2} skipped" -f $postAdded, $postKept, $postSkipped)
}
Write-Host ""
Write-Host "Next: copy templates/snapshot-README-TEMPLATE.md into the snapshot directory as"
Write-Host "README.md and fill in the restore command. Then install with Copy-Item."
