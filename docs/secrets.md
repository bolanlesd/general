# Encrypted secrets with sops + age

We use [sops](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) keys
for any secrets that need to live in this repo (or in repos that consume this toolbox).

## One-time setup

```sh
brew install sops age

# Generate a key (keep this file safe — back it up to 1Password / a USB).
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# Show your public key:
grep '# public key' ~/.config/sops/age/keys.txt
```

Add the public key to `.sops.yaml` at the root of any repo whose secrets you want to be
able to decrypt:

```yaml
creation_rules:
  - path_regex: secrets\.enc\.ya?ml$
    age: age1examplepublickeygoeshere...
```

## Daily use

```sh
# Edit (decrypts in your editor, re-encrypts on save):
sops secrets.enc.yaml

# Decrypt to stdout (e.g. to load into env):
sops -d secrets.enc.yaml

# Encrypt a fresh plaintext file:
sops -e -i secrets.yaml && mv secrets.yaml secrets.enc.yaml
```

See [`secrets.enc.yaml.example`](secrets.enc.yaml.example) for the shape of a typical file.
