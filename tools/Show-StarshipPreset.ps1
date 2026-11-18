#Requires -Version 7.4
<#
.SYNOPSIS
    Prints how each of starship's preset prompts looks here, in this terminal and font.
.DESCRIPTION
    Renders the prompt for Path (default: the current folder), so run it inside a git repository with
    a project in it to see the git and language segments. Nothing is changed; the presets are written
    to a temporary folder and removed afterwards.
.EXAMPLE
    ./tools/Show-StarshipPreset.ps1 -Path V:\Repos\crateside
#>
[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,

    [string[]]$Name = @(
        'catppuccin-powerline', 'gruvbox-rainbow', 'pastel-powerline', 'tokyo-night', 'jetpack',
        'bracketed-segments', 'pure-preset'
    )
)

$ErrorActionPreference = 'Stop'
$workDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "starship-presets-$PID"
$null = New-Item -ItemType Directory -Path $workDirectory
$current = $env:STARSHIP_CONFIG
$resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
$width = $Host.UI.RawUI.WindowSize.Width

try {
    foreach ($preset in @('(current)') + $Name) {
        $env:STARSHIP_CONFIG = $current
        if ($preset -ne '(current)') {
            $env:STARSHIP_CONFIG = Join-Path -Path $workDirectory -ChildPath "$preset.toml"
            starship preset $preset --output $env:STARSHIP_CONFIG
        }

        $prompt = starship prompt --path $resolved --logical-path $resolved --terminal-width $width `
            --status 1 --cmd-duration 3200
        Write-Host -Object "`n$preset" -ForegroundColor DarkGray
        Write-Host -Object (($prompt -join "`n") + 'Get-ChildItem')
    }
} finally {
    $env:STARSHIP_CONFIG = $current
    Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction Ignore
}
