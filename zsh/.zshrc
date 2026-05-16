# Path to oh-my-zs
export ZSH="$HOME/.oh-my-zsh"

# Plugins
plugins=(
    git
    docker
    kubectl
    terraform
    python
    pip
    dnf
    sudo
    history
    command-not-found
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Source global definitions
if [[ -f /etc/zshrc ]]; then
    source /etc/zshrc
fi

# User specific environment
if [[ ! "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# User specific aliases and functions
if [[ -d ~/.zshrc.d ]]; then
    for rc in ~/.zshrc.d/*(N); do
        if [[ -f "$rc" ]]; then
            source "$rc"
        fi
    done
fi
unset rc

# Opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Neovim 
if [[ -n "$NVIM" ]]; then
  _nvim_term_cwd_sync() {
    local key="${NVIM//\//_}"   # replace / with _
    key="${key//:/_}"           # replace : with _
    printf '%s' "$PWD" > "/tmp/nvim_cwd_${key}"
  }
  precmd_functions+=(_nvim_term_cwd_sync)
fi

# Terraform
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/bin/terraform terraform

# zoxide
eval "$(zoxide init zsh)"

# Starship (load at the end to override Oh My Zsh prompt)
eval "$(starship init zsh)"
