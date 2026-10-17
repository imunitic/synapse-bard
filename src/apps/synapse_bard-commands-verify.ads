with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Ports.Store;

--  The `verify` subcommand: a read-only integrity check across the whole
--  graph. Every frontmatter ref and every `[[wikilink]]` in a note's prose
--  must resolve to an entity slug, and every `kinds:` value must be one of the
--  ten settled ones. It reports; it never fixes and never infers a
--  relationship.

package Synapse_Bard.Commands.Verify is

   --  One finding. Field is the dotted field of a frontmatter ref and the fixed
   --  labels `prose` and `kinds` for the other two checks.
   type Miss is record
      File   : Ada.Strings.Unbounded.Unbounded_String;
      Field  : Ada.Strings.Unbounded.Unbounded_String;
      Target : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Miss_Vectors is new Ada.Containers.Vectors (Positive, Miss);

   --  How many distinct entities link to a resolved prose target.
   type Tally is record
      Target : Ada.Strings.Unbounded.Unbounded_String;
      Count  : Natural;
   end record;

   package Tally_Vectors is new Ada.Containers.Vectors (Positive, Tally);

   type Report is record
      Frontmatter_Misses : Miss_Vectors.Vector;
      Prose_Misses       : Miss_Vectors.Vector;
      Kind_Misses        : Miss_Vectors.Vector;
      --  By count, most first, then by target.
      Mentions           : Tally_Vectors.Vector;
   end record;

   function Total_Findings (R : Report) return Natural;

   --  The three checks over one slug set built once from the store, which is
   --  only read.
   function Compute_Report
     (Repo_Root : String; Store : in out Synapse.Ports.Store.Store'Class)
      return Report;

   function Run (Env : Environment; Args : Arguments) return Exit_Code;

end Synapse_Bard.Commands.Verify;
