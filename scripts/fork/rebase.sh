#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source scripts/fork/sync-lib.sh

[[ $(git branch --show-current) == northisup ]] || { echo 'Run rebase on northisup' >&2; exit 1; }
require_clean_checkout

git fetch --no-tags origin northisup:refs/remotes/origin/northisup
git fetch --no-tags https://github.com/semgrep/semgrep.git develop:refs/remotes/semgrep/develop
upstream=refs/remotes/semgrep/develop
before=$(git rev-parse refs/remotes/origin/northisup)
base=$(git merge-base "$before" "$upstream")
git rebase --rebase-merges --onto "$upstream" "$base" northisup

after=$(git rev-parse HEAD)
if [[ "$before" != "$after" ]]; then
  # Guard against rewriting a branch updated since fetch. This branch is
  # intentionally rebased onto upstream, so a lease-protected force update is
  # required; concurrent changes fail safely instead of being overwritten.
  git push --force-with-lease="refs/heads/northisup:$before" origin northisup:northisup
fi
# Keep the public develop mirror current without rewriting it.
git push origin "$upstream:refs/heads/develop"

if [[ "$before" != "$after" ]]; then
  gh workflow run fork-release.yml --repo NorthIsUp/semgrep --ref northisup
fi
