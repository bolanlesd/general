# general — personal toolbox

Shell config, dotfiles, scripts, infra snippets, and notes I use across machines.

## Layout

| Path | Contents |
|---|---|
| [install.sh](install.sh) | Symlinks dotfiles into `$HOME` and installs the `~/.zshrc` bootstrap. |
| [shell/zshrc](shell/zshrc) | **Main zsh config.** Sourced by `~/.zshrc`. |
| [shell/zshrc.local.template](shell/zshrc.local.template) | The slim `~/.zshrc`. Prefers the local clone; falls back to fetching `shell/zshrc` from GitHub. |
| [shell/bashrc](shell/bashrc) | bash equivalent. |
| [dotfiles/](dotfiles/) | [vimrc](dotfiles/vimrc), [tmux.conf](dotfiles/tmux.conf) — symlinked into `$HOME` by `install.sh`. |
| [scripts/](scripts/) | Standalone executable helpers: [youtube-download.sh](scripts/youtube-download.sh), [azdo-create-sprints.sh](scripts/azdo-create-sprints.sh), [aws/](scripts/aws/), [windows/](scripts/windows/). |
| [infra/](infra/) | [docker/](infra/docker/), [compose/](infra/compose/), [k8s/](infra/k8s/) examples. |
| [notes/](notes/) | Cheatsheets / reference: [teleport.md](notes/teleport.md), [tmux.md](notes/tmux.md), [useful-commands.md](notes/useful-commands.md). |
| [sandbox/](sandbox/) | Throwaway experiments (e.g. `csharp-testproject`). Build artifacts are gitignored. |

## Setup on a new machine

```sh
git clone https://github.com/bolanlesd/general.git ~/git/playground/general
cd ~/git/playground/general
./install.sh
exec zsh
```

`install.sh` will:
1. Symlink `dotfiles/vimrc` → `~/.vimrc` and `dotfiles/tmux.conf` → `~/.tmux.conf` (backing up existing files).
2. Install [shell/zshrc.local.template](shell/zshrc.local.template) as `~/.zshrc` if not already present. On machines with the repo cloned at `~/git/playground/general` it sources [shell/zshrc](shell/zshrc) directly; otherwise it downloads it from the `my-mac` branch on GitHub.

## Updating

- Edit [shell/zshrc](shell/zshrc). On this machine the change is live in the next shell (no commit needed). For other machines: commit + push, they pick it up next shell start.
- Edit a dotfile in [dotfiles/](dotfiles/) — symlink means the change is live immediately on this machine.
- Keep [shell/zshrc](shell/zshrc) self-contained — remote machines fetch only this one file.

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

## Windows + Hyper-V Ubuntu VM

Old notes from a previous role — kept for reference:

1. Install Hyper-V.
2. Download a Linux distro (Ubuntu Server works well) and create the VM.
3. Hyper-V doesn't surface the guest IP by default. In the guest run:
   ```sh
   sudo apt-get install "linux-cloud-tools-$(uname -r)"
   ```
   May need a reboot. Then the IP is visible in Hyper-V Manager and you can SSH in.
4. Mount a shared directory from the host: see <https://linuxhint.com/shared_folders_hypver-v_ubuntu_guest/> for the Windows side, then on the guest:
   ```sh
   alias msha="sudo mount -t cifs //<computer name>/<share path> ~/shared -o user=$(whoami),uid=$UID,gid=$(getent group $(whoami) | cut -d ':' -f3)"
   ```
