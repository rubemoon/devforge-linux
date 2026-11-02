#!/usr/bin/env bash

show_help() {
  cat <<'HELP'
DevForge Linux 1.0.0 — Linux developer workstation setup

Usage:
  devforge menu
  devforge install fullstack
  devforge install essentials,ruby,rails,node,dbclients
  devforge install essentials ruby rust --dry-run
  devforge doctor
  devforge list
  devforge --version

Modules:
  fullstack    Rails, Node.js, Python, Rust, PostgreSQL, Podman, Flutter
  essentials   Git, compilers, libraries, curl, jq, and basic tools
  asdf         Current asdf version manager with Bash/Zsh shims
  ruby         Stable Ruby via asdf (default) or rbenv
  rails        Ruby, Bundler, and Rails gems
  node         Node.js LTS via asdf (default) or nvm
  python       Stable Python via asdf
  rust         Stable Rust, rustup, Cargo, Clippy, and rustfmt
  dbclients    PostgreSQL and MariaDB clients
  postgres     PostgreSQL server; does not start the service
  mariadb      MariaDB/MySQL server; does not start the service
  podman       Podman containers
  flutter      Stable Flutter Linux SDK; Android SDK is separate

Options:
  --dry-run                  Preview actions without changing files or packages
  --yes                      Confirm the installation plan automatically
  --ruby-manager asdf|rbenv  (default: asdf)
  --node-manager asdf|nvm    (default: asdf)
  --ruby-version X.Y.Z       Pin the Ruby version for this installation
  --node-version X.Y.Z       Pin the Node.js version for this installation
  --python-version X.Y.Z     Pin the Python version for this installation
  --help / -h                Show help

Never run DevForge with sudo. Review --dry-run before installing.
HELP
}

show_list() {
  local item
  for item in "${DF_MODULES[@]}"; do printf '  %-14s %s\n' "$item" "${DF_DESCRIPTIONS[$item]}"; done
}

menu() {
  local opt answer i line
  local -a selected=()
  [[ -t 0 ]] || die 'The menu requires a terminal. Use devforge install ...'
  printf '\n  DevForge Linux / Developer Bootstrap\n'
  printf '  Distribution: %s\n\n' "$DF_PRETTY"
  i=1
  for opt in "${DF_MODULES[@]}"; do
    printf '  %2d) %-14s %s\n' "$i" "$opt" "${DF_DESCRIPTIONS[$opt]}"
    ((i+=1))
  done
  printf '\nChoose numbers separated by spaces (e.g. 1 3 4 5): '
  read -r line
  [[ -n $line ]] || die 'No modules selected.'
  for answer in $line; do
    [[ $answer =~ ^[0-9]+$ ]] || die "Invalid number: $answer"
    (( answer>=1 && answer<=${#DF_MODULES[@]} )) || die 'Menu index out of range.'
    selected+=("${DF_MODULES[answer-1]}")
  done
  if [[ " ${selected[*]} " == *' ruby '* || " ${selected[*]} " == *' rails '* ]]; then
    printf 'Ruby manager [1=asdf, 2=rbenv] (default 1): '
    read -r answer
    [[ $answer == 2 ]] && DF_RUBY_MANAGER=rbenv
  fi
  if [[ " ${selected[*]} " == *' node '* ]]; then
    printf 'Node.js manager [1=asdf, 2=nvm] (default 1): '
    read -r answer
    [[ $answer == 2 ]] && DF_NODE_MANAGER=nvm
  fi
  perform_install "${selected[@]}"
}

doctor() {
  local cmd version
  log "System: $DF_PRETTY | architecture: $(uname -m)"
  printf '%-16s | %s\n' 'Tool' 'Status / Version'
  printf '%s\n' '------------------------------------------'
  for cmd in git gcc make curl jq asdf rbenv ruby gem bundle rails node npm python3 rustc cargo psql mariadb podman flutter; do
    if command -v "$cmd" >/dev/null 2>&1; then
      case "$cmd" in
        git) version=$(git --version 2>/dev/null) ;;
        gcc) version=$(gcc -dumpversion 2>/dev/null) ;;
        node|ruby|python3|rustc|cargo|psql|mariadb|podman|flutter|rails|bundle|npm|asdf|rbenv) version=$($cmd --version 2>/dev/null | head -n 1 || true) ;;
        *) version=$(command -v "$cmd") ;;
      esac
      printf '%-16s | %s\n' "$cmd" "${version:-installed}"
    else
      printf '%-16s | %s\n' "$cmd" 'not found'
    fi
  done
  log 'Check versions and PATH in a new terminal after installing modules.'
}
