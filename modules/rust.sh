#!/usr/bin/env bash
module_rust() {
  install_module essentials
  add_profile_block 'cargo' 'export PATH="$HOME/.cargo/bin:$PATH"'
  export PATH="$HOME/.cargo/bin:$PATH"
  if [[ -x $HOME/.cargo/bin/rustup ]] || command -v rustup >/dev/null 2>&1; then
    log 'rustup is already available.'
    if [[ $DF_DRY_RUN == 1 ]]; then run rustup update stable; else
      local existing_rustup="$HOME/.cargo/bin/rustup"
      [[ -x $existing_rustup ]] || existing_rustup=$(command -v rustup)
      "$existing_rustup" update stable || die 'Failed to update stable Rust.'
    fi
  elif [[ $DF_DRY_RUN == 1 ]]; then
    log '[DRY RUN] Download rustup-init over HTTPS and verify the official SHA256 checksum'
    run /tmp/rustup-init -y --no-modify-path --default-toolchain stable
  else
    local triple tempfile url hash
    case "$(uname -m)" in
      x86_64) triple='x86_64-unknown-linux-gnu' ;;
      aarch64) triple='aarch64-unknown-linux-gnu' ;;
      *) die 'Unsupported architecture for the rustup installer' ;;
    esac
    url="https://static.rust-lang.org/rustup/dist/$triple/rustup-init"
    tempfile=$(mktemp -d)
    fetch "$url" "$tempfile/rustup-init"
    fetch "$url.sha256" "$tempfile/rustup.sha256"
    hash=$(awk '{print $1}' "$tempfile/rustup.sha256")
    verify_sha256 "$tempfile/rustup-init" "$hash"
    chmod 700 "$tempfile/rustup-init"
    run "$tempfile/rustup-init" -y --no-modify-path --default-toolchain stable
    rm -rf -- "$tempfile"
  fi
  if [[ $DF_DRY_RUN == 1 ]]; then run rustup component add clippy rustfmt
  else
    local binary="$HOME/.cargo/bin/rustup"
    [[ -x $binary ]] || binary=$(command -v rustup)
    run "$binary" component add clippy rustfmt
  fi
}
