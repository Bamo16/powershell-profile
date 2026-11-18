# powershell-profile

My PowerShell profile: a starship prompt, completion for the tools I use, and a startup that does
as little as it can before the prompt appears.

## Install

On a new machine, from Windows PowerShell or pwsh:

```powershell
irm https://raw.githubusercontent.com/Bamo16/powershell-profile/main/bootstrap.ps1 | iex
```

That installs git and pwsh if they are missing, clones this repository (to `V:\Repos` when it
exists, else `~\source\repos`; set `$env:PROFILE_REPO_PATH` first to choose), and runs
`install.ps1`. With the repository already cloned, run `./install.ps1` from pwsh; it is safe to
run again.

`install.ps1` writes a two-line stub to each edition's all-hosts profile
(`Documents\PowerShell\profile.ps1` and `Documents\WindowsPowerShell\profile.ps1`) that
dot-sources `profile.ps1` here, so every host loads the same profile: Windows Terminal, VS Code's
terminal, the PowerShell extension's terminal and plain console windows. It also installs starship,
posh-git, Terminal-Icons and CaskaydiaCove Nerd Font Mono (machine-wide, one UAC prompt) when they
are missing.

Set the terminal font to **CaskaydiaCove Nerd Font Mono** in Windows Terminal (Settings > Defaults >
Appearance) and VS Code (`terminal.integrated.fontFamily`).

## Updating

Once a week, after the prompt is up, a hidden process fetches this repository. When there is
something new, the next terminal says so in one line. Run `Update-Profile` to pull it (fast-forward
only), then open a new terminal.

## Commands

| command | does |
|---|---|
| `repo <name>` | changes to a repository under `V:\Repos`; Tab completes any part of the name |
| `Update-Profile` | pulls new commits to this repository |
| `Edit-Profile` | opens this repository in VS Code |
| `Get-ProfileTiming` | how long each part of the profile took in this session |
| `Measure-ProfileLoad` | median startup time of fresh shells, with and without the profile |
| `refreshenv` | reloads PATH and other variables from the registry (Chocolatey's) |

Keys: **Tab** shows every match in a menu; **Up/Down** search history for lines starting with what
is typed; **Right** accepts the grey suggestion, **Ctrl+Right** one word of it; **F2** switches the
suggestion between inline and a list.

Tab completion covers git (posh-git), dotnet, gh, uv, winget and choco, and every command in every
module on `$env:PSModulePath`: modules load on first use, never at startup.

## How it stays fast

Nothing slow runs before the first prompt:

- **Starship's init script is cached** under `%LOCALAPPDATA%\powershell-profile\cache`, regenerated
  only when starship.exe or `starship.toml` changes.
- **Completion scripts load on a command's first Tab**, not at startup. The dotnet, gh and uv scripts
  run from 10 KB to 700 KB, and are cached until the tool (for dotnet, the newest SDK) changes.
- **Terminal-Icons and the update check run once the prompt is up**, on PowerShell's idle event.
- **Scripts get none of it**: `pwsh -Command`, `-File` and redirected sessions skip the profile.

`Windows PowerShell` gets the prompt and line editing; completion and the commands above are pwsh
7.4 and up.

## Prompt

Agnoster-style segments (`starship.toml`), each shown only when it has something to say: a failed
command's exit code, the folder, the git branch, uncommitted changes, the .NET or Python version,
and how long the last command took when it was 2 s or more.

The language segments come from files in the folder the terminal is in, not from an editor:

- **.NET** shows in a folder with a `.sln`/`.slnx`, a project file, `global.json` or
  `Directory.Build.props`. The SDK version comes from `global.json` without running dotnet. The
  target framework only appears in a folder whose project file sets `<TargetFramework>` itself.
- **Python** shows in a folder with `pyproject.toml`, `.python-version`, `requirements.txt` or `.py`
  files. The version is the project's `.venv` Python when there is one (uv runs it without
  activating), else the `python` on PATH; it costs about 60 ms a prompt there. An activated venv
  adds its name.

## Fonts

The prompt uses Nerd Font glyphs and never emoji (`starship.toml`). An emoji's width differs between
terminals and fallback fonts, which is the usual cause of a prompt that garbles or misplaces the
cursor in one terminal but not another. The font is installed for all users because some programs
ignore fonts installed for one user only.

## Development

```powershell
Invoke-Pester ./tests
```

`tests/Style.Tests.ps1` runs PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1`, checks
formatting, and checks that what Windows PowerShell loads is 5.1 syntax and ASCII. Needs Pester 5+
and PSScriptAnalyzer (`Install-PSResource Pester, PSScriptAnalyzer`).
