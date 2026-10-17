with Synapse.Core.Optional_Text;
with Synapse.Core.Text_Lists;

--  The small reads of a bible note's frontmatter that need no YAML: the block
--  itself, its root keys, one root field as written, and the wikilinks of a
--  text. A block that opens but never closes is not frontmatter.

package Synapse_Bard.Frontmatter_Fields is

   subtype Maybe_Text is Synapse.Core.Optional_Text.Option;

   function Has_Block (Source : String) return Boolean with
     Pre => Source'Last < Positive'Last;

   --  The opening `---` line through the closing `---` line, verbatim: what
   --  `sync` copies into a graph node. The prose body is dropped.
   function Block (Source : String) return Maybe_Text with
     Pre => Source'Last < Positive'Last;

   --  Every column-zero key, in order, skipping blank, indented and `#`
   --  lines; nested sub-fields do not appear. Empty without a block.
   function Root_Keys (Source : String) return Synapse.Core.Text_Lists.Vector
   with Pre => Source'Last < Positive'Last;

   --  The `Key:` line and every line below it that is blank or indented,
   --  verbatim, each ending in a line feed, up to the next non-blank column-
   --  zero line. Root keys only; never refuses.
   function Raw_Field (Source, Key : String) return Maybe_Text with
     Pre => Source'Last < Positive'Last;

   --  The target of every `[[wikilink]]` in Text, in order, duplicates
   --  included.
   function Wikilink_Targets
     (Text : String) return Synapse.Core.Text_Lists.Vector;

end Synapse_Bard.Frontmatter_Fields;
