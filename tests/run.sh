#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
assert_contains() { [[ $1 == *"$2"* ]] || { printf 'FAIL: expected %q in output\n%s\n' "$2" "$1" >&2; exit 1; }; }
assert_not_exists() { [[ ! -e $1 ]] || { echo "FAIL: file unexpectedly created: $1" >&2; exit 1; }; }

for f in "$ROOT"/bin/devforge "$ROOT"/install.sh "$ROOT"/lib/*.sh "$ROOT"/modules/*.sh; do
  bash -n "$f" || exit 1
done
printf 'PASS: Bash syntax\n'

output=$("$ROOT/bin/devforge" --version)
assert_contains "$output" '1.0.0'
printf 'PASS: version\n'
output=$("$ROOT/bin/devforge" --help)
assert_contains "$output" 'dry-run'
printf 'PASS: help\n'
output=$("$ROOT/bin/devforge" list)
assert_contains "$output" 'fullstack'
assert_contains "$output" 'terminal'
assert_contains "$output" 'flutter'
printf 'PASS: module list\n'

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/home"
ln -s "$ROOT/bin/devforge" "$scratch/devforge"
output=$("$scratch/devforge" --version)
assert_contains "$output" '1.0.0'
printf 'PASS: symlink launcher\n'

cat > "$scratch/fedora-release" <<'REL'
ID=fedora
PRETTY_NAME="Fedora Linux 44"
REL
cat > "$scratch/ubuntu-release" <<'REL'
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu Linux"
REL
cat > "$scratch/arch-release" <<'REL'
ID=manjaro
ID_LIKE=arch
PRETTY_NAME="Manjaro Linux"
REL

for item in fedora ubuntu arch; do
  release="$scratch/$item-release"
  output=$(HOME="$scratch/home" DF_OS_RELEASE_FILE="$release" "$ROOT/bin/devforge" install essentials,ruby,rails,node,python,rust,dbclients,postgres,mariadb,podman,flutter --dry-run --yes)
  assert_contains "$output" 'DRY RUN'
  assert_contains "$output" 'module: flutter'
  assert_not_exists "$scratch/home/.local"
  printf 'PASS: no-change dry run [%s]\n' "$item"
done

output=$(HOME="$scratch/home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install fullstack --dry-run --yes)
for module in fullstack rails flutter node python rust postgres podman terminal; do
  assert_contains "$output" "module: $module"
done
assert_contains "$output" 'POWERED BY KOZENETPRO'
assert_contains "$output" '[STEP 01] fullstack'
assert_contains "$output" '[ DONE ] terminal'
assert_contains "$output" 'Installation complete. Restart your terminal, then run devforge doctor.'
assert_not_exists "$scratch/home/.local"
assert_not_exists "$scratch/home/.config"
assert_not_exists "$scratch/home/.bashrc"
printf 'PASS: Fedora full-stack preset dry run\n'

profile_home="$scratch/profile-home"
mkdir -p "$profile_home"
cat > "$profile_home/.bashrc" <<'PROFILE'
before-devforge
# >>> devforge:terminal >>>
old copied logo and prompt
# <<< devforge:terminal <<<
after-devforge
PROFILE
HOME="$profile_home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install terminal --yes > "$scratch/terminal.out"
profile_contents=$(<"$profile_home/.bashrc")
assert_contains "$profile_contents" 'before-devforge'
assert_contains "$profile_contents" 'after-devforge'
assert_contains "$profile_contents" 'git branch --show-current'
assert_contains "$profile_contents" "PS1='\\[\\e[1;36m\\]DEVFORGE"
[[ $(grep -Fc '# >>> devforge:terminal >>>' "$profile_home/.bashrc") == 1 ]]
assert_not_exists "$profile_home/.config/devforge/pro-avatar.txt"
printf 'PASS: live terminal theme update\n'

output=$(HOME="$scratch/home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install postgres --dry-run --yes)
assert_contains "$output" 'Check PostgreSQL cluster state'
assert_contains "$output" 'sudo postgresql-setup --initdb'
assert_contains "$output" 'systemctl enable --now postgresql'
assert_contains "$output" 'PostgreSQL role devforge with CREATEDB privilege'
assert_contains "$output" "$scratch/home/.config/devforge/postgres.env"
assert_not_exists "$scratch/home/.config"
printf 'PASS: PostgreSQL role dry run\n'

fake_bin="$scratch/fake-bin"
partial_data="$scratch/partial-postgres-data"
initialized_data="$scratch/initialized-postgres-data"
mkdir -p "$fake_bin" "$partial_data"
mkdir -p "$initialized_data"
printf 'partial data\n' > "$partial_data/postmaster.opts"
printf '18\n' > "$initialized_data/PG_VERSION"
cat > "$fake_bin/sudo" <<'SUDO'
#!/usr/bin/env bash
case "$1" in
  test) shift; test "$@" ;;
  find) shift; exec find "$@" ;;
  *) exit 0 ;;
esac
SUDO
chmod +x "$fake_bin/sudo"
source "$ROOT/modules/databases.sh"
cluster_state=$(PATH="$fake_bin:$PATH" postgres_cluster_state "$initialized_data")
[[ $cluster_state == initialized ]] || { echo "FAIL: initialized PostgreSQL cluster reported as $cluster_state" >&2; exit 1; }
printf 'PASS: recognizes initialized PostgreSQL cluster\n'
if PATH="$fake_bin:$PATH" HOME="$scratch/home" DF_POSTGRES_DATA_DIR="$partial_data" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install postgres --yes > "$scratch/postgres-partial.out" 2>&1; then
  echo 'FAIL: incomplete PostgreSQL cluster accepted' >&2; exit 1
fi
assert_contains "$(<"$scratch/postgres-partial.out")" 'not empty but has no PG_VERSION'
[[ -f $partial_data/postmaster.opts ]]
printf 'PASS: protects incomplete PostgreSQL data directory\n'

output=$(HOME="$scratch/home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install ruby,node --ruby-manager rbenv --node-manager nvm --dry-run --yes)
assert_contains "$output" 'rbenv install'
assert_contains "$output" 'nvm install'
assert_not_exists "$scratch/home/.rbenv"
printf 'PASS: rbenv and nvm dry run\n'

if HOME="$scratch/home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install unknown --dry-run --yes > "$scratch/out" 2>&1; then
  echo 'FAIL: unknown module accepted' >&2; exit 1
fi
printf 'PASS: rejects unknown modules\n'
if HOME="$scratch/home" DF_OS_RELEASE_FILE="$scratch/fedora-release" "$ROOT/bin/devforge" install ruby --ruby-version '3.0;rm -rf /' --dry-run --yes > "$scratch/out" 2>&1; then
  echo 'FAIL: invalid version accepted' >&2; exit 1
fi
printf 'PASS: rejects invalid versions\n'

printf '\nAll tests passed.\n'
