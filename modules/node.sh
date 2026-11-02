#!/usr/bin/env bash
module_node() {
  install_module essentials
  case "$DF_NODE_MANAGER" in
    asdf)
      install_module asdf
      asdf_add_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git
      if [[ $DF_DRY_RUN == 1 ]]; then
        log '[DRY RUN] Resolve the latest Node.js LTS version'
        asdf_install_latest nodejs '<LTS>'
      else
        local bin version
        bin=$(asdf_bin)
        run "$bin" cmd nodejs update-nodebuild
        version=${DF_NODE_VERSION:-$("$bin" cmd nodejs resolve lts --latest-available)}
        valid_version "$version" || die "Invalid Node.js LTS version: $version"
        asdf_install_latest nodejs "$version"
      fi
      ;;
    nvm)
      if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
        log 'nvm is already installed.'
      else
        if [[ $DF_DRY_RUN == 1 ]]; then
          log '[DRY RUN] Resolve the latest stable nvm release tag'
          run git clone --depth 1 --branch '<release-tag>' https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
        else
          local tag
          tag=$(git ls-remote --refs --tags https://github.com/nvm-sh/nvm.git 'v*' | sed -n 's@.*refs/tags/\(v[0-9][0-9.]*\)$@\1@p' | sort -V | tail -1)
          [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Could not find a stable nvm release.'
          run git clone --depth 1 --branch "$tag" https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
        fi
      fi
      add_profile_block 'nvm' 'export NVM_DIR="$HOME/.nvm"\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
      if [[ $DF_DRY_RUN == 1 ]]; then run nvm install --lts; return; fi
      export NVM_DIR="$HOME/.nvm"
      # nvm's own installer supports Bash; sourcing requires relaxing nounset.
      set +u
      # shellcheck source=/dev/null
      . "$NVM_DIR/nvm.sh"
      set -u
      if [[ -n ${DF_NODE_VERSION:-} ]]; then run nvm install "$DF_NODE_VERSION"; run nvm alias default "$DF_NODE_VERSION"
      else run nvm install --lts; run nvm alias default 'lts/*'; fi
      ;;
    *) die 'Option --node-manager must be asdf or nvm.' ;;
  esac
  shell_reload_hint
}
