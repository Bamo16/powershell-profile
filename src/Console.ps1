# Encoding, line editing, and directory-listing icons.

# Native tools (dotnet, uv, git) write UTF-8; read with the OEM code page it turns into mojibake,
# which looks like a font problem and isn't one.
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $utf8
$Global:OutputEncoding = $utf8
Remove-Variable -Name utf8

# The ISE has no PSReadLine.
if ($readLine = Get-Module -Name PSReadLine) {
    $readLineOptions = @{
        HistoryNoDuplicates           = $true
        MaximumHistoryCount           = 10000
        HistorySearchCursorMovesToEnd = $true
        BellStyle                     = 'None'
    }

    # Windows PowerShell ships PSReadLine 2.0, which has no predictions; plugins need pwsh 7.2.
    if ($readLine.Version -ge [version]'2.1') {
        $readLineOptions.PredictionSource = 'History'
        if ($PSVersionTable.PSVersion -ge [version]'7.2' -and $readLine.Version -ge [version]'2.2') {
            $readLineOptions.PredictionSource = 'HistoryAndPlugin'
            $readLineOptions.PredictionViewStyle = 'InlineView'
        }
    }

    Set-PSReadLineOption @readLineOptions

    # Tab shows every match in a menu instead of cycling blind.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    # Up and Down search history for lines starting with what is already typed.
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # Ctrl+Right takes the next word of a grey suggestion; Right (or End) takes all of it.
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

    Remove-Variable -Name readLineOptions
}

Remove-Variable -Name readLine

# Terminal-Icons takes most of a second to import, so it loads after the prompt is up.
Invoke-WhenIdle -ScriptBlock {
    Import-Module -Name Terminal-Icons -Global -ErrorAction Ignore
}
