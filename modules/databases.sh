#!/usr/bin/env bash
module_dbclients() { pkg_install dbclients; }

postgres_cluster_state() {
  local data_dir="$1"
  if sudo test -s "$data_dir/PG_VERSION"; then
    printf 'initialized'
  elif sudo test -d "$data_dir" && sudo find "$data_dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    printf 'incomplete'
  else
    printf 'empty'
  fi
}

module_postgres() {
  install_module essentials
  pkg_install postgres
  local credentials_dir="$HOME/.config/devforge"
  local credentials_file="$credentials_dir/postgres.env"
  local password sql_file role_query data_dir cluster_state

  if [[ $DF_DRY_RUN == 1 ]]; then
    case "$DF_FAMILY" in
      fedora) data_dir=${DF_POSTGRES_DATA_DIR:-/var/lib/pgsql/data} ;;
      arch) data_dir=${DF_POSTGRES_DATA_DIR:-/var/lib/postgres/data} ;;
      *) data_dir='distribution default' ;;
    esac
    log "[DRY RUN] Check PostgreSQL cluster state at $data_dir before initialization."
    [[ $DF_FAMILY != fedora ]] || log '[DRY RUN] If the Fedora data directory is empty: sudo postgresql-setup --initdb.'
    [[ $DF_FAMILY != arch ]] || log '[DRY RUN] If the Arch data directory is empty: sudo -iu postgres initdb -D /var/lib/postgres/data.'
    run sudo systemctl enable --now postgresql
    log '[DRY RUN] Create or update PostgreSQL role devforge with CREATEDB privilege.'
    log "[DRY RUN] Store PostgreSQL credentials in $credentials_file with permissions 600."
    return
  fi

  case "$DF_FAMILY" in
    fedora)
      data_dir=${DF_POSTGRES_DATA_DIR:-/var/lib/pgsql/data}
      cluster_state=$(postgres_cluster_state "$data_dir")
      case "$cluster_state" in
        initialized) log "Existing PostgreSQL cluster detected at $data_dir." ;;
        empty) run sudo postgresql-setup --initdb ;;
        incomplete) die "PostgreSQL data directory $data_dir is not empty but has no PG_VERSION. Initialization stopped to protect existing files; inspect or back up this directory before retrying." ;;
      esac
      ;;
    arch)
      data_dir=${DF_POSTGRES_DATA_DIR:-/var/lib/postgres/data}
      cluster_state=$(postgres_cluster_state "$data_dir")
      case "$cluster_state" in
        initialized) log "Existing PostgreSQL cluster detected at $data_dir." ;;
        empty) run sudo -iu postgres initdb -D "$data_dir" ;;
        incomplete) die "PostgreSQL data directory $data_dir is not empty but has no PG_VERSION. Initialization stopped to protect existing files; inspect or back up this directory before retrying." ;;
      esac
      ;;
  esac
  run sudo systemctl enable --now postgresql

  run mkdir -p "$credentials_dir"
  run chmod 700 "$credentials_dir"
  if [[ -e $credentials_file || -L $credentials_file ]]; then
    [[ -f $credentials_file && ! -L $credentials_file ]] || die "Invalid credential file: $credentials_file"
    password=$(sed -n 's/^PGPASSWORD=//p' "$credentials_file")
    [[ $password =~ ^[0-9a-f]{64}$ ]] || die "Invalid password in $credentials_file"
    run chmod 600 "$credentials_file"
  else
    require_cmd openssl
    password=$(openssl rand -hex 32) || die 'Could not generate a PostgreSQL password.'
  fi

  sql_file=$(mktemp)
  role_query="SELECT format(CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'devforge') THEN 'ALTER ROLE devforge WITH LOGIN CREATEDB PASSWORD %L' ELSE 'CREATE ROLE devforge WITH LOGIN CREATEDB PASSWORD %L' END, '$password')"
  printf '%s\n\\gexec\n' "$role_query" > "$sql_file"
  if ! sudo -u postgres psql --set=ON_ERROR_STOP=1 < "$sql_file" >/dev/null; then
    rm -f -- "$sql_file"
    die 'Could not create or update the PostgreSQL devforge role.'
  fi
  rm -f -- "$sql_file"

  if [[ ! -e $credentials_file ]]; then
    (umask 077; printf 'PGHOST=127.0.0.1\nPGPORT=5432\nPGUSER=devforge\nPGPASSWORD=%s\n' "$password" > "$credentials_file")
    run chmod 600 "$credentials_file"
  fi
  log "PostgreSQL is running. The devforge role can create project databases; credentials are stored in $credentials_file."
}
module_mariadb() {
  pkg_install mariadb
  log 'MariaDB (MySQL-compatible) installed. The service is not started automatically.'
  log 'Initialize it and start the service manually when needed.'
}
