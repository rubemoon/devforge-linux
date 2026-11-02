#!/usr/bin/env bash
DF_DISTRO=''
DF_FAMILY=''
DF_PRETTY=''

# Supports Fedora, Ubuntu/Debian and Arch/Manjaro; no guessing on unknown systems.
detect_distro() {
  local file="${DF_OS_RELEASE_FILE:-/etc/os-release}" id like
  [[ -r $file ]] || die 'Could not read /etc/os-release'
  id=$( ( . "$file"; printf '%s' "${ID:-}" ) )
  like=$( ( . "$file"; printf '%s' "${ID_LIKE:-}" ) )
  DF_PRETTY=$( ( . "$file"; printf '%s' "${PRETTY_NAME:-$id}" ) )
  DF_DISTRO=$id
  case " $id $like " in
    *fedora*|*rhel*) DF_FAMILY=fedora ;;
    *ubuntu*|*debian*) DF_FAMILY=debian ;;
    *arch*|*manjaro*) DF_FAMILY=arch ;;
    *) die "Unsupported distribution: $DF_PRETTY" ;;
  esac
}
