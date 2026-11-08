<#
.SYNOPSIS
    Installs the MIRAJ skills (miraj-dba, miraj-dev, miraj-mcp) for Claude Code.

.PARAMETER Scope
    User (default): ~\.claude\skills, available in all projects.
    Project: .claude\skills in the current folder, shared with the team through the repository.

.PARAMETER Skills
    List of skills to install (default: all three).

.PARAMETER Uninstall
    Removes the skills instead of installing them.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Scope Project
    .\install.ps1 -Skills miraj-dev
    .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [ValidateSet('User', 'Project')]
    [string]$Scope = 'User',
    [string[]]$Skills = @('miraj-dba', 'miraj-dev', 'miraj-mcp'),
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Scope -eq 'User') {
    $target = Join-Path $env:USERPROFILE '.claude\skills'
} else {
    $target = Join-Path (Get-Location) '.claude\skills'
}

foreach ($name in $Skills) {
    $folder = Join-Path $source $name
    $dest = Join-Path $target $name

    if ($Uninstall) {
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
            Write-Host "Removed: $dest"
        } else {
            Write-Host "Not found: $dest"
        }
        continue
    }

    if (-not (Test-Path (Join-Path $folder 'SKILL.md'))) {
        throw "Skill not found: $folder (SKILL.md missing)"
    }
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse -Force $folder $dest
    Write-Host "Installed: $name -> $dest"
}

if (-not $Uninstall) {
    Write-Host ''
    Write-Host 'Done. Restart Claude Code (or open a new session), then type /skills to check.'
}
