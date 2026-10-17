# synapse-bard

[![ada](https://github.com/imunitic/synapse-bard/actions/workflows/ada.yml/badge.svg)](https://github.com/imunitic/synapse-bard/actions/workflows/ada.yml)

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
> cd synapse-bard
> just release                                       # builds bin/synapse-bard and bin/synapse-bard-hook
> mkdir -p packages/synapse-bard/platforms/$(node -p 'process.platform + "-" + process.arch')/bin
> cp bin/synapse-bard bin/synapse-bard-hook packages/synapse-bard/platforms/$(node -p 'process.platform + "-" + process.arch')/bin/
> cd packages/synapse-bard
> node bin/synapse-bard-setup.cjs configure claude   # or: codex / opencode
> ```

## Develop

Ada 2022, built with [Alire](https://alire.ada.dev); the toolchain (`gnat_native`, `gprbuild`) comes
with it on first use.

```sh
brew install alire just       # if not already installed
just build                    # compile synapse-bard / synapse-bard-hook (validation profile)
just test                     # the AUnit suite in tests/unit
just acceptance               # run the built programs in scratch repositories
just docs-check               # verify cli.md and rendered diagrams match their sources
just fix                      # regenerate cli.md and diagrams after a change upstream of them
just release                  # the release binaries
just package                  # pack them as npm packages and check the installed result
just check                    # the full gate -- before pushing
```

The `synapse` library is an Alire git pin in `alire.toml` on a tagged
[imunitic/synapse](https://github.com/imunitic/synapse) release commit. Bumping it to a newer
release is a deliberate `alr pin synapse --use=<url> --commit=<tag> --subdir=synapse` against a
real tag, never an arbitrary commit, and the same tag in `tests/unit/alire.toml` and
`tests/acceptance/alire.toml`. The build compiles the library's vendored tree-sitter C source, so it
needs the C compiler that ships with the GNAT toolchain; the binaries link no tree-sitter code.

A tagged `vX.Y.Z` push runs [`release.yml`](.github/workflows/release.yml): builds the binaries
natively on each platform and publishes the four `@imunitic/synapse-bard*` npm packages in
lock-step via OIDC trusted publishing — no local `npm publish` needed.

## License

MIT — see [LICENSE](LICENSE).
