#!/usr/bin/env bash
# Packages are distro-specific; services are NOT automatically initialized or exposed.

packages_for() {
  local group="$1"; DF_PACKAGES=()
  case "$DF_FAMILY:$group" in
    fedora:essentials)
      DF_PACKAGES=(git curl wget ca-certificates jq unzip zip tar xz gzip gcc gcc-c++ make patch autoconf automake bison pkgconf-pkg-config bzip2-devel openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel gdbm-devel ncurses-devel sqlite-devel libuuid-devel) ;;
    debian:essentials)
      DF_PACKAGES=(git curl wget ca-certificates jq unzip zip tar xz-utils gzip build-essential patch autoconf automake bison pkg-config libbz2-dev libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libgdbm-dev libncurses-dev libsqlite3-dev uuid-dev) ;;
    arch:essentials)
      DF_PACKAGES=(base-devel git curl wget ca-certificates jq unzip zip tar xz gzip bzip2 openssl readline zlib libyaml libffi gdbm ncurses sqlite util-linux) ;;
    fedora:python) DF_PACKAGES=(bzip2-devel libffi-devel openssl-devel readline-devel sqlite-devel xz-devel tk-devel) ;;
    debian:python) DF_PACKAGES=(libbz2-dev libffi-dev libssl-dev libreadline-dev libsqlite3-dev liblzma-dev tk-dev) ;;
    arch:python) DF_PACKAGES=(bzip2 openssl readline sqlite xz tk) ;;
    fedora:dbclients) DF_PACKAGES=(postgresql mariadb) ;;
    debian:dbclients) DF_PACKAGES=(postgresql-client mariadb-client) ;;
    arch:dbclients) DF_PACKAGES=(postgresql mariadb-clients) ;;
    fedora:postgres) DF_PACKAGES=(postgresql-server postgresql) ;;
    debian:postgres) DF_PACKAGES=(postgresql postgresql-client) ;;
    arch:postgres) DF_PACKAGES=(postgresql) ;;
    fedora:mariadb) DF_PACKAGES=(mariadb-server mariadb) ;;
    debian:mariadb) DF_PACKAGES=(mariadb-server mariadb-client) ;;
    arch:mariadb) DF_PACKAGES=(mariadb) ;;
    fedora:podman|debian:podman|arch:podman) DF_PACKAGES=(podman) ;;
    fedora:flutter) DF_PACKAGES=(clang cmake ninja-build pkgconf-pkg-config gtk3-devel libstdc++-devel) ;;
    debian:flutter) DF_PACKAGES=(clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev) ;;
    arch:flutter) DF_PACKAGES=(clang cmake ninja pkgconf gtk3) ;;
    *) die "Unsupported package group: $DF_FAMILY/$group" ;;
  esac
}

pkg_install() {
  local group="$1"
  packages_for "$group"
  log "Pacotes [$DF_FAMILY/$group]: ${DF_PACKAGES[*]}"
  case "$DF_FAMILY" in
    fedora) run sudo dnf install -y "${DF_PACKAGES[@]}" ;;
    debian) run sudo apt-get update; run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${DF_PACKAGES[@]}" ;;
    arch) run sudo pacman -S --needed --noconfirm "${DF_PACKAGES[@]}" ;;
  esac
}
