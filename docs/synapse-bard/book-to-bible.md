# Book to bible

Two modes over a series manuscript, chosen by whether the bible already has entity files. The bible is the source of truth.

- **generate** — the bible has no entity files yet. An entity file is drafted for every entity found in the manuscript.
- **report** — the bible has entity files. Nothing in it is created or changed: the report lists how the manuscript differs from the bible, as a diff for the author to read, not a code diff. Each finding is a **contradiction** (the book says blue eyes, the bible says brown), a **new fact** about a known entity (a scar the bible does not record) or a **new entity**. The author decides finding by finding whether to change the book or the bible.

`synapse-bard mode` prints which one applies. The LLM-driven steps (roster detection, chapter summaries, the report, the drafting) are run by the agent from the `synapse-bard-book-to-bible` command; the binary does the mechanical ones and does no network I/O.

## The manuscript root

The same layout is available to agents as the `synapse-bard-manuscript` skill (`packages/synapse-bard/skills/synapse-bard-manuscript/SKILL.md`).

A required path, inside the bible repository or anywhere else. It holds an `index.md`, a numbered list of paths, one per book, in series order:

```
1. the_first_book/
2. second_book.md
```

A book is one of two things:

- a **folder** with its own `index.md` listing its chapter files in reading order. The folder name is the book's title and each listed file is a chapter, named from its filename. Headings inside a chapter file are content and are never parsed.
- a **single `.md` file** with exactly one H1, the title, and one H2 per chapter, the chapter's name. Text between the H1 and the first H2 is refused.

Only listed paths are read; a listed path that does not exist, or that leaves the folder, is refused. A trailing `.md` is dropped from a name shown as a title. A name written as a slug, with `_` or `-` and no space, has them turned into spaces and its first letter capitalized, so `some_title_of_the_chapter.md` is the chapter "Some title of the chapter". A name with a space, or with neither separator, is already a title and stays as written, so a folder named `The Star Forge` is the book "The Star Forge".

Turning a Google Docs or Word manuscript into this layout is a separate job. `synapse-bard manuscript <root>` checks a manuscript and lists its books and chapters.

## Pipeline

1. **Roster detection** (agent): per chapter, the named entities, their kinds and alternate names, merged into one roster. Only kinds that have a template are named. The result is `$SYNAPSE_BARD_WORK_DIR/roster.tsv`.
2. **Grounding** (`synapse-bard ground`): every line of the manuscript that holds a name or alias of a roster entity as a whole word, written to `$SYNAPSE_BARD_WORK_DIR/_refs.tsv` as term, entity, book, chapter, file, line and the SHA-256 of the line. It is deterministic and uses no language model. A mention that uses no name (a pronoun, "the old man") is not found.
3. **Chapter summaries** (agent): a synopsis per chapter, scratch state regenerated every run.
4. **Report** or **drafting** (agent): in report mode each finding cites a quote with book, chapter and line, and `synapse-bard quote` confirms the quote sits there before the finding is shown. In generate mode each entity file is drafted against the template for its kind, on a new git branch.

Everything the pipeline produces lives under `$SYNAPSE_BARD_WORK_DIR`, never inside the bible repository.

## Templates

The entity kinds and their fields come from the bible's own `_templates/`, a `{kind}_template.md` per kind. `synapse-bard templates` lists them. A bible with none can be given the default set the package ships under `templates/`: `synapse-bard templates --install` copies it into `_templates/`, refuses when the bible already has a template, and never overwrites a file. When it runs `sync` or book-to-bible and finds no templates, the agent asks whether to install, and then stops either way: after a yes the author customizes the copies before running anything again. The copies belong to the bible and can be edited freely; the pipeline itself never edits a template.

`verify` checks `kinds:` values against a `kinds_template.md` in `_templates/`, whose `kinds:` field enumerates every allowed value. With no kinds template the values are not checked.
