#!/usr/bin/env bash
set -euo pipefail
: "${FORK_VERSION:?FORK_VERSION must identify this release}"
[[ "$FORK_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+northisup\.[0-9]+\.g[0-9a-f]+$ ]]
UV_PYTHON=$(command -v python)
export UV_PYTHON

# The core and Python wrapper must report the same downstream version.
for file in cli/pyproject.toml cli/src/semgrep/__init__.py src/core/Version.ml; do
  sed -E "s/^(version|__VERSION__|let version) = \"[^\"]+\"/\1 = \"$FORK_VERSION\"/" "$file" > "$file.fork-tmp"
  mv "$file.fork-tmp" "$file"
done
opam exec -- make core
opam exec -- make copy-core-for-cli
uv build --wheel --directory cli
mkdir -p release
uvx --from wheel==0.45.1 wheel tags --python-tag py3 --abi-tag none --remove cli/dist/*.whl
case $(uname -s) in
  Linux)
    # Retag for the actual build libc before auditwheel vendors dependencies.
    libc=$(getconf GNU_LIBC_VERSION | cut -d ' ' -f 2 | tr . _)
    uvx --from wheel==0.45.1 wheel tags --platform-tag "manylinux_${libc}_$(uname -m)" --remove cli/dist/*.whl
    uvx --from auditwheel==6.8.2 --with patchelf==0.17.2.4 auditwheel repair \
      --plat "manylinux_${libc}_$(uname -m)" --wheel-dir release cli/dist/*.whl
    ;;
  Darwin)
    uvx --from delocate==0.13.0 delocate-wheel --require-archs "$(uname -m)" -w release cli/dist/*.whl
    ;;
  *) echo 'Unsupported release platform' >&2; exit 1 ;;
esac
uvx --from twine==6.2.0 twine check release/*.whl
uv venv --clear --python "$UV_PYTHON" .fork-venv
uv pip install --python .fork-venv/bin/python release/*.whl
.fork-venv/bin/semgrep --version
.fork-venv/bin/semgrep scan --metrics=off --disable-version-check \
  --config tests/rules/fork_smoke.yaml tests/rules/fork_smoke.py --json > release/smoke-results.json
jq -e '(.errors | length) == 0 and
  (.results | map(.check_id | split(".") | last) | sort) ==
  ["fork-lazy", "fork-template", "fork-unpacking"]' release/smoke-results.json
bundle=$(mktemp -d)
trap 'rm -rf "$bundle"' EXIT
unzip -q release/*.whl -d "$bundle"
for libdir in "$bundle"/*.data/purelib "$bundle"/*.data/platlib; do
  if [[ -d "$libdir" ]]; then
    cp -R "$libdir/." "$bundle/"
  fi
done
rm -rf "$bundle"/*.data
chmod +x "$bundle/semgrep/bin/semgrep-core"
tar -C "$bundle" -czf "release/semgrep-core-$(uname -s)-$(uname -m)-${FORK_VERSION}.tar.gz" .
