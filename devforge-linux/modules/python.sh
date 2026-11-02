#!/usr/bin/env bash
module_python() {
  install_module essentials
  pkg_install python
  install_module asdf
  asdf_add_plugin python https://github.com/asdf-community/asdf-python.git
  asdf_install_latest python "${DF_PYTHON_VERSION:-}"
  log 'Use python -m venv .venv in each project.'
}
