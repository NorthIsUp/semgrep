# shellcheck shell=bash
# Retire patches only when Git can verify that their changes reached upstream.

require_clean_checkout() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo 'Upstream sync requires a clean checkout' >&2
    return 1
  fi
}

patch_is_upstream() {
  local base=$1 head=$2 upstream=$3 patch_file=$4 patch_id
  if git merge-base --is-ancestor "$head" "$upstream"; then
    return 0
  fi
  git diff --binary "$base" "$head" > "$patch_file"
  patch_id=$(git patch-id --stable < "$patch_file" | cut -d ' ' -f 1)
  if [[ -n "$patch_id" ]] && git log --no-merges -p "$base..$upstream" |
    git patch-id --stable | cut -d ' ' -f 1 | grep -Fx "$patch_id" >/dev/null; then
    return 0
  fi
  # A detached index checks the upstream tree without touching the checkout.
  local check_index
  check_index=$(mktemp)
  rm "$check_index"
  GIT_INDEX_FILE="$check_index" git read-tree "$upstream"
  local result=0
  GIT_INDEX_FILE="$check_index" git apply --cached --reverse --check "$patch_file" 2>/dev/null || result=$?
  rm -f "$check_index"
  return "$result"
}

resolve_retired_conflicts() {
  local upstream=$1 ledger=$2 path base head ours retired theirs resolved
  while IFS= read -r -d '' path; do
    resolved=false
    ours=$(git rev-parse --verify "HEAD:$path" 2>/dev/null || true)
    while IFS=$'\t' read -r base head; do
      if git diff --quiet "$base" "$head" -- "$path"; then
        continue
      fi
      retired=$(git rev-parse --verify "$head:$path" 2>/dev/null || true)
      if [[ -n "$ours" && "$ours" == "$retired" ]]; then
        theirs=$(git rev-parse --verify "$upstream:$path" 2>/dev/null || true)
        if [[ -n "$theirs" ]]; then
          git checkout "$upstream" -- "$path"
        else
          git rm -- "$path"
        fi
        resolved=true
        break
      fi
    done < <(jq -r '.[] | select(.status == "upstreamed") | [.base, .head] | @tsv' "$ledger")
    if [[ "$resolved" != true ]]; then
      printf 'Unresolved upstream conflict: %s\n' "$path" >&2
      return 1
    fi
  done < <(git diff --name-only --diff-filter=U -z)
}
