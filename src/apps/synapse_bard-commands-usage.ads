--  The usage text of each command, as the command line prints it.
--  What a command prints is the contract its callers depend on; the
--  generated CLI reference is built from these texts.

package Synapse_Bard.Commands.Usage is

   LF : constant Character := Character'Val (10);

   Main_Usage : constant String :=
     "usage: synapse-bard <command>" & LF & "" & LF &
     "  sync                          populate _bard/graph" &
     "/ from the bible's" & LF &
     "                                source tree (always " &
     "a full re-ingest)" & LF &
     "  query <node> [--inbound]      resolved relationshi" &
     "ps (outbound by" & LF &
     "                                default, --inbound f" &
     "or backlinks)" & LF &
     "  field <node> <key>            one raw frontmatter " &
     "field, verbatim" & LF &
     "  fields <node>                 a template's own fie" &
     "ld names, so you" & LF &
     "                                know which `field` c" &
     "alls are worth" & LF &
     "                                making instead of gu" & "essing" &
     LF & "  fields --template <name>      same, by template na" &
     "me directly" & LF &
     "  search <query>                full-text over _bard" & "/graph/" &
     LF & "  search --field <key>:<value>  structured filter ac" &
     "ross the graph" & LF &
     "  vault-search <query>          full-text over _bard" &
     "/vault/, ranked" & LF &
     "                                by backlink count" & LF &
     "  vault-links <note>            every note in _bard/" &
     "vault/ linking to" & LF & "                                <note>" &
     LF & "  verify                        check frontmatter/pr" &
     "ose-body links and" & LF &
     "                                kinds: values agains" &
     "t the graph" & LF &
     "  manuscript <root>             check a series manus" &
     "cript and list its" & LF &
     "                                books and chapters" & LF &
     "  ground <root> <roster>        find where the manus" &
     "cript names each" & LF &
     "                                roster entity, into " &
     "$SYNAPSE_BARD_WORK_DIR" & LF &
     "  quote <root> <book> <chapter> <line> <text>" & LF &
     "                                check a quote sits o" &
     "n a cited line" & LF &
     "  templates [--install]         the entity kinds and" &
     " their template" & LF &
     "                                files; --install cop" &
     "ies in the default" & LF &
     "                                set when there is no" & "ne" & LF &
     "  mode                          generate or report, " &
     "by whether the" & LF &
     "                                bible has entity fil" & "es" & LF;

   Field_Usage : constant String :=
     "usage: synapse-bard field <node> <key>" & LF & "" & LF &
     "  <node>    the wikilink slug, without .md (e.g. aid" & "an-dayne)" &
     LF & "  <key>     a root-level frontmatter key (e.g. image" &
     "s) -- no dotted" & LF & "            nested paths" & LF;

   Fields_Usage : constant String :=
     "usage: synapse-bard fields <node>" & LF &
     "       synapse-bard fields --template <name>" & LF & "" & LF &
     "  <node>              the wikilink slug -- resolved " &
     "the same way query/" & LF &
     "                      field do, then its own templat" &
     "e is looked up" & LF &
     "  --template <name>   a template name directly (e.g." &
     " character_pov)," & LF &
     "                      matching a root-level template" &
     ": value verbatim --" & LF &
     "                      for exploring a schema with no" &
     " example entity" & LF;

   Query_Usage : constant String :=
     "usage: synapse-bard query <node> [--inbound]" & LF & "" & LF &
     "  <node>       the wikilink slug, without .md (e.g. " &
     "calla-starweaver)" & LF &
     "  --inbound    backlinks -- who references <node> --" &
     " instead of outbound refs" & LF;

   Search_Usage : constant String :=
     "usage: synapse-bard search <query>" & LF &
     "       synapse-bard search --field <key>:<value>" & LF & "" & LF &
     "  <query>              full-text substring, always, " &
     "case-insensitive --" & LF &
     "                       never treated as key:value ev" &
     "en if it contains" & LF & "                       a colon" & LF &
     "  --field <key>:<value>  exact match on a root-level" &
     " frontmatter field" & LF &
     "                       across every entity (key case" &
     "-sensitive, value" & LF &
     "                       case-insensitive), e.g. --fie" &
     "ld faction:""the" & LF & "                       radiant dominion""" &
     LF;

   Sync_Usage : constant String :=
     "usage: synapse-bard sync" & LF & "       synapse-bard sync --check" &
     LF & "" & LF & "Walks the bible repo for entity files (any path with" &
     " a `_`- or" & LF &
     "`.`-prefixed folder is excluded), groups them into c" &
     "lusters -- the" & LF &
     "shallowest folder in each top-level, non-excluded fo" &
     "lder's tree that" & LF &
     "directly contains a `.md` file -- and writes one" & LF &
     "_bard/graph/{Cluster Title}.md per cluster, carrying" &
     " a `sources:`" & LF &
     "manifest of its member entities. Always a full re-in" &
     "gest; stale" & LF &
     "cluster nodes for folders no longer producing any en" &
     "tity are removed." & LF & "" & LF &
     "  --check    report whether _bard/graph/ matches wha" &
     "t a real run" & LF &
     "             would produce, without writing anything" &
     ". Exit 0 if it" & LF &
     "             already matches, exit 1 if it doesn't." & LF;

   Vault_Links_Usage : constant String :=
     "usage: synapse-bard vault-links <note>" & LF & "" & LF &
     "  <note>  a vault-relative path, or just its filenam" &
     "e stem (the same" & LF &
     "          way a [[wikilink]] itself resolves) -- e.g" & ". both" &
     LF & "          ""designs/synapse-bard/Bible-graph.md"" and " &
     """Bible-graph""" & LF & "          find the same note" & LF;

   Vault_Search_Usage : constant String :=
     "usage: synapse-bard vault-search <query>" & LF & "" & LF &
     "  <query>  full-text substring over _bard/vault/, ca" &
     "se-insensitive," & LF & "           ranked by each" & LF &
     "           matching note's backlink count -- most-li" &
     "nked first, node" & LF & "           path ascending to break a tie" &
     LF;

   Verify_Usage : constant String :=
     "usage: synapse-bard verify" & LF & "" & LF &
     "Checks every entity's frontmatter refs and prose-body [[wikilinks]]" &
     LF & "resolve to a real entity, and every kinds: value is one the" & LF &
     "template set's kinds template (kinds_template.md, its kinds: field)" &
     LF & "enumerates; without a kinds template the values are not checked." &
     LF & "Read-only -- reports findings, fixes nothing. Exit 1 if any check" &
     LF & "found something." & LF;

   Manuscript_Usage : constant String :=
     "usage: synapse-bard manuscript <root>" & LF & "" & LF &
     "  <root>  a folder holding an index.md: a numbered list" & LF &
     "          of paths, one per book, in series order. A book" & LF &
     "          is a folder with its own index.md listing its" & LF &
     "          chapter files, or a single .md file with one H1" & LF &
     "          (the title) and one H2 per chapter." & LF & "" & LF &
     "Checks the manuscript and prints one tab-separated line" & LF &
     "per chapter: book, chapter, file, first line, last line." & LF &
     "A folder or file name written as a slug (_ or - and no" & LF &
     "space) is shown as a title: they become spaces and the" & LF &
     "first letter is capitalized; any other name is shown as" & LF &
     "written. Exit 1 with the reason when the manuscript does" & LF &
     "not conform." & LF;

   Ground_Usage : constant String :=
     "usage: synapse-bard ground <root> <roster>" & LF & "" & LF &
     "  <root>    a manuscript folder, as for `manuscript`" & LF &
     "  <roster>  a file with one entity per line, tab-separated:" & LF &
     "            name, kind, then any number of aliases" & LF & "" & LF &
     "Writes $SYNAPSE_BARD_WORK_DIR/_refs.tsv, one tab-separated" & LF &
     "line per whole-word mention of a name or alias: term," & LF &
     "entity, book, chapter, file, line, SHA-256 of the line." & LF &
     "Sorted by term, then entity, then position. Pronouns and" & LF &
     "other mentions without a name form are not found. Exit 1" & LF &
     "when the variable is unset or an input is refused." & LF;

   Quote_Usage : constant String :=
     "usage: synapse-bard quote <root> <book> <chapter> <line> <text>" &
     LF & "" & LF &
     "Checks that <text> sits within line <line> of chapter" & LF &
     "<chapter> of book <book>, the line being inside that" & LF &
     "chapter. Names are the titles `manuscript` prints. Exit 0" & LF &
     "when it does, 1 when it does not." & LF;

   Templates_Usage : constant String :=
     "usage: synapse-bard templates" & LF &
     "       synapse-bard templates --install" & LF & "" & LF &
     "Prints one tab-separated line per template of the bible's" & LF &
     "_templates/: its kind and the path of its file (a" & LF &
     "{kind}_template.md). Exit 1 when it holds none." & LF & "" & LF &
     "  --install    copy the default template set the package ships" & LF &
     "               into _templates/ and print each copy. Refused when" & LF &
     "               _templates/ already holds a template, so nothing is" & LF &
     "               ever overwritten." & LF;

   Mode_Usage : constant String :=
     "usage: synapse-bard mode" & LF & "" & LF &
     "Prints `generate` when the bible has no entity files yet and" & LF &
     "`report` when it has any: the two modes of book-to-bible." & LF &
     "An entity file is one `sync` would ingest." & LF;

end Synapse_Bard.Commands.Usage;
