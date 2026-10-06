<#
.SYNOPSIS
    Registers the two Windows scheduled tasks that run the nightly release.

.DESCRIPTION
    Reads the schedule block of release-manager.config.json and registers:

      <taskName>        daily at cutTime,   runs nightly-release.cmd scheduled
      <taskName>-Retry  daily at retryTime, runs nightly-release.cmd retry

    The retry exits at once if this machine already logged a successful run today, so it
    only does work when the main run failed or never fired.

    Times in the config are read in the config's timezone (a Windows time zone id such as
    "Eastern Standard Time", or "Local") and converted to this machine's local clock,
    because Task Scheduler triggers use local time.

    Tasks run as the current user, only while that user is logged on, because Claude Code
    keeps its sign-in in the user profile. StartWhenAvailable is set, so a trigger missed
    while the machine was off or asleep fires once the machine is back. A trigger missed
    because the user was signed out is NOT recovered until the next sign-in.

    Register on ONE machine per workspace. Two machines cutting the same synced folder at
    the same time is exactly the conflict this kit exists to prevent.

    Supports -WhatIf: prints what it would register without touching Task Scheduler.

.PARAMETER ConfigPath
    Path to release-manager.config.json. Defaults to the one beside this scripts folder.

.EXAMPLE
    .\Register-NightlyRelease.ps1 -WhatIf

.EXAMPLE
    .\Register-NightlyRelease.ps1
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
$cfg = Get-ReleaseConfig -ConfigPath $ConfigPath
$s = $cfg.schedule

$launcher = (Get-Item -LiteralPath (Join-Path $PSScriptRoot 'nightly-release.cmd')).FullName

function ConvertTo-LocalClock {
    param([string] $HHmm, [string] $ZoneId)
    $parts = $HHmm.Split(':')
    $today = [DateTime]::Today
    $wall  = [DateTime]::new($today.Year, $today.Month, $today.Day, [int] $parts[0], [int] $parts[1], 0, [DateTimeKind]::Unspecified)
    if (-not $ZoneId -or $ZoneId -eq 'Local') { return $wall }
    # ponytail: offset computed for today's date. Across a DST change in only one of the
    # two zones the task drifts by an hour; re-run this script after the change.
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById($ZoneId)
    return [TimeZoneInfo]::ConvertTime($wall, $zone, [TimeZoneInfo]::Local)
}

$mainAt  = ConvertTo-LocalClock -HHmm $s.cutTime   -ZoneId $s.timezone
$retryAt = ConvertTo-LocalClock -HHmm $s.retryTime -ZoneId $s.timezone

$user = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { $env:USERNAME }
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -WakeToRun:([bool] $s.wakeToRun) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew

$tasks = @(
    @{ Name = [string] $s.taskName;              At = $mainAt;  Mode = 'scheduled' },
    @{ Name = ([string] $s.taskName + '-Retry'); At = $retryAt; Mode = 'retry' }
)

Write-Host ("Workspace: {0}" -f $cfg.ResolvedRoot)
Write-Host ("Launcher:  {0}" -f $launcher)
Write-Host ("Run as:    {0} (only while logged on)" -f $user)

foreach ($t in $tasks) {
    $action  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c ""{0}" {1}"' -f $launcher, $t.Mode)
    $trigger = New-ScheduledTaskTrigger -Daily -At $t.At
    $label   = "{0}{1} daily at {2:HH:mm} local" -f $s.taskFolder, $t.Name, $t.At
    if ($PSCmdlet.ShouldProcess($label, 'Register scheduled task')) {
        Register-ScheduledTask -TaskPath $s.taskFolder -TaskName $t.Name -Action $action `
            -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Write-Host "Registered: $label"
    }
}

Write-Host ""
Write-Host "Log: $($s.logFile) (relative to the workspace root)."
Write-Host "Test now without waiting: Start-ScheduledTask -TaskPath '$($s.taskFolder)' -TaskName '$($s.taskName)'"
