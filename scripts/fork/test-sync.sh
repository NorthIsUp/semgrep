#!/usr/bin/env bash
set -euo pipefail
# The Docker hook lints this library separately without external-source mode.
# shellcheck source=/dev/null
source scripts/fork/sync-lib.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
cd "$scratch"
git init -q -b base
git config user.name 'Fork sync test'
git config user.email 'fork-test@example.invalid'
# Isolate tests from workstation hooks and signing; no production commits use this repo.
git config core.hooksPath /dev/null
git config commit.gpgsign false
printf 'base\n' > feature.txt
git add feature.txt
git commit -qm base
base=$(git rev-parse HEAD)
git switch -qc patch
printf 'feature\n' > feature.txt
git commit -qam feature
head=$(git rev-parse HEAD)
git switch -qc upstream "$base"
if patch_is_upstream "$base" "$head" HEAD "$scratch/patch.diff"; then
  echo 'FAIL: an unapplied patch was retired' >&2
  exit 1
fi
git cherry-pick "$head" >/dev/null
patch_is_upstream "$base" "$head" HEAD "$scratch/patch.diff"
echo 'PASS: equivalent upstream patches retire automatically'

git switch -qc squashed "$base"
printf 'feature\n' > feature.txt
printf 'unrelated\n' > upstream.txt
git add .
git commit -qm 'feature plus upstream changes'
patch_is_upstream "$base" "$head" HEAD "$scratch/patch.diff"
echo 'PASS: a patch bundled with other upstream changes is recognized'

# A verified retired patch may yield to later upstream edits to the same file.
printf 'new upstream implementation\n' > feature.txt
git commit -qam 'upstream implementation changed'
upstream=$(git rev-parse HEAD)
git switch -q patch
if git merge --no-commit "$upstream" >/dev/null 2>&1; then
  echo 'FAIL: test did not create a conflict' >&2
  exit 1
fi
jq -n --arg base "$base" --arg head "$head" \
  '[{base:$base, head:$head, status:"upstreamed"}]' > "$scratch/ledger.json"
resolve_retired_conflicts "$upstream" "$scratch/ledger.json"
[[ $(git show :feature.txt) == 'new upstream implementation' ]]
git merge --abort
echo 'PASS: verified retired patches automatically resolve to upstream'

printf 'local enhancement\n' > feature.txt
git commit -qam 'unretired downstream work'
if git merge --no-commit "$upstream" >/dev/null 2>&1; then
  echo 'FAIL: test did not create a conflict' >&2
  exit 1
fi
if resolve_retired_conflicts "$upstream" "$scratch/ledger.json"; then
  echo 'FAIL: downstream work was discarded' >&2
  exit 1
fi
git merge --abort
echo 'PASS: unresolved downstream changes are never discarded'
