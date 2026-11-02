#!/usr/bin/env bash

setup_rbenv() {
  install_module essentials
  if [[ -d $HOME/.rvm ]] || command -v rvm >/dev/null 2>&1; then
    die 'RVM detected. Avoid mixing managers; disable RVM or use another installation.'
  fi
  if [[ ! -d $HOME/.rbenv/.git ]]; then
    run git clone --depth 1 https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
  else
    log 'rbenv already exists; leaving the local repository unchanged.'
  fi
  if [[ ! -d $HOME/.rbenv/plugins/ruby-build/.git ]]; then
    run mkdir -p "$HOME/.rbenv/plugins"
    run git clone --depth 1 https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
  fi
  add_profile_block 'rbenv' 'export PATH="$HOME/.rbenv/bin:$PATH"\neval "$(rbenv init -)"'
  export PATH="$HOME/.rbenv/bin:$PATH"
  if [[ $DF_DRY_RUN != 1 ]]; then eval "$("$HOME/.rbenv/bin/rbenv" init - bash)"; fi
}

module_ruby() {
  install_module essentials
  case "$DF_RUBY_MANAGER" in
    asdf)
      if command -v rbenv >/dev/null 2>&1 || command -v rvm >/dev/null 2>&1; then
        die 'Another Ruby manager is active. Avoid conflicts with asdf.'
      fi
      install_module asdf
      asdf_add_plugin ruby https://github.com/asdf-vm/asdf-ruby.git
      asdf_install_latest ruby "${DF_RUBY_VERSION:-}"
      ;;
    rbenv)
      if command -v asdf >/dev/null 2>&1 && [[ -f $HOME/.tool-versions ]] && grep -q '^ruby ' "$HOME/.tool-versions"; then
        die 'Ruby managed by asdf was detected. Do not mix managers for the same Ruby.'
      fi
      setup_rbenv
      if [[ $DF_DRY_RUN == 1 ]]; then
        log '[DRY RUN] Resolve the latest Ruby version with ruby-build'
        run rbenv install -s '<ruby-version>'
        run rbenv global '<ruby-version>'
      else
        local version
        if [[ -n ${DF_RUBY_VERSION:-} ]]; then version=$DF_RUBY_VERSION
        else
          # Stable definitions are shown by 'rbenv install -l'; select the highest Ruby semver.
          version=$("$HOME/.rbenv/bin/rbenv" install -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
        fi
        [[ -n $version ]] && valid_version "$version" || die 'Could not resolve a Ruby version for rbenv.'
        run "$HOME/.rbenv/bin/rbenv" install -s "$version"
        run "$HOME/.rbenv/bin/rbenv" global "$version"
        run "$HOME/.rbenv/bin/rbenv" rehash
      fi
      ;;
    *) die 'Option --ruby-manager must be asdf or rbenv.' ;;
  esac
  shell_reload_hint
}

module_rails() {
  install_module ruby
  if [[ $DF_DRY_RUN == 1 ]]; then
    run gem install bundler --no-document
    run gem install rails --no-document
    return
  fi
  require_cmd ruby
  require_cmd gem
  if ! gem list -i bundler >/dev/null 2>&1; then run gem install bundler --no-document; fi
  if ! gem list -i rails >/dev/null 2>&1; then
    run gem install rails --no-document
  else
    log 'Rails is installed. Run gem update rails when you want to update it.'
  fi
  if [[ $DF_RUBY_MANAGER == asdf ]]; then
    local bin; bin=$(asdf_bin)
    run "$bin" reshim ruby
  elif [[ $DF_RUBY_MANAGER == rbenv ]]; then
    run "$HOME/.rbenv/bin/rbenv" rehash
  fi
}
