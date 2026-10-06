<#
.SYNOPSIS
    Diffs two core inventories and reports added, removed, and modified files.

.DESCRIPTION
    The proof step of a release. Run Get-CoreInventory.ps1 before the install and again
    after, then run this. For a purely additive release the expected result is: added
    equals the file count of the item, removed 0, modified 0.

    Anything unexpected in the Modified list means the install rewrote a file it should
    have copied, or somebody had core open. Stop and investigate before writing the
    CHANGELOG entry.

    Also used as the drift gate: compare the baseline inventory against a fresh one before
    installing. Expect 0 / 0 / 0.

.PARAMETER Before
    CSV from Get-CoreInventory.ps1 taken before the install.

.PARAMETER After
    CSV taken after the install.

.PARAMETER OutFile
    Optional markdown file for the APPLY record.

.PARAMETER ExpectedAdded
    Optional. Number of files this release should add. Sets a non-zero exit code on
    mismatch, so an unattended cut fails loudly.

.PARAMETER ExpectedRemoved
    Optional. Defaults to 0 when ExpectedAdded is supplied.

.PARAMETER ExpectedModified
    Optional. Defaults to 0 when ExpectedAdded is supplied.

.EXAMPLE
    .\Compare-CoreInventory.ps1 -Before .\pre.csv -After .\post.csv -ExpectedAdded 9
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Before,
    [Parameter(Mandatory = $true)] [string] $After,
    [string] $OutFile,
    [int] $ExpectedAdded = -1,
    [int] $ExpectedRemoved = 0,
    [int] $ExpectedModified = 0
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$pre  = @{}
$post = @{}
Import-Csv -LiteralPath $Before | ForEach-Object { $pre[$_.RelativePath]  = $_ }
Import-Csv -LiteralPath $After  | ForEach-Object { $post[$_.RelativePath] = $_ }

$added    = @($post.Keys | Where-Object { -not $pre.ContainsKey($_) }    | Sort-Object)
$removed  = @($pre.Keys  | Where-Object { -not $post.ContainsKey($_) }   | Sort-Object)
$modified = @($pre.Keys  | Where-Object { $post.ContainsKey($_) -and $pre[$_].Sha256 -ne $post[$_].Sha256 } | Sort-Object)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("| Measure | Value |")
$lines.Add("|---|---|")
$lines.Add("| Files before | $($pre.Count) |")
$lines.Add("| Files after | $($post.Count) |")
$lines.Add("| Added | $($added.Count) |")
$lines.Add("| Removed | $($removed.Count) |")
$lines.Add("| Modified | $($modified.Count) |")

if ($added.Count) {
    $lines.Add("")
    $lines.Add("**Added**")
    $lines.Add("")
    foreach ($p in $added) { $lines.Add("- ``$p`` ($($post[$p].Bytes) bytes, $($post[$p].Sha256))") }
}
if ($removed.Count) {
    $lines.Add("")
    $lines.Add("**Removed**")
    $lines.Add("")
    foreach ($p in $removed) { $lines.Add("- ``$p`` (was $($pre[$p].Bytes) bytes, $($pre[$p].Sha256))") }
}
if ($modified.Count) {
    $lines.Add("")
    $lines.Add("**Modified**")
    $lines.Add("")
    foreach ($p in $modified) {
        $lines.Add("- ``$p``: $($pre[$p].Bytes) bytes $($pre[$p].Sha256) -> $($post[$p].Bytes) bytes $($post[$p].Sha256)")
    }
}

$report = $lines -join [Environment]::NewLine
Write-Host ""
Write-Host $report
Write-Host ""

if ($OutFile) {
    $report | Out-File -LiteralPath $OutFile -Encoding utf8
    Write-Host "Markdown written: $OutFile"
}

if ($ExpectedAdded -ge 0) {
    $fail = @()
    if ($added.Count    -ne $ExpectedAdded)    { $fail += "added $($added.Count), expected $ExpectedAdded" }
    if ($removed.Count  -ne $ExpectedRemoved)  { $fail += "removed $($removed.Count), expected $ExpectedRemoved" }
    if ($modified.Count -ne $ExpectedModified) { $fail += "modified $($modified.Count), expected $ExpectedModified" }

    if ($fail.Count) {
        Write-Host ""
        Write-Warning ("INVENTORY DIFF FAILED: " + ($fail -join '; '))
        Write-Warning "Do not write the CHANGELOG entry. Investigate, or roll back."
        exit 1
    }
    Write-Host "INVENTORY DIFF PASSED: shape matches the release exactly."
}
