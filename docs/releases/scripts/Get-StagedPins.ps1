<#
.SYNOPSIS
    Pins a staged tree at build time, and re-checks those pins at install time.

.DESCRIPTION
    A staged change is only "built" once every file in it has a byte count and a sha256
    recorded in its queue item. Those pins are the contract between build and install: if
    one does not match at cut time, something drifted and the release stops.

    Run it once at build time with -OutFile to write the pins, and again at install time
    with -VerifyAgainst to check them. It also reports CRLF files, because the pins were
    taken over those bytes and an install that normalizes line endings silently
    invalidates them.

    Fails if the staged tree contains build artifacts (__pycache__ and friends), which do
    not belong in core.

.PARAMETER StagedRoot
    The staged tree, e.g. docs/requests/<slug>/staged

.PARAMETER OutFile
    Optional CSV of the pins.

.PARAMETER VerifyAgainst
    A pins CSV from a previous run. Non-zero exit code on any mismatch.

.PARAMETER Markdown
    Emit a markdown table ready to paste into the queue item.

.EXAMPLE
    .\Get-StagedPins.ps1 -StagedRoot ".\docs\requests\my-skill\staged" -OutFile .\pins.csv -Markdown

.EXAMPLE
    .\Get-StagedPins.ps1 -StagedRoot ".\docs\requests\my-skill\staged" -VerifyAgainst .\pins.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $StagedRoot,
    [string] $OutFile,
    [string] $VerifyAgainst,
    [switch] $Markdown
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

# Get-Item, not Resolve-Path: Get-Item expands 8.3 short names to the long form that
# Get-ChildItem also reports, so prefix stripping lines up instead of losing a character.
$root = (Get-Item -LiteralPath $StagedRoot -Force).FullName.TrimEnd('\')

function Get-RelativeTo {
    param([string] $Root, [string] $Path)
    $full = (Get-Item -LiteralPath $Path -Force).FullName
    if (-not $full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the root and cannot be made relative: $Path"
    }
    return $full.Substring($Root.Length).TrimStart('\')
}
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName)

if ($files.Count -eq 0) { throw "Staged tree is empty: $root" }

$artifacts = @($files | Where-Object {
    $_.FullName -match '\\__pycache__\\' -or $_.Extension -in @('.pyc', '.tmp', '.bak') -or $_.Name -like '~$*'
})
if ($artifacts.Count) {
    Write-Warning "Build artifacts in the staged tree. Remove these before pinning:"
    $artifacts | ForEach-Object { Write-Warning ("  " + (Get-RelativeTo -Root $root -Path $_.FullName)) }
    exit 1
}

$rows = foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $crCount = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -eq 13) { $crCount++ } }

    $nonAscii = 0
    for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -gt 127) { $nonAscii++ } }

    [pscustomobject]@{
        staged_path = (Get-RelativeTo -Root $root -Path $f.FullName).Replace('\', '/')
        bytes       = $f.Length
        sha256      = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        cr_count    = $crCount
        non_ascii   = $nonAscii
    }
}

$crlf = @($rows | Where-Object { $_.cr_count -gt 0 })

Write-Host ""
Write-Host ("Staged tree: {0}" -f $root)
Write-Host ("Files: {0}   CRLF files: {1}" -f $rows.Count, $crlf.Count)
if ($crlf.Count) {
    Write-Host "CRLF files (install with Copy-Item only, never a rewriting tool):"
    $crlf | ForEach-Object { Write-Host ("  {0} ({1} CR)" -f $_.staged_path, $_.cr_count) }
}

if ($Markdown) {
    Write-Host ""
    Write-Host "| Staged path | Bytes | sha256 |"
    Write-Host "|---|---|---|"
    foreach ($r in $rows) {
        $note = if ($r.cr_count -gt 0) { " (CRLF)" } else { "" }
        Write-Host ("| ``{0}``{1} | {2} | ``{3}`` |" -f $r.staged_path, $note, $r.bytes, $r.sha256)
    }
}

if ($OutFile) {
    $rows | Export-Csv -LiteralPath $OutFile -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "Pins written: $OutFile"
}

if ($VerifyAgainst) {
    $pinned = @{}
    Import-Csv -LiteralPath $VerifyAgainst | ForEach-Object { $pinned[$_.staged_path] = $_ }
    $now = @{}
    $rows | ForEach-Object { $now[$_.staged_path] = $_ }

    $fail = @()
    foreach ($k in $pinned.Keys) {
        if (-not $now.ContainsKey($k)) { $fail += "MISSING: $k"; continue }
        if ($now[$k].sha256 -ne $pinned[$k].sha256) {
            $fail += ("DRIFTED: {0} pinned {1} now {2}" -f $k, $pinned[$k].sha256, $now[$k].sha256)
        }
    }
    foreach ($k in $now.Keys) {
        if (-not $pinned.ContainsKey($k)) { $fail += "UNPINNED EXTRA FILE: $k" }
    }

    Write-Host ""
    if ($fail.Count) {
        $fail | ForEach-Object { Write-Warning $_ }
        Write-Warning "PIN CHECK FAILED. Do not install. Something changed between build and cut."
        exit 1
    }
    Write-Host ("PIN CHECK PASSED: all {0} staged files match their pins byte for byte." -f $pinned.Count)
}
