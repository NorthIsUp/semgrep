# NorthIsUp Semgrep builds

`northisup` is the maintained branch; `develop` mirrors `semgrep/semgrep:develop`.
Every push to `northisup` builds Linux x86-64 and macOS arm64 wheels and core
runtime archives. GitHub Releases contain versioned assets and `SHA256SUMS`.
The package remains named `semgrep`; its local version identifies this fork and
source commit. Releases are published only after both platforms pass parser,
installation, and matching checks. Published assets are never replaced.

Install the wheel for your platform from
<https://github.com/NorthIsUp/semgrep/releases/latest> with `uv tool install URL`.
Linux wheels declare the actual build glibc requirement; macOS wheels contain
arm64 binaries. Core archives include their bundled library layout: extract
the whole archive, then run `semgrep/bin/semgrep-core` inside it.

## Maintenance

`Weekly upstream sync` runs Mondays at 08:23 UTC and supports manual dispatch.
It merges upstream into `northisup`, updates `develop`, and explicitly dispatches
the release workflow after a changed sync (GitHub suppresses push workflows for
commits made with `GITHUB_TOKEN`). Updates are atomic and never force-pushed.

`.fork/patches.json` records the original base/head of each downstream PR.
A patch retires only when its head is an upstream ancestor, its complete patch
matches an upstream commit, or the complete patch can be reversed from the
upstream tree. Closure of a public PR alone is insufficient. Git normally
merges equivalent imported changes automatically. Remaining conflicts may take
the upstream file only when the current file exactly matches a verified,
retired patch's version and that patch changed the file. Other conflicts stop
the workflow for human resolution; downstream edits are never guessed away.
Associated fork PRs close after verified retirement; upstream PR closure remains
with the upstream maintainers' import process.

Run `mise run fork:test` to exercise retirement and conflict safeguards in
isolated repositories. `mise run fork:sync` performs the real sync when checked
out on `northisup`. `FORK_VERSION=... mise run fork:package` builds and verifies
one platform's release assets; CI supplies the version automatically.
