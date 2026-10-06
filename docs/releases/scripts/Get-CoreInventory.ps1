<#
.SYNOPSIS
    Takes a full sha256 inventory of the workspace core.

.DESCRIPTION
    This replaces "git status" in a shared folder that is not a git repository. Run it
    before an install and again after, then diff the two with Compare-CoreInventory.ps1.
    That diff is what proves nothing outside the release changed.

    Scope comes from release-manager.config.json (corePaths, charterFile, excludePaths)
    unless you pass the matching parameter, which wins.

    Build artifacts (__pycache__, editor temp files) are supposed to show up inside
    governed core: if one appears in the diff, the release created it and that is worth
    knowing.

    The only thing excluded is the set of paths the team is allowed to write outside a
    release (excludePaths). Those writes are not core drift, and counting them makes every
    drift gate fail on work that was allowed. Exclusions are always reported with a
    per-path file count, and a listed path that matches nothing is flagged, because a stale
    or mistyped exclusion is a silent hole in the gate.

.PARAMETER WorkspaceRoot
    Top of the shared workspace. Defaults to the config's workspaceRoot.

.PARAMETER OutFile
    Where to write the CSV. Defaults to a timestamped file in the current directory.

.PARAMETER CorePath
    Core files or directories, relative to the workspace root. Defaults to the config's
    corePaths, or .claude if there is no config.

.PARAMETER CharterFile
    Single core file at the workspace root to include, usually CLAUDE.md.

.PARAMETER ExcludePath
    Relative path prefixes to leave out: places the team writes without a release by
    design. An inventory is only comparable against another taken with the same
    -CorePath and -ExcludePath, so record both wherever the count is recorded.

.PARAMETER ConfigPath
    Path to release-manager.config.json. Defaults to the workspace root above this script.

.EXAMPLE
    .\Get-CoreInventory.ps1 -OutFile ..\2026.01.15\pre.csv

.EXAMPLE
    .\Get-CoreInventory.ps1 -WorkspaceRoot "D:\shared\workspace" -CorePath '.claude' -OutFile .\pre.csv
#>
[CmdletBinding()]
param(
    [string]   $WorkspaceRoot,
    [string]   $OutFile,
    [string[]] $CorePath,
    [string]   $CharterFile,
    [string[]] $ExcludePath,
    [string]   $ConfigPath
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

. (Join-Path $PSScriptRoot 'ReleaseConfig.ps1')

# Precedence: explicit parameter, then config, then built-in default.
$cfg = $null
try { $cfg = Get-ReleaseConfig -ConfigPath $ConfigPath }
catch { if ($ConfigPath -or -not $WorkspaceRoot) { throw } }

if (-not $PSBoundParameters.ContainsKey('WorkspaceRoot')) { $WorkspaceRoot = $cfg.ResolvedRoot }
if (-not $PSBoundParameters.ContainsKey('CorePath')) {
    $CorePath = if ($cfg -and $cfg.corePaths) { @($cfg.corePaths) } else { @('.claude') }
}
if (-not $PSBoundParameters.ContainsKey('CharterFile')) {
    $CharterFile = if ($cfg -and $cfg.charterFile) { [string] $cfg.charterFile } else { 'CLAUDE.md' }
}
if (-not $PSBoundParameters.ContainsKey('ExcludePath')) {
    $ExcludePath = if ($cfg -and $cfg.excludePaths) { @($cfg.excludePaths) } else { @() }
}

if (-not (Test-Path -LiteralPath $WorkspaceRoot)) {
    throw "WorkspaceRoot not found: $WorkspaceRoot"
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

if (-not $OutFile) {
    $OutFile = Join-Path (Get-Location).ProviderPath ("core-inventory-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".csv")
}

# A HashSet keeps a file listed once even when corePaths overlap the charter file.
$targets = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

foreach ($rel in $CorePath) {
    $p = Join-Path $root ($rel.Replace('/', '\'))
    if (Test-Path -LiteralPath $p) {
        Get-ChildItem -LiteralPath $p -Recurse -File -Force |
            ForEach-Object { [void] $targets.Add($_.FullName) }
    }
    else {
        Write-Warning "Core path not found, skipped: $rel"
    }
}

if ($CharterFile) {
    $charter = Join-Path $root $CharterFile
    if (Test-Path -LiteralPath $charter) { [void] $targets.Add((Get-Item -LiteralPath $charter -Force).FullName) }
    else { Write-Warning "Charter file not found, skipped: $CharterFile" }
}

# Filter before hashing, so an excluded subtree costs nothing. Counts are per prefix, so
# the report can tell a prefix that excluded 500 files from one that excluded none.
$exCounts = [ordered]@{}
$kept = New-Object System.Collections.Generic.List[string]
$normEx = @($ExcludePath | ForEach-Object { $_.Replace('\', '/').Trim('/') } | Where-Object { $_ })
foreach ($ex in $normEx) { $exCounts[$ex] = 0 }
foreach ($path in $targets) {
    $rel = (Get-RelativeTo -Root $root -Path $path).Replace('\', '/')
    $hit = $null
    foreach ($ex in $normEx) {
        if ($rel -eq $ex -or $rel.StartsWith($ex + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            $hit = $ex; break
        }
    }
    if ($hit) { $exCounts[$hit] = $exCounts[$hit] + 1 } else { $kept.Add($path) }
}

$rows = foreach ($path in $kept) {
    $item = Get-Item -LiteralPath $path -Force
    [pscustomobject]@{
        RelativePath = (Get-RelativeTo -Root $root -Path $path).Replace('\', '/')
        Bytes        = $item.Length
        Sha256       = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        LastWrite    = $item.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}

$sorted = @($rows | Sort-Object RelativePath)
$sorted | Export-Csv -LiteralPath $OutFile -NoTypeInformation -Encoding UTF8

$count = $sorted.Count
$bytes = ($sorted | Measure-Object -Property Bytes -Sum).Sum

Write-Host ""
Write-Host "Core inventory written: $OutFile"
Write-Host ("Scope: -CorePath {0}  -CharterFile {1}" -f ($CorePath -join ','), $CharterFile)
Write-Host ("Files: {0}   Total bytes: {1:N0}" -f $count, $bytes)

if ($exCounts.Count -gt 0) {
    $exTotal = 0
    foreach ($k in $exCounts.Keys) { $exTotal += $exCounts[$k] }
    Write-Host ("Excluded by -ExcludePath: {0} file(s) not counted as core" -f $exTotal)
    foreach ($k in $exCounts.Keys) {
        if ($exCounts[$k] -eq 0) {
            Write-Host ("  {0}  ->  0 files   MATCHED NOTHING: stale or mistyped exclusion" -f $k)
        }
        else {
            Write-Host ("  {0}  ->  {1} file(s)" -f $k, $exCounts[$k])
        }
    }
}
else {
    Write-Host "Excluded by -ExcludePath: nothing, every file under -CorePath was counted"
}

$charterRow = $sorted | Where-Object { $_.RelativePath -eq $CharterFile }
if ($charterRow) {
    Write-Host ("{0}: {1} bytes  {2}" -f $CharterFile, $charterRow.Bytes, $charterRow.Sha256)
}

Write-Host ""
Write-Host "Record the file count, total bytes and charter hash in the CHANGELOG entry. They"
Write-Host "are how the next release proves core did not drift in between. A count only means"
Write-Host "something next to another count taken over the same scope."
