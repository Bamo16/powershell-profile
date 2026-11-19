# powershell-profile

Bamo's PowerShell profile. README.md says what it does; this file is what to keep true when
changing it.

- **Startup budget.** Nothing before the first prompt may start a process, touch the network, or
  import a slow module. Cache generated scripts with `Get-CachedScript`, defer with
  `Invoke-WhenIdle`, and register completers with `Register-LazyCompleter`. Check with
  `Get-ProfileTiming` from a real terminal: a session whose output is redirected (any agent's
  shell) skips the profile, so `Measure-ProfileLoad` must run in a terminal too.
- **Two editions.** `profile.ps1`, `bootstrap.ps1` and `src/Core.ps1`, `Console.ps1`, `Prompt.ps1`
  load in Windows PowerShell 5.1: 5.1 syntax and ASCII only (the style tests check both). The
  other `src` parts, `install.ps1` and `tools/` are pwsh 7.6+.
- **Scope.** Each `src` part is dot-sourced into the global scope. Clean up temporary variables
  with `Remove-Variable`; work queued with `Invoke-WhenIdle` runs in its own scope, so it imports
  with `-Global`.
- **Style** is `V:\Repos\coordination\rules\powershell-style.md`, enforced by
  `PSScriptAnalyzerSettings.psd1`. Run `Invoke-Pester ./tests` before committing.
