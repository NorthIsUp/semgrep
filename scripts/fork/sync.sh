#!/usr/bin/env bash
set -euo pipefail
source scripts/fork/sync-lib.sh

[[ $(git branch --show-current) == northisup ]] || { echo 'Run sync on northisup' >&2; exit 1; }
git diff --quiet && git diff --cached --quiet
git fetch --no-tags https://github.com/semgrep/semgrep.git develop:refs/remotes/semgrep/develop
upstream=refs/remotes/semgrep/develop
before=$(git rev-parse HEAD)
ledger=$(mktemp)
patch_file=$(mktemp)
trap 'rm -f "$ledger" "$patch_file"' EXIT
cp .fork/patches.json "$ledger"
while IFS=$'\t' read -r number base head; do
  if patch_is_upstream "$base" "$head" "$upstream" "$patch_file"; then
    jq --argjson number "$number" \
      'map(if .upstream_pr == $number then .status = "upstreamed" else . end)' \
      "$ledger" > "$ledger.next"
    mv "$ledger.next" "$ledger"
    printf 'Verified upstream PR #%s is present in upstream develop\n' "$number"
  fi
done < <(jq -r '.[] | select(.status == "active") | [.upstream_pr, .base, .head] | @tsv' "$ledger")

if ! git merge --no-commit --no-ff "$upstream"; then
  resolve_retired_conflicts "$upstream" "$ledger"
fi
cp "$ledger" .fork/patches.json
git add .fork/patches.json
if git rev-parse -q --verify MERGE_HEAD >/dev/null || ! git diff --cached --quiet; then
  git commit -m 'chore: sync upstream develop and retire integrated patches'
fi
# No forced updates: a concurrent human push makes this fail safely.
git push --atomic origin HEAD:northisup "$upstream:refs/heads/develop"
if [[ "$before" != $(git rev-parse HEAD) ]]; then
  gh workflow run fork-release.yml --repo NorthIsUp/semgrep --ref northisup
fi
while IFS=$'\t' read -r number fork_pr; do
  if [[ $(gh pr view "$fork_pr" --repo NorthIsUp/semgrep --json state --jq .state) == OPEN ]]; then
    gh pr close "$fork_pr" --repo NorthIsUp/semgrep \
      --comment "Verified upstream PR #$number is present in upstream develop; retiring the fork patch."
  fi
done < <(jq -r '.[] | select(.status == "upstreamed" and .fork_pr != null) | [.upstream_pr, .fork_pr] | @tsv' .fork/patches.json)
