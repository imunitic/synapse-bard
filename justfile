# Task runner for this repo. The recipes mirror .github/workflows/ada.yml
# deliberately: "green locally" and "green in CI" must mean the same thing.
#
#   just              list the recipes
#   just check        the full gate -- before pushing
#   just fix          regenerate whatever `check` verifies

set shell := ["bash", "-uc"]

_default:
    @just --list --unsorted

# Alire builds a dependency in the release profile whatever the root's
# profile; the validation profile makes the library's contracts run too.
profile := "--profiles='*=validation'"

# Build the executables.
build:
    alr -n build {{profile}}

# Build and run the AUnit suite.
test:
    cd tests/unit && alr -n build {{profile}} && ./bin/synapse_bard_tests

# Run the built program in scratch repositories and check what it writes.
acceptance: build
    cd tests/acceptance && alr -n build {{profile}} && ./bin/synapse_bard_acceptance "$(cd ../.. && pwd)/bin/synapse-bard"

# Build the release binaries.
release:
    alr -n build --profiles='*=release' -- -m

# Verify, never regenerate: a `check` that quietly fixes what it is checking
# cannot fail, and the point is to catch a source edit committed without the
# regeneration that follows from it.

# Verify the generated cli.md and rendered diagrams match their sources.
docs-check: build
    ./docs/synapse-bard/generate-cli-reference.sh --check
    ./docs/synapse-bard/generate-diagrams.sh --check

# Regenerate all generated artefacts; diagrams need mermaid-cli and its Chromium.
fix: build
    ./docs/synapse-bard/generate-cli-reference.sh
    ./docs/synapse-bard/generate-diagrams.sh

# Pack the release binaries as npm packages, install them into a scratch prefix and check the installed program.
package: release
    ci/package.sh

# Build the Linux release binaries in a container against a glibc 2.28 sysroot.
linux-release:
    ci/linux-release.sh

# The full gate -- run before pushing.
check: build test acceptance docs-check package
    @echo "all green"

# Show what changed against the pushed branch.
diff:
    @git --no-pager diff --stat @{u}.. 2>/dev/null || git --no-pager diff --stat
