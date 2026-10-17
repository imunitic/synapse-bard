#!/bin/bash
# Assembles the npm packages around the Ada release binaries of this
# machine's platform, installs them into a scratch prefix as a user would, and
# checks the installed program end to end: the `synapse-bard` and
# `synapse-bard-hook` shims find the binaries, `synapse-bard-setup configure`
# wires the hooks to the installed hook binary, and the binaries answer as
# they do in use.
#
#   ci/package.sh [--keep]
#
# Needs `ada/bin/synapse-bard` and `ada/bin/synapse-bard-hook` built with
# `just release` in `ada`. --keep leaves the scratch directory in place.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$PWD"
keep=0
[ "${1:-}" = "--keep" ] && keep=1

for tool in node npm jq git; do
    command -v "$tool" >/dev/null || { echo "$tool not on PATH" >&2; exit 1; }
done
for bin in synapse-bard synapse-bard-hook; do
    [ -x "ada/bin/$bin" ] || { echo "ada/bin/$bin missing -- run: just release (in ada)" >&2; exit 1; }
done

# On Linux, when a floor is named, the binaries must not ask for a newer glibc.
if [ -n "${GLIBC_FLOOR:-}" ] && [ "$(uname -s)" = Linux ]; then
    for b in synapse-bard synapse-bard-hook; do
        top="$(objdump -T "ada/bin/$b" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -Vu | tail -1)"
        [ "$(printf '%s\n%s\n' "$top" "$GLIBC_FLOOR" | sort -V | tail -1)" = "$GLIBC_FLOOR" ] \
            || { echo "FAIL: $b needs glibc $top, above $GLIBC_FLOOR" >&2; exit 1; }
    done
    echo "  glibc floor $GLIBC_FLOOR ok"
fi

plat="$(node -p 'process.platform + "-" + process.arch')"
[ -d "packages/synapse-bard/platforms/$plat" ] || { echo "no npm platform package for $plat" >&2; exit 1; }

work="$(mktemp -d)"
cleanup() { [ "$keep" = 1 ] && echo "kept $work" || rm -rf "$work"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# The packages, copied so the checkout is never written to.
cp -R packages/synapse-bard "$work/pkg"
mkdir -p "$work/pkg/platforms/$plat/bin"
cp ada/bin/synapse-bard ada/bin/synapse-bard-hook "$work/pkg/platforms/$plat/bin/"

mkdir -p "$work/tarballs" "$work/prefix"
(cd "$work/tarballs" && npm pack "$work/pkg/platforms/$plat" --silent >/dev/null && npm pack "$work/pkg" --silent >/dev/null)
ls "$work/tarballs" | sed 's/^/  packed /'

# Both in one install, so the main package's optional dependency on the
# platform package is satisfied by the tarball and not looked up on a registry.
(cd "$work/prefix" && npm init -y >/dev/null && npm install --silent --no-audit --no-fund "$work"/tarballs/*.tgz)

nm="$work/prefix/node_modules"
bin="$nm/.bin"
# A path as node's real path: /var is /private/var on macOS.
canon() { node -p "require('fs').realpathSync.native(process.argv[1])" "$1"; }
pkgbin="$(canon "$nm/@imunitic/synapse-bard-$plat/bin")"
[ -x "$pkgbin/synapse-bard" ] && [ -x "$pkgbin/synapse-bard-hook" ] || fail "the platform package holds no binaries"

# The shims resolve the binaries.
"$bin/synapse-bard" --help 2>&1 | grep -q "usage: synapse-bard" || fail "synapse-bard through the shim"
"$bin/synapse-bard-hook" --help 2>&1 | grep -q "usage: synapse-bard-hook" || fail "synapse-bard-hook through the shim"
echo "  shims ok"

# Configure each harness in a machine of its own.
home="$work/home"
mkdir -p "$home/.claude" "$home/.config"
export HOME="$home"
unset XDG_CONFIG_HOME CLAUDE_PLUGIN_ROOT SYNAPSE_BARD_CONTENT_ROOT
"$bin/synapse-bard-setup" configure claude >/dev/null || fail "synapse-bard-setup configure claude"
settings="$home/.claude/settings.json"
[ -f "$settings" ] || fail "no settings.json written"
for hook in session-start stop-nudge; do
    cmd="$(jq -r --arg h "$hook" '[.hooks[][].hooks[].command | select(endswith(" " + $h))] | first // empty' "$settings")"
    [ -n "$cmd" ] || fail "settings.json registers no '$hook' hook"
    [ "$(canon "${cmd%% *}")" = "$pkgbin/synapse-bard-hook" ] || fail "'$hook' runs ${cmd%% *}, not the installed hook binary"
done
content_root="$(jq -r '.env.SYNAPSE_BARD_CONTENT_ROOT // empty' "$settings")"
[ -f "$content_root/synapse-bard-claude.md" ] || fail "the content root named in settings.json holds no synapse-bard-claude.md"
ls "$home/.claude/skills" | grep -q "synapse-bard" || fail "no skills copied"
echo "  configure claude ok"

"$bin/synapse-bard-setup" configure codex >/dev/null || fail "synapse-bard-setup configure codex"
for b in $(jq -r '[.hooks[][].hooks[].command | split(" ")[0]] | unique | .[]' "$home/.codex/hooks.json"); do
    [ "$(canon "$b")" = "$pkgbin/synapse-bard-hook" ] || fail "codex hooks do not run the installed hook binary"
done
"$bin/synapse-bard-setup" configure opencode >/dev/null || fail "synapse-bard-setup configure opencode"
plugin_bin="$(grep -o '"[^"]*synapse-bard-hook[^"]*"' "$home/.config/opencode/plugin/synapse-bard.js" | head -1 | tr -d '"')"
[ -n "$plugin_bin" ] && [ "$(canon "$plugin_bin")" = "$pkgbin/synapse-bard-hook" ] || fail "the opencode plugin does not name the installed hook binary"
echo "  configure codex, opencode ok"

# The installed programs, run the way a harness runs them: a repository with a
# bible, the content root as settings.json names it.
repo="$work/repo"
mkdir -p "$repo/Characters/Main"
git -C "$repo" init -q
printf -- '---\ndef: [[Mara]]\n---\n# Mara\n' > "$repo/Characters/Main/Mara.md"
export SYNAPSE_BARD_CONTENT_ROOT="$content_root"
hook="$pkgbin/synapse-bard-hook"

out="$(cd "$repo" && printf '{"cwd":"%s"}' "$repo" | "$hook" session-start)" || fail "session-start exited non-zero"
[ -z "$out" ] || fail "session-start wrote output in a repository without _bard"

(cd "$repo" && "$pkgbin/synapse-bard" sync >/dev/null) || fail "synapse-bard sync exited non-zero"
[ -n "$(ls "$repo/_bard/graph" 2>/dev/null)" ] || fail "sync wrote no graph node"
(cd "$repo" && "$pkgbin/synapse-bard" sync --check >/dev/null) || fail "synapse-bard sync --check reports drift after a sync"

ctx="$(cd "$repo" && printf '{"cwd":"%s"}' "$repo" | "$hook" session-start)" || fail "session-start exited non-zero"
echo "$ctx" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null || fail "session-start gave no context"
echo "$ctx" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "vault index" || fail "session-start left out the vault index part"
printf '{"session_id":"x"}' | (cd "$repo" && "$hook" stop-nudge) >/dev/null || fail "stop-nudge exited non-zero"
"$hook" wat >/dev/null 2>&1 && fail "an unknown hook should not exit 0"
echo "  programs ok"

echo "package ok ($plat)"
