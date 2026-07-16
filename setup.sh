#!/bin/bash
# One-shot terminal-experience port: Ghostty + zsh stack.
# Run on the target Mac AFTER Homebrew is installed:  bash blackmac-setup.sh
set -e

# Piped/non-login shells don't read .zprofile — find brew ourselves.
for B in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$B" ] && eval "$("$B" shellenv)" && break
done
command -v brew >/dev/null || { echo "Homebrew not found — install it first: https://brew.sh"; exit 1; }

# Make sure future login shells see brew too.
grep -q 'brew shellenv' ~/.zprofile 2>/dev/null || \
  echo "eval \"\$($(command -v brew) shellenv)\"" >> ~/.zprofile

echo "==> brew packages"
[ -d /Applications/Ghostty.app ] || brew list --cask ghostty &>/dev/null || brew install --cask ghostty
brew list --cask font-hack-nerd-font &>/dev/null || brew install --cask font-hack-nerd-font
brew install starship fzf eza yazi zsh-autosuggestions zsh-syntax-highlighting

echo "==> fzf-tab plugin"
mkdir -p ~/.config/zsh
[ -d ~/.config/zsh/fzf-tab ] || git clone --depth 1 https://github.com/Aloxaf/fzf-tab ~/.config/zsh/fzf-tab

echo "==> ghostty config"
mkdir -p ~/.config/ghostty
cat > ~/.config/ghostty/config <<'GHOSTTY'
# === Theme === (Warp "dark" approximation, black bg)
background = #000000
foreground = #eef1f6
cursor-color = #62b9ff
selection-background = #2d4a63
selection-foreground = #ffffff

# ANSI palette — mimics Warp default dark
palette = 0=#3b4048
palette = 1=#ff6767
palette = 2=#5af78e
palette = 3=#f3f99d
palette = 4=#57c7ff
palette = 5=#ff6ac1
palette = 6=#9aedfe
palette = 7=#d6dae4
palette = 8=#5c6370
palette = 9=#ff8c8c
palette = 10=#7bffaa
palette = 11=#fdf6b3
palette = 12=#8fd9ff
palette = 13=#ff92d0
palette = 14=#b9f6ff
palette = 15=#ffffff

# === Font ===
font-family = Hack Nerd Font
font-size = 16

window-padding-x = 12
window-padding-y = 8
confirm-close-surface = false

# Treat Option as Alt so alt+backspace etc. reach TUIs like Claude Code
macos-option-as-alt = true

# === Tabs ===
keybind = cmd+t=new_tab
keybind = cmd+w=close_surface
keybind = cmd+shift+left=previous_tab
keybind = cmd+shift+right=next_tab

# === Splits ===
split-divider-color = #3b4048
unfocused-split-opacity = 0.8
keybind = cmd+d=new_split:right
keybind = cmd+shift+d=new_split:down
keybind = cmd+alt+left=goto_split:left
keybind = cmd+alt+right=goto_split:right
keybind = cmd+alt+up=goto_split:up
keybind = cmd+alt+down=goto_split:down
keybind = cmd+shift+enter=toggle_split_zoom

# === Command "blocks" (shell-integration prompt jumping) ===
keybind = cmd+up=jump_to_prompt:-1
keybind = cmd+down=jump_to_prompt:1
keybind = cmd+k=clear_screen
GHOSTTY

echo "==> zshrc (appending; existing content untouched)"
if grep -q "ported terminal experience" ~/.zshrc 2>/dev/null; then
  echo "    already present, skipping"
else
cat >> ~/.zshrc <<'ZSHRC'

# >>> ported terminal experience >>>
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"

autoload -Uz compinit && compinit -C

# fzf: fuzzy history (ctrl-r), file search (ctrl-t), cd into dir (alt-c)
command -v fzf >/dev/null && eval "$(fzf --zsh)"
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline"

# fzf-tab: fzf picker as the tab-completion menu (after compinit, before wrappers)
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group ',' '.'
[ -f ~/.config/zsh/fzf-tab/fzf-tab.plugin.zsh ] && source ~/.config/zsh/fzf-tab/fzf-tab.plugin.zsh

[ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
  source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
command -v starship >/dev/null && eval "$(starship init zsh)"

# kubectl, if/when the day job hands one over
if command -v kubectl >/dev/null; then
  alias k=kubectl
  compdef k=kubectl 2>/dev/null
fi

# claude with sonnet subagents
alias cc="CLAUDE_CODE_SUBAGENT_MODEL=sonnet claude"

# === eza: clickable file:// links (cmd+click in Ghostty), icons, dirs first ===
alias ls='eza --hyperlink --icons --group-directories-first'
alias ll='eza --hyperlink --icons --group-directories-first -lah --git'
alias la='eza --hyperlink --icons --group-directories-first -a'
alias lt='eza --hyperlink --icons --tree --level=2'

# === yazi: visual file browser; `y` cds to wherever you quit ===
y() {
  local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# editor: cursor if present, else whatever the day job allows
if command -v cursor >/dev/null; then
  export EDITOR="cursor --wait"; export VISUAL="cursor --wait"
  e() { cursor "${@:-.}"; }
fi
# <<< ported terminal experience <<<
ZSHRC
fi

echo
echo "Done. Open Ghostty, run: claude   (or cc)"
