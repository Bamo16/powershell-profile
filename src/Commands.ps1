# Commands for living with the profile, plus `repo` for jumping between repositories.

function Edit-Profile {
    <#
    .SYNOPSIS
        Opens the profile repository in VS Code.
    #>
    [CmdletBinding()]
    param()

    code $ProfileInfo.Root
}


function Get-ProfileTiming {
    <#
    .SYNOPSIS
        Shows how long each part of the profile took to load in this session.
    .EXAMPLE
        Get-ProfileTiming
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $ProfileInfo.Timings
}


function Measure-ProfileLoad {
    <#
    .SYNOPSIS
        Starts fresh shells to measure how long startup takes with and without the profile.
    .DESCRIPTION
        Reports the median of several runs of the same PowerShell as this session. The profile's own
        share is the difference between the two.
    .EXAMPLE
        Measure-ProfileLoad -Count 10
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateRange(1, 50)]
        [int]$Count = 5
    )

    $executable = (Get-Process -Id $PID).Path
    foreach ($withProfile in $true, $false) {
        $arguments = @('-NoLogo', '-NoExit', '-Command', 'exit')
        if (-not $withProfile) {
            $arguments = @('-NoProfile') + $arguments
        }

        # Start-Process shares this console, so the child sees an interactive session, not a pipe.
        $runs = foreach ($run in 1..$Count) {
            (Measure-Command -Expression {
                Start-Process -FilePath $executable -ArgumentList $arguments -NoNewWindow -Wait
            }).TotalMilliseconds
        }

        $sorted = $runs | Sort-Object
        [pscustomobject]@{
            Profile = $withProfile
            MedianMs = [math]::Round($sorted[[math]::Floor($Count / 2)])
            FastestMs = [math]::Round($sorted[0])
            SlowestMs = [math]::Round($sorted[-1])
        }
    }
}


function Enter-Repository {
    <#
    .SYNOPSIS
        Changes to a repository under the repos folder, with tab completion on any part of its name.
    .DESCRIPTION
        The repos folder is $env:REPOS_ROOT, else V:\Repos, else ~\source\repos. With no name, goes to
        the repos folder itself.
    .EXAMPLE
        repo crate
    #>
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete)

                $names = (Get-ChildItem -LiteralPath (Get-RepositoryRoot) -Directory).Name
                # Prefix matches first, then names that only contain what was typed.
                @($names | Where-Object -FilterScript { $_ -like "$wordToComplete*" }) +
                @($names | Where-Object -FilterScript {
                        $_ -like "?*$wordToComplete*" -and $_ -notlike "$wordToComplete*"
                    })
            })]
        [string]$Name
    )

    $root = Get-RepositoryRoot
    if (-not $Name) {
        Set-Location -LiteralPath $root

        return
    }

    $exact = Join-Path -Path $root -ChildPath $Name
    if (Test-Path -LiteralPath $exact -PathType Container) {
        Set-Location -LiteralPath $exact

        return
    }

    # A partial name works too, when it matches exactly one repository.
    $matching = @(Get-ChildItem -LiteralPath $root -Directory | Where-Object -Property Name -Like "*$Name*")
    switch ($matching.Count) {
        1 { Set-Location -LiteralPath $matching[0].FullName }
        0 { Write-Error -Message "No repository under $root matches '$Name'." }
        default { Write-Error -Message "'$Name' matches several repositories: $($matching.Name -join ', ')." }
    }
}


function Get-RepositoryRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($env:REPOS_ROOT) {
        return $env:REPOS_ROOT
    }

    if (Test-Path -LiteralPath 'V:\Repos') {
        return 'V:\Repos'
    }

    Join-Path -Path $HOME -ChildPath 'source\repos'
}


Set-Alias -Name repo -Value Enter-Repository
