# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# Opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Neovim 
if [ -n "$NVIM" ]; then
  _nvim_term_cwd_sync() {
    local key="${NVIM//\//_}"   # replace / with _
    key="${key//:/_}"           # replace : with _
    printf '%s' "$PWD" > "/tmp/nvim_cwd_${key}"
  }
  PROMPT_COMMAND="_nvim_term_cwd_sync${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Terraform
complete -C /usr/bin/terraform terraform

# Starship
eval "$(starship init bash)"
