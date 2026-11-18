# Keeping the profile current without touching the network at startup. Once a week, after the prompt
# is up, a hidden process fetches and counts the new commits. The next launch shows a one-line notice;
# Update-Profile pulls them.

function Update-Profile {
    <#
    .SYNOPSIS
        Pulls new commits to the profile repository and lists what changed.
    .DESCRIPTION
        Fast-forward only: local commits or uncommitted changes that conflict stop the pull rather than
        merge. Open a new terminal afterwards to load the new version.
    .EXAMPLE
        Update-Profile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $root = $ProfileInfo.Root
    if (-not $PSCmdlet.ShouldProcess($root, 'git pull --ff-only')) {
        return
    }

    $before = git -C $root rev-parse HEAD
    git -C $root pull --ff-only --quiet
    if ($LASTEXITCODE) {
        Write-Error -Message "git pull failed in $root; see the output above."

        return
    }

    Remove-Item -LiteralPath (Get-UpdateNoticePath) -ErrorAction Ignore
    $after = git -C $root rev-parse HEAD
    if ($before -eq $after) {
        Write-Host -Object 'The profile is already up to date.'

        return
    }

    git -C $root log --oneline --no-decorate "$before..$after"
    Write-Host -Object 'Open a new terminal to load the new version.' -ForegroundColor Cyan
}


function Get-UpdateNoticePath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Join-Path -Path $ProfileInfo.StateDirectory -ChildPath 'update-available.txt'
}


function Start-ProfileUpdateCheck {
    <#
    .SYNOPSIS
        Fetches the profile repository in a hidden process if the last check was a week or more ago.
    .DESCRIPTION
        The work is tools/Update-ProfileNotice.ps1. -Force checks regardless of when the last check was.
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $stamp = Join-Path -Path $ProfileInfo.StateDirectory -ChildPath 'last-update-check'
    $lastCheck = Get-Item -LiteralPath $stamp -ErrorAction Ignore
    if (-not $Force -and $lastCheck -and $lastCheck.LastWriteTime -gt (Get-Date).AddDays(-7)) {
        return
    }

    $null = New-Item -ItemType Directory -Path $ProfileInfo.StateDirectory -Force
    $null = New-Item -ItemType File -Path $stamp -Force

    $script = Join-Path -Path $ProfileInfo.Root -ChildPath 'tools\Update-ProfileNotice.ps1'
    # Start-Process joins the arguments with spaces and quotes nothing, so the paths carry their own quotes.
    $format = '-NoLogo -NoProfile -NonInteractive -File "{0}" -Root "{1}" -NoticePath "{2}"'
    $arguments = $format -f $script, $ProfileInfo.Root, (Get-UpdateNoticePath)
    Start-Process -FilePath (Get-Process -Id $PID).Path -WindowStyle Hidden -ArgumentList $arguments
}


if (Test-Path -LiteralPath (Get-UpdateNoticePath)) {
    $updateCount = Get-Content -LiteralPath (Get-UpdateNoticePath) -TotalCount 1
    $notice = "Profile updates are waiting upstream (commits: $updateCount). Run Update-Profile to get them."
    Write-Host -Object $notice -ForegroundColor Cyan
    Remove-Variable -Name updateCount, notice
}

Invoke-WhenIdle -ScriptBlock {
    Start-ProfileUpdateCheck
}
