with Ada.Containers.Vectors;

with Synapse.Core.Tag_Payload;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Extractor;

--  Bible entity frontmatter in, `def` and `ref` tags out. A `def` is the
--  file's own identity: the root `name:` value, of kind the root `template:`
--  value (`entity` without one). A `ref` is every `[[wikilink]]` in any
--  scalar or list value of the frontmatter tree, of kind the dotted path of
--  the field it came from (`relationships.key_relationships.link`); what a
--  link's target is, is the caller's to resolve.
--
--  The accepted YAML is a subset: scalars, block lists of scalars or objects,
--  nested maps, flow lists of scalars and wikilinks (also across lines), full-
--  line comments and an empty flow map. Anything else refuses the whole file,
--  and says why: a reader that skips what it does not understand drops
--  relationships silently from notes that look fine, where a refusal is
--  visible and recoverable.
--
--  The prose body after the frontmatter is never read, so a `---` scene break
--  in it is not a second document.

package Synapse_Bard.Frontmatter_Extractor is

   type Refusal is
     (Not_A_Note, No_Frontmatter, Unterminated, Anchor_Or_Alias, Block_Scalar,
      Flow_Collection, Tab_Indent, Nesting_Too_Deep, Malformed_Line);

   --  The reason as the command line prints it: `not_a_note`.
   function Name (Reason : Refusal) return String;

   type Maybe_Refusal (Refused : Boolean := False) is record
      case Refused is
         when True =>
            Why : Refusal;

         when False =>
            null;
      end case;
   end record;

   --  The tags of one note's text, or the reason it is refused (and then no
   --  tags).
   procedure Scan
     (Source : String; Tags : out Synapse.Core.Tag_Payload.Tag_Vectors.Vector;
      Result : out Maybe_Refusal);

   type Extractor is limited new Synapse.Ports.Extractor.Extractor with
     private;

   --  A path that does not end in `.md`, cannot be read, is over 1 MiB or is
   --  refused gives `Unsupported`.
   overriding
   function Extract
     (E     : in out Extractor; Root : String;
      Paths :        Synapse.Core.Text_Lists.Vector)
      return Synapse.Ports.Extractor.Outcome_Vectors.Vector;

   --  Why path number Index of the most recent Extract was refused; not
   --  refused when it parsed, or when it could not be read.
   function Last_Refusal
     (E : Extractor; Index : Positive) return Maybe_Refusal;

private

   package Refusal_Vectors is new Ada.Containers.Vectors
     (Positive, Maybe_Refusal);

   type Extractor is limited new Synapse.Ports.Extractor.Extractor with record
      Refusals : Refusal_Vectors.Vector;
   end record;

end Synapse_Bard.Frontmatter_Extractor;
