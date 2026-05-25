# 00-env.zsh — editor, prompt, vcs_info
# Sets up VISUAL/EDITOR and the custom PROMPT with git branch info.

export VISUAL=vim
export EDITOR="$VISUAL"

# desc: print current git branch in (parens) for the prompt
git_branch() {
    # Print "(branch-name)" when inside a git repo, otherwise nothing.
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        echo "($branch)"
    fi
}

autoload -Uz vcs_info
precmd() { vcs_info }
setopt PROMPT_SUBST
PROMPT='%F{yellow}%* %F{blue}%~ %F{green}$(git_branch)%f $ '
