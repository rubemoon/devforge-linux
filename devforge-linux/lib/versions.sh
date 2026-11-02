#!/usr/bin/env bash
# Version resolution at execution time. Existing project lockfiles are never edited.

asdf_bin() {
  if [[ -x $HOME/.local/bin/asdf ]]; then printf '%s' "$HOME/.local/bin/asdf"; else command -v asdf || return 1; fi
}

asdf_add_plugin() {
  local name="$1" url="$2" bin
  bin="$(asdf_bin)" || { [[ $DF_DRY_RUN == 1 ]] && bin="$HOME/.local/bin/asdf" || die 'asdf is not installed yet.'; }
  if [[ $DF_DRY_RUN == 1 ]]; then run "$bin" plugin add "$name" "$url"; return; fi
  if ! "$bin" plugin list | grep -Fxq "$name"; then run "$bin" plugin add "$name" "$url"; fi
  run "$bin" plugin update "$name"
}

asdf_install_latest() {
  local name="$1" version="${2:-}" bin
  bin="$(asdf_bin)" || { [[ $DF_DRY_RUN == 1 ]] && bin="$HOME/.local/bin/asdf" || die 'asdf not found.'; }
  if [[ $DF_DRY_RUN == 1 ]]; then
    log "[DRY RUN] Resolve stable $name version (${version:-latest})"
    run "$bin" install "$name" "${version:-latest}"
    run "$bin" set -u "$name" '<resolved-version>'
    return
  fi
  [[ -n $version ]] || version="$($bin latest "$name")"
  valid_version "$version" || die "Invalid version received for $name: $version"
  if ! "$bin" list "$name" | sed 's/^[[:space:]]*\*\?[[:space:]]*//' | grep -Fxq "$version"; then
    run "$bin" install "$name" "$version"
  else
    log "$name $version is already installed."
  fi
  run "$bin" set -u "$name" "$version"
  log "Selected $name version: $version"
}

# Fetch release metadata and SHA256 digest supplied by GitHub. No unverified binaries.
github_asset_info() {
  local repo="$1" asset="$2" release tag url digest
  require_cmd jq
  release="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 "https://api.github.com/repos/$repo/releases/latest")" || die "Could not query official release for $repo"
  tag=$(printf '%s' "$release" | jq -er '.tag_name') || die 'Release has no tag'
  url=$(printf '%s' "$release" | jq -er --arg name "$asset" '.assets[] | select(.name==$name) | .browser_download_url') || die "Asset not found: $asset"
  digest=$(printf '%s' "$release" | jq -er --arg name "$asset" '.assets[] | select(.name==$name) | .digest // empty') || die 'Release has no SHA256 digest; refusing unverified download'
  [[ $digest == sha256:* ]] || die "Digest is not SHA256: $digest"
  DF_ASSET_TAG="$tag"
  DF_ASSET_URL="$url"
  DF_ASSET_SHA256="${digest#sha256:}"
}
