---
name: synapse-bard-book-to-bible
description: Draft a bible from a series manuscript, or report how the manuscript differs from an existing bible (contradictions, new facts, new entities, inconsistencies within the book) — the two modes of book-to-bible, chosen by whether the bible already has entity files. Use whenever the author wants a bible generated from her books, or a new book checked against the bible ("generate the bible from my manuscript", "check book 3 against the bible", "book to bible").
---

Run book-to-bible over a manuscript. The bible is the source of truth: **generate** drafts entity files into a bible that has none, **report** only tells the author how the manuscript differs from a bible that has some, and never writes a bible file. The author then decides, finding by finding, whether to change the book or the bible.

The mechanical parts are `synapse-bard` subcommands (a shell call each); roster detection, chapter summarization, the report and the drafting are yours. The binary does no network I/O.

## The manuscript root

The `synapse-bard-manuscript` skill holds the full layout and format; load it before touching a manuscript. In short:

A required path to a folder holding an `index.md`: a numbered list of paths, one per book, in series order. A book is a single `.md` file, or a folder with its own `index.md` listing its chapter files in reading order. A single-file book has one H1 (its title) and one H2 per chapter. A folder book takes its title from the folder name and its chapters from the listed filenames (`_` and `-` shown as spaces, first letter capitalised); headings inside a chapter file are just content.

If the author gave no path, ask for it. There is no default location, and it may be inside the bible repository or anywhere else.

The root must already follow this layout. This command reads a manuscript and never converts or repairs one: a manuscript in any other format is brought into this layout before book-to-bible runs, guided by the `synapse-bard-manuscript` skill, and `synapse-bard manuscript` says whether the result conforms.

`$SYNAPSE_BARD_WORK_DIR` must be set, since everything below keeps its intermediate state there and never inside the bible repository. If it is unset, tell the author and stop.

## Preparing

1. `synapse-bard manuscript <root>` checks the manuscript and prints one tab-separated line per chapter: book, chapter, file, first line, last line. If it exits non-zero, relay the reason and stop; do not try to fix the manuscript.
2. `synapse-bard templates` prints `kind<TAB>path` for each template in the bible's `_templates/`. If it exits non-zero the bible has no template set: ask the author whether to install the default set the package ships, then stop either way, without going on to the manuscript. On yes, run `synapse-bard templates --install`, tell her what it copied and that the copies in `_templates/` are hers to customize before she runs book-to-bible again. On no, stop, since the pipeline needs a template set. The `kinds` template, when present, is a vocabulary for `kinds:` fields and not an entity kind.
3. `synapse-bard mode` prints `generate` or `report`. Tell the author which mode this run is in.

## Roster detection

For each chapter, read its lines (`file`, `first` to `last` from the outline) and list the named entities in it, each with its kind and any alternate names the chapter uses for it. Use only kinds that have a template. Do this every run, whether or not a bible exists: a lookup against the existing bible can only confirm a returning entity, never surface a new one.

Merge the chapters' results into one entry per entity with its aliases combined, and write `$SYNAPSE_BARD_WORK_DIR/roster.tsv`: one entity per line, tab-separated, as name, kind, then each alias.

In report mode, match each roster entry against the bible's existing entities only now, to resolve aliases and catch one entity named two ways (`synapse-bard search`, `synapse-bard field <node> name`, or reading the entity file). A match decides the entity's path: a known entity is compared, an unmatched one is new.

## Grounding

`synapse-bard ground <root> $SYNAPSE_BARD_WORK_DIR/roster.tsv` writes `$SYNAPSE_BARD_WORK_DIR/_refs.tsv`: one line per whole-word mention of a name or alias, as term, entity, book, chapter, file, line and a SHA-256 of the line, sorted by term. It finds only mentions that use a name; "he" and "the old man" are not found, and that is accepted. Read an entity's mentions straight from this index, then the lines themselves from `file`.

## Chapter summaries

Write a synopsis of each chapter to `$SYNAPSE_BARD_WORK_DIR/summaries/`, one file per chapter. Mentions only catch what is stated next to a name; a place's significance, a magic system's rules or a faction's goals are established across a whole passage. Summaries are scratch: regenerate them every run, never treat an old one as current.

## Report mode

For each roster entity matched to a bible entity, compare its mentions (`_refs.tsv`) and the summaries of the chapters it appears in against the entity file's frontmatter. Report four kinds of finding:

- **contradiction** — the book says something that cannot be true together with a value in the bible (blue eyes where the bible says brown). A difference in wording, emphasis or level of detail is not a contradiction: report it as a new fact only if it adds something the bible lacks, and otherwise leave it out;
- **new fact** — the book states something about a known entity that the bible does not record (a scar);
- **new entity** — a roster entry with no match in the bible;
- **inconsistency within the book** — two passages of the manuscript that cannot both be true (a pool of tears said to be shallow in one chapter and deeper than the character is tall in another), whatever the bible says. It is not a contradiction, which is always against the bible, and it applies to any roster entity, new or known, and to places and events as well as characters.

Every finding cites a quote with its book, chapter and line; an inconsistency cites one quote for each passage. Before it goes in the report, run `synapse-bard quote <root> <book> <chapter> <line> "<quote>"`; exit 0 means the quote really sits there. Drop or redo any finding whose quote does not verify.

Print the report in the reply, grouped by entity, each finding labelled, naming the bible field and value where there is one, and the quote with its location. It is a report for a writer to read, not a code diff. Create or modify nothing in the bible. If the manuscript agrees with the bible everywhere, say so.

## Generate mode

For each roster entity, draft one entity file against the template its kind resolves to. Take the template's field names from `synapse-bard fields --template <kind>` and its file from `synapse-bard templates`, start from the template's own frontmatter, set `template:` to the kind, and fill in only the fields it lists. Read only that entity's own mentions and the summaries of the chapters it appears in, not the whole book. Do not invent a field the template does not have, and leave a field empty when the manuscript does not say.

Name each file by the entity's slug (lowercase, words joined by hyphens) and put it in a top-level folder named for its kind, unless the author names another layout. Work on a new git branch, so review is an ordinary branch and pull request, and do not commit or push unless the author asks.

## Constraints

- Never modify an existing bible file, in either mode.
- Never write intermediate state (roster, `_refs.tsv`, summaries) inside the bible repository.
- Never edit a template. The only template change is the default set copied in, with the author's agreement, when the bible has none.
- Run `synapse-bard sync` afterwards only if the author asks; it is not part of this command.

## Confirm

State the mode, how many chapters and entities were processed, and either the report (report mode) or the paths of the drafted files and the branch they are on (generate mode).
