#!/usr/bin/env bash
# Shared functions. Sourced by bin/devforge; never execute directly.

DF_VERSION='1.0.0'
DF_DRY_RUN=${DF_DRY_RUN:-0}
DF_YES=${DF_YES:-0}
DF_POLICY=${DF_POLICY:-latest}
DF_RUBY_MANAGER=${DF_RUBY_MANAGER:-asdf}
DF_NODE_MANAGER=${DF_NODE_MANAGER:-asdf}
DF_LOG_DIR=${DF_LOG_DIR:-"${XDG_STATE_HOME:-$HOME/.local/state}/devforge"}
DF_LOG_FILE=''

color() { if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then printf '\033[%sm' "$1"; fi; }
log()  { printf '%s[DevForge]%s %s\n' "$(color 36)" "$(color 0)" "$*"; [[ -z $DF_LOG_FILE ]] || printf '[INFO] %s\n' "$*" >> "$DF_LOG_FILE"; }
warn() { printf '%s[WARN]%s %s\n' "$(color 33)" "$(color 0)" "$*" >&2; [[ -z $DF_LOG_FILE ]] || printf '[WARN] %s\n' "$*" >> "$DF_LOG_FILE"; }
die()  { printf '%s[ERROR]%s %s\n' "$(color 31)" "$(color 0)" "$*" >&2; exit 1; }

init_log() {
  if [[ $DF_DRY_RUN == 1 ]]; then return 0; fi
  mkdir -p "$DF_LOG_DIR"
  chmod 700 "$DF_LOG_DIR"
  DF_LOG_FILE="$DF_LOG_DIR/$(date +%Y%m%d-%H%M%S)-$$.log"
  (umask 077; : > "$DF_LOG_FILE")
}

run() {
  if [[ $DF_DRY_RUN == 1 ]]; then
    printf '[DRY RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

confirm() {
  local answer
  [[ $DF_YES == 1 ]] && return 0
  [[ $DF_DRY_RUN == 1 ]] && return 0
  if [[ ! -t 0 ]]; then die 'No interactive terminal: review --dry-run, then use --yes.'; fi
  read -r -p "${1:-Continue?} [y/N] " answer
  [[ $answer =~ ^([yY]|[yY][eE][sS])$ ]]
}

require_unprivileged() {
  if (( EUID == 0 )); then die 'Do not run DevForge with sudo. It requests sudo only for system packages.'; fi
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

add_profile_block() {
  local label="$1" content="$2" file start end body_file temp
  start="# >>> devforge:${label} >>>"
  end="# <<< devforge:${label} <<<"
  for file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -L $file ]]; then
      file="$(readlink -f -- "$file")" || die "Could not resolve shell config symlink: $file"
    fi
    if [[ -f "$file" ]] && grep -Fqx "$start" "$file"; then
      if [[ $DF_DRY_RUN == 1 ]]; then
        log "[DRY RUN] Update $label configuration in $file"
        continue
      fi
      body_file=$(mktemp "${file}.devforge.body.XXXXXX") || die "Could not create temporary file for $file"
      printf '%b\n' "$content" > "$body_file"
      temp=$(mktemp "${file}.devforge.XXXXXX") || die "Could not create temporary file for $file"
      if ! awk -v start="$start" -v end="$end" -v body_file="$body_file" '
        $0 == start {
          if (!updated) {
            print
            while ((getline body_line < body_file) > 0) print body_line
            close(body_file)
            updated=1
            block=1
          }
          else { block=2 }
          next
        }
        $0 == end && block { if (block == 1) print; block=0; next }
        !block { print }
        END { if (block || !updated) exit 1 }
      ' "$file" > "$temp"; then
        rm -f -- "$body_file"
        rm -f -- "$temp"
        die "Could not update $label configuration in $file"
      fi
      rm -f -- "$body_file"
      chmod --reference="$file" "$temp"
      mv -f -- "$temp" "$file"
      log "$label configuration updated in $file"
      continue
    fi
    if [[ $DF_DRY_RUN == 1 ]]; then
      log "[DRY RUN] Add $label configuration to $file"
    else
      touch "$file"
      printf '\n%s\n%b\n%s\n' "$start" "$content" "$end" >> "$file"
      log "$label configuration added to $file"
    fi
  done
}

add_user_bin_path() {
  mkdir_user_bin
  export PATH="$HOME/.local/bin:$PATH"
  add_profile_block 'local-bin' 'export PATH="$HOME/.local/bin:$PATH"'
}

mkdir_user_bin() { run mkdir -p "$HOME/.local/bin"; }

fetch() {
  local url="$1" dest="$2"
  run curl --proto '=https' --tlsv1.2 -fL --retry 3 --connect-timeout 15 -o "$dest" "$url"
}

verify_sha256() {
  local file="$1" expected="$2" actual
  [[ $expected =~ ^[0-9a-fA-F]{64}$ ]] || die 'SHA256 checksum unavailable or invalid; installation stopped.'
  if [[ $DF_DRY_RUN == 1 ]]; then log "[DRY RUN] Verificar SHA256: $file"; return; fi
  actual="$(sha256sum "$file")"
  actual="${actual%% *}"
  [[ ${actual,,} == ${expected,,} ]] || die "SHA256 checksum mismatch for $file"
}

# Version must be a plain release number, never arbitrary shell fragments.
valid_version() { [[ $1 =~ ^[0-9]+(\.[0-9]+){1,3}([.-][a-zA-Z0-9]+)?$ ]]; }

shell_reload_hint() { log 'Open a new terminal after installation to reload PATH.'; }
