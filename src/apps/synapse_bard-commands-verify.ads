with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Text_Lists;
with Synapse.Ports.Store;

--  The `verify` subcommand: a read-only integrity check across the whole
--  graph. Every frontmatter ref and every `[[wikilink]]` in a note's prose
--  must resolve to an entity slug, and every `kinds:` value must be one the
--  template set's kinds template enumerates; with no kinds template the
--  values are not checked. It reports; it never fixes and never infers a
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

   --  The values the template set's kinds template allows in a `kinds:` field:
   --  the `kinds:` field of its `kinds_template.md`. Empty when the set has no
   --  kinds template, or its template lists nothing, or there is no set.
   function Allowed_Kinds
     (Repo_Root : String) return Synapse.Core.Text_Lists.Vector;

   --  The three checks over one slug set built once from the store, which is
   --  only read. Allowed is what a `kinds:` value may be; with none, the
   --  values are not checked and Kind_Misses stays empty.
   function Compute_Report
     (Repo_Root : String; Allowed : Synapse.Core.Text_Lists.Vector;
      Store : in out Synapse.Ports.Store.Store'Class) return Report;

   function Run (Env : Environment; Args : Arguments) return Exit_Code;

end Synapse_Bard.Commands.Verify;
