# Dotfiles

These dotfiles customize my Bash environment and prompt.

## Features
- **Strict mode**: sets pipefail, etc.
- **Shared history**: immediate history sync across shells.
- **Lightweight bash-completion** and *Bash‑It* modules.
- **Starship prompt** with caching and minimal fallback.
- **Optional ble.sh** for autosuggestions and syntax highlighting.
- **fzf** key bindings and completions.
- **ROS 2 underlay/overlay** auto-loading on demand.
- Convenient aliases including a `config` alias for managing dotfiles via a bare Git repository.

## Files
- `.bashrc` – main shell configuration.
- `.config/starship.toml` – Starship prompt configuration that displays the current ROS workspace.

## Installation
Install these tools to get the most out of the configuration:

- **git** – required for the `config` alias.
- **bash-completion** – standard command completion scripts.
- **Bash‑It** – optional aliases and plugins. Clone to `~/.bash_it`.
- **starship** – fast prompt. `curl -sS https://starship.rs/install.sh | sh -s -- -y`
- **fzf** – fuzzy finder. `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --key-bindings --completion --no-update-rc`
- **ble.sh** *(optional)* – autosuggestions and syntax highlighting. `git clone --depth 1 https://github.com/akinomyoga/ble.sh.git ~/.local/share/ble.sh && make -C ~/.local/share/ble.sh install PREFIX=~/.local`

## Getting started
Clone the repository and check out the files into your home directory using a bare Git repo. This lets you track dotfiles without nested working tree files.

```bash
# 1. Clone as a bare repository
git clone --bare <repo-url> "$HOME/.cfg"

# 2. Create an alias for convenience (also defined in `.bashrc`)
alias config='/usr/bin/git --git-dir="$HOME/.cfg" --work-tree="$HOME"'

# 3. Check out the tracked files
config checkout

# 4. Hide untracked files from status output
config config --local status.showUntrackedFiles no
```

Back up any existing files that would be overwritten before running `config checkout`.

After cloning, install optional tools like **starship**, **fzf**, and **ble.sh** to unlock all features. When you open a new shell, the greeting `[Bash ready]` confirms the configuration has loaded.

