<#
.SYNOPSIS
    Removes the two nightly release scheduled tasks created by Register-NightlyRelease.ps1.

.DESCRIPTION
    Reads taskFolder and taskName from release-manager.config.json and unregisters
    <taskName> and <taskName>-Retry. Leaves the log and the success stamp in place.
    Supports -WhatIf.

.PARAMETER ConfigPath
    Path to release-manager.config.json. Defaults to the one beside this scripts folder.

.EXAMPLE
    .\Unregister-NightlyRelease.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
# Resolved here, not as a param default: Windows PowerShell 5.1 leaves $PSScriptRoot
# empty in param defaults when the script runs under -File.
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..\release-manager.config.json' }

. (Join-Path $PSScriptRoot '..\docs\releases\scripts\ReleaseConfig.ps1')
$s = (Get-ReleaseConfig -ConfigPath $ConfigPath).schedule

foreach ($name in @([string] $s.taskName, ([string] $s.taskName + '-Retry'))) {
    $task = Get-ScheduledTask -TaskPath $s.taskFolder -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { Write-Host "Not registered: $($s.taskFolder)$name"; continue }
    if ($PSCmdlet.ShouldProcess("$($s.taskFolder)$name", 'Unregister scheduled task')) {
        Unregister-ScheduledTask -TaskPath $s.taskFolder -TaskName $name -Confirm:$false
        Write-Host "Removed: $($s.taskFolder)$name"
    }
}
