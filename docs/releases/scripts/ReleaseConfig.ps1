<#
.SYNOPSIS
    Reads release-manager.config.json. Dot-source it, or run it with -AsCmd.

.DESCRIPTION
    Every script in this kit reads its workspace-specific values from one file,
    release-manager.config.json at the workspace root. This file holds the loader.

    Dot-source it to get Get-ReleaseConfig:

        . "$PSScriptRoot\ReleaseConfig.ps1"
        $cfg = Get-ReleaseConfig

    Run it with -AsCmd to print KEY=VALUE lines for the nightly .cmd launcher.

    A relative workspaceRoot in the config resolves against the folder that holds the
    config file, so the default "." means "the folder this config sits in".

.PARAMETER ConfigPath
    Path to the config. Defaults to release-manager.config.json three levels above this
    script (docs/releases/scripts -> workspace root).

.PARAMETER AsCmd
    Print RM_WS, RM_CLAUDE, RM_CLAUDE_ARGS, RM_PROMPT, RM_LOG and RM_STAMP as KEY=VALUE.
#>
[CmdletBinding()]
param(
    [string] $ConfigPath,
    [switch] $AsCmd
)

$script:ReleaseConfigScriptDir = $PSScriptRoot

function Get-ReleaseConfig {
    param([string] $ConfigPath)

    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $script:ReleaseConfigScriptDir '..\..\..\release-manager.config.json'
    }
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config not found: $ConfigPath"
    }
    $cfgFile = (Get-Item -LiteralPath $ConfigPath -Force).FullName
    $cfg = [System.IO.File]::ReadAllText($cfgFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

    $base = Split-Path -Parent $cfgFile
    $ws = [string] $cfg.workspaceRoot
    if (-not $ws) { $ws = '.' }
    if (-not [System.IO.Path]::IsPathRooted($ws)) { $ws = Join-Path $base $ws }
    if (-not (Test-Path -LiteralPath $ws)) { throw "workspaceRoot not found: $ws" }

    # Get-Item, not Resolve-Path: it expands 8.3 short names to the long form that
    # Get-ChildItem reports, so relative paths computed later line up.
    $root = (Get-Item -LiteralPath $ws -Force).FullName.TrimEnd('\')
    $cfg | Add-Member -NotePropertyName ResolvedRoot -NotePropertyValue $root -Force
    $cfg | Add-Member -NotePropertyName ConfigFile -NotePropertyValue $cfgFile -Force
    return $cfg
}

function Resolve-WorkspacePath {
    param([string] $Root, [string] $Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Root ($Path.Replace('/', '\')))
}

if ($AsCmd) {
    $ErrorActionPreference = 'Stop'
    $cfg = Get-ReleaseConfig -ConfigPath $ConfigPath
    $s = $cfg.schedule
    $stamp = [string] $s.stampFile
    if (-not $stamp) {
        # Per machine, outside the synced folder: the stamp says "this machine already ran
        # today", which is not something teammates should share.
        $stamp = Join-Path $env:LOCALAPPDATA ("claude-release-manager\" + $s.taskName + ".ok")
    }
    else {
        $stamp = Resolve-WorkspacePath -Root $cfg.ResolvedRoot -Path $stamp
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stamp) | Out-Null
    $log = Resolve-WorkspacePath -Root $cfg.ResolvedRoot -Path ([string] $s.logFile)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null

    "RM_WS=$($cfg.ResolvedRoot)"
    "RM_CLAUDE=$($s.claudeExe)"
    "RM_CLAUDE_ARGS=$($s.claudeArgs)"
    "RM_PROMPT=$($s.prompt)"
    "RM_LOG=$log"
    "RM_STAMP=$stamp"
}
