# synapse-bard

[![tests](https://github.com/imunitic/synapse-bard/actions/workflows/tests.yml/badge.svg)](https://github.com/imunitic/synapse-bard/actions/workflows/tests.yml)

Repo-local memory for a fiction bible: a durable markdown vault plus a story graph, for Claude
Code, Codex CLI, and OpenCode. Two stores, both repo-local (no external vault location, no network
dependency to use either): the **Bible-graph** (`_bard/graph/`), a structured index over a
YAML-templated character/place/faction/item bible, kept in sync with the bible's own source tree by
`synapse-bard sync`; and the **Writer's notes vault** (`_bard/vault/`), free-form durable notes —
decisions, continuity, research — that outlive any one session. See
[`docs/synapse-bard/`](docs/synapse-bard/) for the full picture: `bard-graph.md`, `bard-vault.md`,
`cli.md` (generated CLI reference), and `bard-config.md`.

## Install

```sh
npm install -g @imunitic/synapse-bard
synapse-bard-setup configure claude       # or: codex / opencode
```

`npm install` alone already puts the right compiled binaries (`synapse-bard`, `synapse-bard-hook`)
on disk — `@imunitic/synapse-bard` depends on a per-platform package
(`@imunitic/synapse-bard-darwin-arm64` etc.) that npm resolves automatically for the machine it's
running on, so there's nothing to fetch or build afterward. `synapse-bard-setup configure <harness>`
wires up the hooks/commands/skills for that harness; run it once per harness you use.

> To run from a checkout instead of the published package (for contributing, or to test an
> unreleased change):
> ```sh
> git clone https://github.com/imunitic/synapse-bard
> cd synapse-bard/packages/synapse-bard
> node bin/synapse-bard-setup.cjs configure claude   # or: codex / opencode
> ```
> This needs the platform binaries built locally first (`zig build`, or `just build`) and copied
> into `platforms/{platform}-{arch}/bin/` — see [Develop](#develop) below.

## Develop

```sh
brew install zig just         # if not already installed
just build                    # compile synapse-bard / synapse-bard-hook
just test                     # zig build test
just build-targets            # cross-compile all three release targets
just docs-check               # verify cli.md and rendered diagrams match their sources
just fix                      # regenerate cli.md and diagrams after a change upstream of them
just check                    # the full gate -- before pushing
```

The `synapse` dependency in `build.zig.zon` is a `git+hash` pin to a tagged
[imunitic/synapse](https://github.com/imunitic/synapse) release, resolved automatically by `zig
build` the first time it's needed (cached afterward under `~/.cache/zig/p`). Bumping it to a newer
synapse release is a deliberate `zig fetch --save=synapse <tag-url>` against a real tag, never an
arbitrary commit. This build never links `treesitter` — `synapse-bard` parses YAML frontmatter
only, so the whole build needs no libtree-sitter and no C compiler.

A tagged `vX.Y.Z` push runs [`release.yml`](.github/workflows/release.yml): cross-compiles the
release targets and publishes the four `@imunitic/synapse-bard*` npm packages in lock-step via
OIDC trusted publishing — no local `npm publish` needed.

## License

MIT — see [LICENSE](LICENSE).
