#Requires -Version 7.6
<#
.SYNOPSIS
    Points pwsh and Windows PowerShell at this repository's profile and installs what it uses.
.DESCRIPTION
    Safe to run again. Writes a stub that dot-sources profile.ps1 to each edition's all-hosts profile,
    keeping any other profile already there as a .bak file. Installs starship, posh-git and
    Terminal-Icons when missing, and the CaskaydiaCove Nerd Font machine-wide (one UAC prompt).
.EXAMPLE
    ./install.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$marker = '# Managed by powershell-profile.'
$documents = [Environment]::GetFolderPath('MyDocuments')
$entryPoint = Join-Path -Path $PSScriptRoot -ChildPath 'profile.ps1'
$stub = @"
$marker Edit the repository, not this file: $PSScriptRoot
`$profileEntryPoint = '$($entryPoint -replace "'", "''")'
if (Test-Path -LiteralPath `$profileEntryPoint) {
    . `$profileEntryPoint
}

Remove-Variable -Name profileEntryPoint
"@

foreach ($edition in 'PowerShell', 'WindowsPowerShell') {
    $directory = Join-Path -Path $documents -ChildPath $edition
    $allHosts = Join-Path -Path $directory -ChildPath 'profile.ps1'

    if ((Test-Path -LiteralPath $allHosts) -and
        -not (Select-String -LiteralPath $allHosts -SimpleMatch -Pattern $marker -Quiet) -and
        $PSCmdlet.ShouldProcess($allHosts, 'Keep the existing profile as a .bak file')) {
        Move-Item -LiteralPath $allHosts -Destination "$allHosts.$(Get-Date -Format yyyyMMdd).bak"
    }

    if ($PSCmdlet.ShouldProcess($allHosts, 'Write the profile stub')) {
        $null = New-Item -ItemType Directory -Path $directory -Force
        Set-Content -LiteralPath $allHosts -Value $stub -Encoding utf8BOM
    }

    # These run on top of the stub's profile in their own hosts, so anything in them still applies.
    foreach ($hostProfile in Get-ChildItem -LiteralPath $directory -Filter '*_profile.ps1' -ErrorAction Ignore) {
        Write-Warning -Message (
            "$($hostProfile.FullName) still runs after this profile; move what it does into the repository.")
    }
}

# Windows PowerShell defaults to Restricted on a fresh machine, which would refuse to run the stub.
$windowsPolicy = powershell.exe -NoProfile -Command Get-ExecutionPolicy
if ($windowsPolicy -in 'Restricted', 'AllSigned', 'Undefined' -and
    $PSCmdlet.ShouldProcess('Windows PowerShell, current user', 'Set-ExecutionPolicy RemoteSigned')) {
    powershell.exe -NoProfile -Command `
        'Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force'
}

if (-not (Get-Command -Name starship -CommandType Application -ErrorAction Ignore) -and
    $PSCmdlet.ShouldProcess('starship', 'winget install')) {
    winget install --id Starship.Starship --exact --source winget `
        --accept-package-agreements --accept-source-agreements
}

# Windows Terminal reads every fragment in this folder at startup; a junction keeps it in step with the
# repository, and needs no elevation.
$fragments = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows Terminal\Fragments\powershell-profile'
$fragmentSource = Join-Path -Path $PSScriptRoot -ChildPath 'terminal'
$existing = Get-Item -LiteralPath $fragments -Force -ErrorAction Ignore
if ($existing -and -not $existing.LinkType) {
    Write-Warning -Message "$fragments is a real folder, not a link; move it aside to install the fragment."
} elseif ($existing.Target -ne $fragmentSource -and
    $PSCmdlet.ShouldProcess($fragments, 'Link to the Windows Terminal fragment')) {
    if ($existing) {
        # Deletes the link alone, never what it points to.
        [System.IO.Directory]::Delete($fragments)
    }

    $null = New-Item -ItemType Directory -Path (Split-Path -Path $fragments -Parent) -Force
    $null = New-Item -ItemType Junction -Path $fragments -Target $fragmentSource
}

foreach ($module in 'posh-git', 'Terminal-Icons') {
    if (-not (Get-Module -Name $module -ListAvailable) -and
        $PSCmdlet.ShouldProcess($module, 'Install-PSResource')) {
        Install-PSResource -Name $module -Scope CurrentUser -TrustRepository -Quiet
    }
}

$fonts = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$fontInstalled = $fonts.PSObject.Properties.Name -like 'CaskaydiaCove Nerd Font Mono*'
if (-not $fontInstalled -and $PSCmdlet.ShouldProcess('CaskaydiaCove Nerd Font Mono', 'Install machine-wide')) {
    $fontScript = Join-Path -Path $PSScriptRoot -ChildPath 'tools\Install-NerdFont.ps1'
    Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-File', "`"$fontScript`""
    )
}

Write-Host -Object @'
Done. Open a new terminal to load the profile.
Set the terminal font to 'CaskaydiaCove Nerd Font Mono' wherever it isn't already:
  Windows Terminal  Settings > Defaults > Appearance > Font face
  VS Code           "terminal.integrated.fontFamily": "'CaskaydiaCove Nerd Font Mono'"
'@
