<#
    Sets up the profile on a new machine, from Windows PowerShell or pwsh:

        irm https://raw.githubusercontent.com/Bamo16/powershell-profile/main/bootstrap.ps1 | iex

    Installs git and pwsh with winget if missing, clones this repository, and runs install.ps1.
    Clones to $env:PROFILE_REPO_PATH if set, else V:\Repos\powershell-profile when V:\Repos exists,
    else ~\source\repos\powershell-profile. Must stay Windows PowerShell 5.1 compatible.
#>
& {
    $ErrorActionPreference = 'Stop'

    function Get-Tool {
        param(
            [string]$Name,
            [string]$WingetId,
            [string]$DefaultPath
        )

        $command = Get-Command -Name $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
        if ($command) {
            return $command.Source
        }

        winget install --id $WingetId --exact --source winget `
            --accept-package-agreements --accept-source-agreements
        # This session's PATH predates the install, so use where the installer puts it.
        $DefaultPath
    }

    $git = Get-Tool -Name git -WingetId Git.Git -DefaultPath "$env:ProgramFiles\Git\cmd\git.exe"
    # From 7.7 winget installs pwsh as an MSIX package (there is no MSI), reached through an app alias.
    $pwsh = Get-Tool -Name pwsh -WingetId Microsoft.PowerShell `
        -DefaultPath "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"

    $destination = $env:PROFILE_REPO_PATH
    if (-not $destination) {
        $repos = 'V:\Repos'
        if (-not (Test-Path -LiteralPath $repos)) {
            $repos = Join-Path -Path $HOME -ChildPath 'source\repos'
        }

        $destination = Join-Path -Path $repos -ChildPath 'powershell-profile'
    }

    if (Test-Path -LiteralPath (Join-Path -Path $destination -ChildPath '.git')) {
        & $git -C $destination pull --ff-only
    } else {
        & $git clone https://github.com/Bamo16/powershell-profile.git $destination
    }

    if ($LASTEXITCODE) {
        throw "git failed with exit code $LASTEXITCODE."
    }

    & $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path -Path $destination -ChildPath 'install.ps1')
}
