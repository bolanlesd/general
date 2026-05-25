# Starship prompt

The default prompt is the lightweight `vcs_info`-based one in `shell/parts/00-env.zsh`.
If you'd rather use [starship](https://starship.rs), enable it via:

```sh
brew install starship
general use-starship   # appends `eval "$(starship init zsh)"` to ~/.zshrc.local
exec zsh
```

The base prompt in `00-env.zsh` will still be set, but `starship` overrides it after init.
To disable, remove the line from `~/.zshrc.local` and `exec zsh`.

## Custom config

Starship config lives in `~/.config/starship.toml`. A minimal config that plays nicely
with this repo:

```toml
add_newline = false
format = "$directory$git_branch$git_status$aws$kubernetes$character"

[aws]
format = '[$symbol($profile )]($style)'

[kubernetes]
disabled = false
```
