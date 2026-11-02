#!/usr/bin/env bash

module_terminal() {
  local asset="$DF_ROOT/assets/pro-avatar.txt"
  local asset_ref profile
  [[ -r $asset ]] || die "ASCII logo asset not found: $asset"
  printf -v asset_ref '%q' "$asset"
  profile=$(cat <<'PROFILE'
if [[ $- == *i* && -t 1 ]]; then
  if [[ -z ${DEVFORGE_BRANDING_SHOWN:-} ]]; then
    if [[ -r __DEVFORGE_LOGO__ ]]; then
      if [[ -z ${NO_COLOR:-} ]]; then printf '\033[1;35m'; fi
      cat __DEVFORGE_LOGO__
      if [[ -z ${NO_COLOR:-} ]]; then printf '\033[0m'; fi
    fi
    printf '\n  DEVFORGE LINUX\n  POWERED BY KOZENETPRO\n\n'
    printf '\033]0;DevForge | KozenetPro\007'
    DEVFORGE_BRANDING_SHOWN=1
  fi
  if [[ -n ${BASH_VERSION:-} ]]; then
    if [[ -z ${NO_COLOR:-} ]]; then
      PS1='\\[\\e[1;36m\\]DEVFORGE\\[\\e[0m\\] \\[\\e[1;32m\\]\\u@\\h\\[\\e[0m\\]:\\[\\e[1;34m\\]\\w\\[\\e[0m\\] \\[\\e[1;33m\\]$(git branch --show-current 2>/dev/null)\\[\\e[0m\\]\\n\\[\\e[1;36m\\]>\\[\\e[0m\\] '
    else
      PS1='DEVFORGE \\u@\\h:\\w $(git branch --show-current 2>/dev/null)\\n> '
    fi
  elif [[ -n ${ZSH_VERSION:-} ]]; then
    setopt PROMPT_SUBST
    if [[ -z ${NO_COLOR:-} ]]; then
      PROMPT='%F{cyan}DEVFORGE%f %F{green}%n@%m%f:%F{blue}%~%f %F{yellow}$(git branch --show-current 2>/dev/null)%f\\n%F{cyan}>%f '
    else
      PROMPT='DEVFORGE %n@%m:%~ $(git branch --show-current 2>/dev/null)\\n> '
    fi
  fi
fi
PROFILE
)
  profile=${profile//__DEVFORGE_LOGO__/$asset_ref}
  add_profile_block 'terminal' "$profile"
  log 'Live DevForge prompt and Kozenet Pro branding enabled for interactive shells.'
}