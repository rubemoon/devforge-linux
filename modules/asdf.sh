#!/usr/bin/env bash
module_asdf() {
  install_module essentials
  add_user_bin_path
  local arch asset temp bin tag
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    i?86) arch=386 ;;
    *) die "Unsupported asdf architecture: $arch" ;;
  esac
  bin="$HOME/.local/bin/asdf"
  if [[ -x "$bin" ]] || command -v asdf >/dev/null 2>&1; then
    log 'asdf is already available; no binary installation needed.'
  elif [[ $DF_DRY_RUN == 1 ]]; then
    log '[DRY RUN] Query the latest asdf release and official GitHub SHA256 checksum'
    run install -m 755 /tmp/asdf-bin "$bin"
  else
    # Release asset contains a standalone binary since asdf >=0.16.
    tag=$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 https://api.github.com/repos/asdf-vm/asdf/releases/latest | jq -er '.tag_name') || die 'Could not resolve the asdf release'
    asset="asdf-${tag}-linux-${arch}.tar.gz"
    github_asset_info 'asdf-vm/asdf' "$asset"
    temp=$(mktemp -d)
    fetch "$DF_ASSET_URL" "$temp/$asset"
    verify_sha256 "$temp/$asset" "$DF_ASSET_SHA256"
    tar -xzf "$temp/$asset" -C "$temp"
    [[ -f $temp/asdf ]] || die 'asdf binary not found in the verified archive'
    run install -m 0755 "$temp/asdf" "$bin"
    rm -rf -- "$temp"
  fi
  add_profile_block 'asdf' 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"'
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
  log 'asdf is ready; plugins and runtimes will be installed for the selected modules.'
}
