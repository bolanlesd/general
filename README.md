# general — personal toolbox

Shell config, dotfiles, scripts, infra snippets, and notes I use across machines.
Everything is wired up with one command, syntax-checked in CI, and self-documenting.

## TL;DR

```sh
git clone git@github.com:bolanlesd/general.git ~/git/general
cd ~/git/general && ./install.sh
exec zsh
general doctor      # health-check everything
help                # list every custom function/alias
```

## What you get

- **Modular zsh config** — one file per concern under [shell/parts/](shell/parts/),
  auto-loaded by [shell/zshrc](shell/zshrc). Drop a new `NN-name.zsh` to add behaviour.
- **`general` meta-CLI** — see [bin/general](bin/general):
  `install`, `update`, `build`, `doctor`, `edit`, `help`, `use-starship`, `version`.
- **Self-documenting `help`** — `help [pattern]` lists every custom function/alias with the
  description from its leading `# desc:` comment. `fhelp` is the fzf-powered picker.
- **fzf alias picker** — hit `Ctrl+G` in the shell to fuzzy-search aliases/functions
  and insert the chosen name at the cursor.
- **`g <script>` runner** — run anything in [scripts/](scripts/) by short name, with
  tab-completion. E.g. `g youtube-download <url>`.
- **Cross-platform `updateall`** — picks `brew` / `apt` / `dnf` automatically.
- **Per-machine overrides** — `~/.zshrc.local` is auto-created by `install.sh` and
  sourced last, so machine-specific tweaks stay out of git.
- **Offline-safe bootstrap** — `~/.zshrc` prefers your local clone but falls back to
  `curl`ing [dist/zshrc](dist/zshrc) from GitHub (bypassing corp proxies).
- **Tested in CI** — shellcheck, zsh `-n` syntax check on every part, `dist/zshrc`
  freshness check, and [tests/test_shell.bats](tests/test_shell.bats). See
  [.github/workflows/ci.yml](.github/workflows/ci.yml).
- **Pre-commit hook** — auto-rebuilds [dist/zshrc](dist/zshrc) whenever you touch
  [shell/parts/](shell/parts/), so the remote fallback never drifts.

## Layout

| Path | Contents |
|---|---|
| [install.sh](install.sh) | One-shot setup: symlinks, `~/.zshrc`, `bin/general`, pre-commit hook, `dist/zshrc` build. |
| [bin/general](bin/general) | Meta CLI. `general help` lists subcommands. |
| [shell/zshrc](shell/zshrc) | Loader that sources every `shell/parts/*.zsh`. |
| [shell/parts/](shell/parts/) | Modular config (see below). |
| [shell/zshrc.local.template](shell/zshrc.local.template) | The slim `~/.zshrc` installed on each machine. |
| [shell/bashrc](shell/bashrc) | bash equivalent. |
| [dist/zshrc](dist/zshrc) | Auto-generated single-file build used by the offline fallback. |
| [dotfiles/](dotfiles/) | [vimrc](dotfiles/vimrc), [tmux.conf](dotfiles/tmux.conf) — symlinked into `$HOME`. |
| [scripts/](scripts/) | Standalone helpers: [youtube-download.sh](scripts/youtube-download.sh), [teleport.sh](scripts/teleport.sh), [th-overrides.sh](scripts/th-overrides.sh), [build-zshrc.sh](scripts/build-zshrc.sh), [aws/](scripts/aws/), [windows/](scripts/windows/), [git-hooks/](scripts/git-hooks/). |
| [infra/](infra/) | [docker/](infra/docker/), [compose/](infra/compose/), [k8s/](infra/k8s/) examples. |
| [docs/](docs/) | [secrets.md](docs/secrets.md) (sops+age), [direnv.md](docs/direnv.md), [starship.md](docs/starship.md). |
| [notes/](notes/) | Cheatsheets — [teleport.md](notes/teleport.md), [tmux.md](notes/tmux.md), [useful-commands.md](notes/useful-commands.md). |
| [tests/](tests/) | bats tests. Run with `bats tests/`. |
| [.github/workflows/](.github/workflows/) | CI: shellcheck + zsh syntax + bats. |
| [sandbox/](sandbox/) | Throwaway experiments (gitignored builds). |

## shell/parts/ — modular config

| File | What it provides |
|---|---|
| [00-env.zsh](shell/parts/00-env.zsh) | `VISUAL`/`EDITOR`, `git_branch`, prompt. |
| [10-colors.zsh](shell/parts/10-colors.zsh) | Colorised `ls`/`grep` when `dircolors` is available. |
| [20-aliases.zsh](shell/parts/20-aliases.zsh) | Day-to-day aliases (`gr`, `lsd`, `edit`, `yt-dl`, …). |
| [30-git.zsh](shell/parts/30-git.zsh) | Git aliases + `gco`, `gg`, `gb`. |
| [40-aws.zsh](shell/parts/40-aws.zsh) | `awsp` profile switcher, `awsid`. |
| [50-terragrunt.zsh](shell/parts/50-terragrunt.zsh) | `tg*` aliases, `tgfu`, `tgperm`, `cleantgcache`. |
| [60-azure-devops.zsh](shell/parts/60-azure-devops.zsh) | `create_pr` with `--dry-run`/`--draft`/auto-`az login`/template fill. |
| [70-misc.zsh](shell/parts/70-misc.zsh) | `ppc`, `hc`, cross-platform `updateall`, `create_venv`, `cleanup_venv`. |
| [75-help.zsh](shell/parts/75-help.zsh) | `help [pattern]` + `fhelp`. |
| [76-fzf.zsh](shell/parts/76-fzf.zsh) | `Ctrl+G` fuzzy alias/function picker. |
| [77-g-runner.zsh](shell/parts/77-g-runner.zsh) | `g <script>` runner + completion. |
| [80-completion.zsh](shell/parts/80-completion.zsh) | kubectl completion, teleport CLI. |
| [99-th-overrides.zsh](shell/parts/99-th-overrides.zsh) | Sources [scripts/th-overrides.sh](scripts/th-overrides.sh) last. |

Add new behaviour by dropping a new `NN-name.zsh` into `shell/parts/`. The pre-commit hook
will rebuild [dist/zshrc](dist/zshrc) for you on commit.

## The `general` CLI

```text
general install         install/refresh ~/.zshrc bootstrap + symlinks
general update          git pull && rebuild dist/zshrc
general build           rebuild dist/zshrc from shell/parts/*.zsh
general doctor          health-check: brew, fzf, repo path, ~/.zshrc, symlinks
general edit [thing]    open repo (or a specific part) in $EDITOR
general help            print subcommand list
general use-starship    enable starship prompt (writes to ~/.zshrc.local)
general version         print current commit SHA
```

## Conventions

- **Self-documenting:** every function gets a leading `# desc: <one-line summary>` comment.
  `help` picks these up automatically.
- **`~/.zshrc.local`** is for machine-specific bits (corp proxies, work-only aliases,
  starship init, direnv hook). Never commit it.
- **`dist/zshrc` is generated** — never edit by hand. The pre-commit hook + CI enforce this.
- **Bash scripts** (under [scripts/](scripts/) and [bin/](bin/)) are shellcheck-clean.

## Workflows

- **Add a new alias/function:** edit the matching `shell/parts/NN-*.zsh`, `exec zsh`, done.
- **Add a new script:** drop it in [scripts/](scripts/), make it executable. Then `g <name>` just works.
- **Update another machine:** `general update` (= `git pull && general build`).
- **Reproducible install on a fresh box:** `git clone … && ./install.sh && general doctor`.

## Extras (opt-in)

- **[Encrypted secrets](docs/secrets.md)** — sops + age workflow with `.sops.yaml` examples.
- **[direnv](docs/direnv.md)** — per-project env vars, plus a `sops`-loaded `.envrc` recipe.
- **[Starship prompt](docs/starship.md)** — `general use-starship` to enable.

## Vim plug commands

Plugin manager: <https://github.com/junegunn/vim-plug>

| Command | Description |
|---|---|
| `PlugInstall [name ...] [#threads]` | Install plugins |
| `PlugUpdate [name ...] [#threads]` | Install or update plugins |
| `PlugClean[!]` | Remove unlisted plugins (bang = no prompt) |
| `PlugUpgrade` | Upgrade vim-plug itself |
| `PlugStatus` | Check plugin status |
| `PlugDiff` | Examine changes from previous update and pending changes |
| `PlugSnapshot[!] [output path]` | Generate script to restore current snapshot |
