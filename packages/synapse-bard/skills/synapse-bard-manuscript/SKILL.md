---
name: synapse-bard-manuscript
description: The layout and format a series manuscript must have for synapse-bard to read it (book-to-bible, the manuscript, ground and quote subcommands). Load this BEFORE pointing synapse-bard at a manuscript, before creating or restructuring manuscript files, and when the author asks how to lay out her books, chapters or index files.
---

# The manuscript format

Knowledge, not a procedure. This is what `synapse-bard` accepts as a manuscript and what it refuses; running book-to-bible is the `synapse-bard-book-to-bible` command's job. `synapse-bard manuscript <root>` checks a manuscript against everything below and prints its books and chapters, or the reason it is refused.

## Markdown only, laid out by index files

`synapse-bard` reads markdown and nothing else, and infers no structure from folder layout or filename order. Index files state it. A Google Docs or Word manuscript has to be converted into this layout first; the tool does not convert and does not detect chapter titles in plain text.

## The root

A folder holding an `index.md`: a numbered list of relative paths, one per book, in series order.

```
1. the_first_book/
2. second_book.md
```

- Every non-blank line is an ordered-list item (`1.` or `1)`) with one path. Anything else is refused.
- A path is relative to the folder holding the index, may end in `/`, and may not be absolute or contain `.` or `..` parts.
- Only listed paths are read. A file or folder nobody lists is ignored. A listed path that does not exist is refused.
- A series of one book is an index with one item.
- The root may be inside the bible repository or anywhere else. It is always an explicit path; there is no default location.

## A book is a folder or a single file

**A folder book** has its own `index.md` in the same format, listing its chapter files in reading order.

```
the_first_book/
  index.md        1. the_departure.md
                  2. the_storm.md
  the_departure.md
  the_storm.md
```

The folder's name is the book's title and each listed file is one chapter, named by its filename. Headings inside a chapter file are plain content and are never parsed.

**A single-file book** is one `.md` file with exactly one `# ` heading, the title, followed by one `## ` heading per chapter, the chapter's name.

```
# The Second Book

## Dawn
…text of the chapter…

## Dusk
…text of the chapter…
```

- The first non-blank line is the H1; a second H1 is refused.
- Between the H1 and the first H2 there is nothing but blank lines.
- At least one H2. Everything under an H2, `###` scene breaks included, is that chapter's content; depth below H2 is not parsed.
- A heading is `#` or `##` followed by a space and a non-empty title.

## Names become titles

A folder name or chapter filename is shown as a title. A trailing `.md` is dropped. A name written as a slug, with `_` or `-` and no space, has them turned into spaces and its first letter capitalized, so `some_title_of_the_chapter.md` is the chapter "Some title of the chapter" and `the_star_forge` the book "The star forge". A name with a space, or with neither separator, is already a title and stays as written: a folder named `The Star Forge` is the book "The Star Forge", and `Prologue.md` the chapter "Prologue". Capitals after the first letter, and any numeric prefix, stay as written.

## Positions

Everything the tool cites is book, chapter and line, the line being a 1-based line of the file the chapter is in. A quote is checked with `synapse-bard quote <root> <book> <chapter> <line> <text>`, using the titles `manuscript` prints.

## Where it is used

`synapse-bard manuscript`, `ground` and `quote` take the root as an argument. `$SYNAPSE_BARD_WORK_DIR` holds what the pipeline produces and is never inside the bible repository. See `docs/synapse-bard/book-to-bible.md` for the two modes.
