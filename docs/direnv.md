# direnv integration

[direnv](https://direnv.net) auto-loads/unloads per-project env vars when you `cd` into a directory.

## Install + hook

```sh
brew install direnv
# Add to ~/.zshrc.local so it survives across machines:
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc.local
```

## Example .envrc

Drop a `.envrc` into any project root:

```sh
# .envrc — per-project environment
export AWS_PROFILE=staging
export TF_VAR_environment=staging
export TF_LOG=INFO

# Layered Python venv (auto-activated):
layout python3
```

Then `direnv allow` once to trust it.

## Pair with sops

```sh
# .envrc that pulls decrypted secrets from a sops file:
eval "$(sops -d secrets.enc.yaml | yq -r 'to_entries|.[]|"export \(.key)=\(.value)"')"
```
