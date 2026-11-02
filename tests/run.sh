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
for module in fullstack rails flutter node python rust postgres podman; do
  assert_contains "$output" "module: $module"
done
assert_contains "$output" 'Installation complete. Restart your terminal, then run devforge doctor.'
assert_not_exists "$scratch/home/.local"
printf 'PASS: Fedora full-stack preset dry run\n'

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
