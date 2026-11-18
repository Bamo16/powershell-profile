<#
.SYNOPSIS
    Fetches the profile repository and records how many upstream commits it is behind.
.DESCRIPTION
    Run hidden by Start-ProfileUpdateCheck, at most weekly. Writes the count to NoticePath, which the
    next launch reports, or removes NoticePath when there is nothing new.
.EXAMPLE
    ./tools/Update-ProfileNotice.ps1 -Root V:\Repos\powershell-profile -NoticePath $env:TEMP\notice.txt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Root,

    [Parameter(Mandatory)]
    [string]$NoticePath
)

git -C $Root fetch --quiet
$count = git -C $Root rev-list --count 'HEAD..@{upstream}'
if ($LASTEXITCODE -eq 0 -and [int]$count -gt 0) {
    Set-Content -LiteralPath $NoticePath -Value $count
} else {
    Remove-Item -LiteralPath $NoticePath -ErrorAction Ignore
}
