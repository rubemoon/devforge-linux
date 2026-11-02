#!/usr/bin/env bash
module_flutter() {
  install_module essentials
  pkg_install flutter
  [[ $(uname -m) == x86_64 ]] || die 'The Flutter installer currently supports Linux x86_64 only.'
  local target="$HOME/.local/share/devforge/flutter"
  add_profile_block 'flutter' 'export PATH="$HOME/.local/share/devforge/flutter/bin:$PATH"'
  export PATH="$target/bin:$PATH"
  if [[ -x "$target/bin/flutter" ]]; then
    log 'Flutter SDK is already installed. Update it manually with flutter upgrade, respecting project requirements.'
    return
  fi
  if [[ $DF_DRY_RUN == 1 ]]; then
    log '[DRY RUN] Resolve stable version, archive, and SHA256 from releases_linux.json'
    run tar -xJf /tmp/flutter-stable.tar.xz -C "$HOME/.local/share/devforge"
    return
  fi
  require_cmd jq
  local manifest hash archive checksum base version work
  manifest=$(curl --proto '=https' --tlsv1.2 -fsSL --retry 3 'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json') || die 'Could not query official Flutter releases.'
  hash=$(printf '%s' "$manifest" | jq -er '.current_release.stable')
  archive=$(printf '%s' "$manifest" | jq -er --arg h "$hash" '.releases[] | select(.hash==$h and .dart_sdk_arch=="x64") | .archive' | head -1)
  checksum=$(printf '%s' "$manifest" | jq -er --arg h "$hash" '.releases[] | select(.hash==$h and .dart_sdk_arch=="x64") | .sha256' | head -1)
  version=$(printf '%s' "$manifest" | jq -er --arg h "$hash" '.releases[] | select(.hash==$h and .dart_sdk_arch=="x64") | .version' | head -1)
  base=$(printf '%s' "$manifest" | jq -er '.base_url')
  [[ $archive == stable/linux/*.tar.xz ]] || die 'Unexpected Flutter archive path in release manifest.'
  [[ $base == 'https://storage.googleapis.com/flutter_infra_release/releases' ]] || die 'Unexpected Flutter release source.'
  log "Flutter stable: $version (large download; check available disk space)."
  work=$(mktemp -d)
  fetch "$base/$archive" "$work/flutter.tar.xz"
  verify_sha256 "$work/flutter.tar.xz" "$checksum"
  run mkdir -p "$HOME/.local/share/devforge"
  tar -xJf "$work/flutter.tar.xz" -C "$HOME/.local/share/devforge"
  rm -rf -- "$work"
  [[ -x "$target/bin/flutter" ]] || die 'Flutter SDK not found after extraction.'
  log 'Flutter SDK installed. Android Studio, Android SDK, and emulators require separate setup.'
  run "$target/bin/flutter" doctor
}
