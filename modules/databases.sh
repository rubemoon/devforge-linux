#!/usr/bin/env bash
module_dbclients() { pkg_install dbclients; }
module_postgres() {
  pkg_install postgres
  log 'PostgreSQL installed. The database is not initialized and the service is not started.'
  log 'On Fedora, initialize and start it manually when needed: sudo postgresql-setup --initdb && sudo systemctl enable --now postgresql.'
}
module_mariadb() {
  pkg_install mariadb
  log 'MariaDB (MySQL-compatible) installed. The service is not started automatically.'
  log 'Initialize it and start the service manually when needed.'
}
