# Dotfiles

This repository contains my personal configuration files. The setup uses GNU Stow to manage
symlinks and make the configuration portable across systems, and Ansible for full machine
provisioning on Fedora.

## Structure

    dotfiles/
      ansible/        # Fedora workstation provisioning playbook
      bin/            # Scripts
      bash/
      nvim/
      kitty/
      tmux/
      starship/
      opencode/
      zsh/

Each module mirrors the expected structure under the home directory.\
For example:

    bash/.bashrc        -> ~/.bashrc
    nvim/.config/nvim   -> ~/.config/nvim

## Usage

### Option 1: Just the dotfiles (any distro)

Clone the repository into your home directory:

    git clone https://github.com/yaliach/dotfiles.git ~/dotfiles
    cd ~/dotfiles

Then apply individual modules:

    stow bash
    stow nvim
    stow kitty
    stow tmux
    stow starship
    stow zsh
    stow opencode

### Option 2: Full Fedora provisioning (Ansible)

On a fresh Fedora Workstation install:

    # Install Ansible
    sudo dnf install -y ansible

    # Clone this repo
    git clone https://github.com/yaliach/dotfiles.git ~/dotfiles
    
    # Adjust vars and setup home directory and user
    vim ~/dotfiles/ansible/vars.yml   

    # Run the playbook (asks for sudo password)
    ansible-playbook ~/dotfiles/ansible/playbook.yml -K

 ## Notes

- The dotfiles repository must be located directly in the home directory. Otherwise, Stow will not target the correct location unless the $HOME directory is explicitly specified using the -t option.
- The Ansible playbook is idempotent and safe to re-run multiple times.
