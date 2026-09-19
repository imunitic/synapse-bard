# Task runner for this repo. The recipes here mirror .github/workflows/tests.yml
# deliberately: "green locally" and "green in CI" must mean the same thing.
#
#   just              list the recipes
#   just check        the full gate -- before pushing
#   just fix          regenerate whatever `check` verifies

set shell := ["bash", "-uc"]

_default:
    @just --list --unsorted

# Compile the Zig binaries.
build:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v zig >/dev/null || { echo "zig not on PATH -- brew install zig" >&2; exit 1; }
    zig build
    echo "zig build ok: zig-out/bin/synapse-bard"

# Zig unit tests.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v zig >/dev/null || { echo "zig not on PATH -- brew install zig" >&2; exit 1; }
    zig build test --summary all

# A POSIX path assumption or a shell-out is a portability bug that only
# surfaces on the platform that lacks the thing. Compiling all three release
# targets here moves that to the moment the line is written.

# Compile for all three release targets.
build-targets:
    #!/usr/bin/env bash
    set -euo pipefail
    source ci/release-targets.sh
    for t in "${targets[@]}"; do
        zig build -Dtarget="$t" -p "/tmp/synapse-bard-build-targets/$t"
    done
    echo "build-targets ok: ${targets[*]}"

# Verify, never regenerate: a `check` that quietly fixes what it is checking
# cannot fail, and the point is to catch a script edit committed without the
# regeneration that follows from it.

# Verify the generated cli.md and rendered diagrams match their sources.
docs-check:
    ./docs/synapse-bard/generate-cli-reference.sh --check
    ./docs/synapse-bard/generate-diagrams.sh --check

# Regenerate all generated artefacts; diagrams need mermaid-cli and its Chromium.
fix:
    ./docs/synapse-bard/generate-cli-reference.sh
    ./docs/synapse-bard/generate-diagrams.sh

# The full gate -- run before pushing.
check: build build-targets test docs-check
    @echo "all green"

# Show what changed against the pushed branch.
diff:
    @git --no-pager diff --stat @{u}.. 2>/dev/null || git --no-pager diff --stat
