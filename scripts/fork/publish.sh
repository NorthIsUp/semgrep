#!/usr/bin/env bash
set -euo pipefail
: "${FORK_VERSION:?FORK_VERSION must identify this release}"
: "${GITHUB_SHA:?GITHUB_SHA must identify the source commit}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must identify the fork}"
tag="v${FORK_VERSION}"
cd release
sha256sum ./*.whl ./*.tar.gz > SHA256SUMS
printf '<!doctype html><title>NorthIsUp Semgrep wheels</title>\n' > index.html
for wheel in ./*.whl; do
  wheel=${wheel#./}
  digest=$(sha256sum "$wheel" | cut -d ' ' -f 1)
  printf '<a href="https://github.com/%s/releases/download/%s/%s#sha256=%s">%s</a>\n' \
    "$GITHUB_REPOSITORY" "${tag//+/%2B}" "${wheel//+/%2B}" "$digest" "$wheel" >> index.html
done
if draft=$(gh release view "$tag" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft 2>/dev/null); then
  if [[ "$draft" == false ]]; then
    echo "Release $tag is already published; preserving its assets."
    exit 0
  fi
else
  gh release create "$tag" --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" \
    --title "Semgrep ${FORK_VERSION}" --draft \
    --notes "NorthIsUp build from commit ${GITHUB_SHA}. Includes the active patches recorded in .fork/patches.json. Wheels and core runtime archives passed installation and parser smoke tests."
fi
gh release upload "$tag" --repo "$GITHUB_REPOSITORY" --clobber ./*.whl ./*.tar.gz SHA256SUMS index.html
branch_head=$(gh api "repos/$GITHUB_REPOSITORY/branches/northisup" --jq .commit.sha)
latest=false
[[ "$branch_head" != "$GITHUB_SHA" ]] || latest=true
gh release edit "$tag" --repo "$GITHUB_REPOSITORY" --draft=false --latest="$latest"
