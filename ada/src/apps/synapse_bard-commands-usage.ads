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
     "t the graph" & LF;

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
     "Checks every entity's frontmatter refs and prose-bod" &
     "y [[wikilinks]]" & LF &
     "resolve to a real entity, and every kinds: value mat" &
     "ches the settled" & LF &
     "vocabulary. Read-only -- reports findings, fixes not" &
     "hing. Exit 1 if" & LF & "any check found something." & LF;

end Synapse_Bard.Commands.Usage;
