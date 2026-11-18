#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs every style of CaskaydiaCove Nerd Font Mono for all users.
.DESCRIPTION
    Machine-wide on purpose: a font installed for one user only is invisible to some programs, which
    is a classic cause of a font that works in one terminal and not another. install.ps1 runs this
    elevated when the font is missing.
.EXAMPLE
    ./tools/Install-NerdFont.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Uri = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip'
)

$ErrorActionPreference = 'Stop'
$workDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "nerd-font-$PID"
$fontsDirectory = Join-Path -Path $env:windir -ChildPath 'Fonts'
$registryKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

try {
    $null = New-Item -ItemType Directory -Path $workDirectory
    $archive = Join-Path -Path $workDirectory -ChildPath 'font.zip'
    Invoke-WebRequest -Uri $Uri -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $workDirectory

    foreach ($font in Get-ChildItem -LiteralPath $workDirectory -Filter 'CaskaydiaCoveNerdFontMono-*.ttf') {
        if ($PSCmdlet.ShouldProcess($font.Name, 'Install font')) {
            Copy-Item -LiteralPath $font.FullName -Destination $fontsDirectory -Force
            # 'CaskaydiaCoveNerdFontMono-BoldItalic' becomes 'CaskaydiaCove Nerd Font Mono BoldItalic'.
            $style = $font.BaseName.Split('-')[1]
            $name = "CaskaydiaCove Nerd Font Mono $style (TrueType)"
            Set-ItemProperty -LiteralPath $registryKey -Name $name -Value $font.Name
        }
    }
} finally {
    Remove-Item -LiteralPath $workDirectory -Recurse -Force -ErrorAction Ignore
}
