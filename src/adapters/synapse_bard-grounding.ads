with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Results;
with Synapse.Core.Text_Lists;

with Synapse_Bard.Manuscript;

--  Where a manuscript names the entities of a roster. Deterministic and free
--  of any language model: a name or alias grounds on every line that holds it
--  as a whole word, and nothing else. A line that refers to an entity only as
--  "he" or "the old man" does not ground it.

package Synapse_Bard.Grounding is

   --  One entity of a roster: the name it is filed under, the template kind it
   --  belongs to, and the other names the manuscript uses for it.
   type Entity is record
      Name    : Ada.Strings.Unbounded.Unbounded_String;
      Kind    : Ada.Strings.Unbounded.Unbounded_String;
      Aliases : Synapse.Core.Text_Lists.Vector;
   end record;

   package Entity_Vectors is new Ada.Containers.Vectors (Positive, Entity);

   subtype Roster is Entity_Vectors.Vector;

   package Parsed is new
     Synapse.Core.Results (Roster, Ada.Strings.Unbounded.Unbounded_String);

   --  A roster from its file: one entity per line, tab-separated, as the name,
   --  the kind, then any number of aliases. Blank lines are skipped. A line
   --  with fewer than two columns, an empty column, or a name already used by
   --  an earlier line is refused.
   function Parse_Roster (Text : String) return Parsed.Result;

   --  A line of the manuscript holding Term, one of Entity's names.
   type Reference is record
      Term    : Ada.Strings.Unbounded.Unbounded_String;
      Entity  : Ada.Strings.Unbounded.Unbounded_String;
      Book    : Ada.Strings.Unbounded.Unbounded_String;
      Chapter : Ada.Strings.Unbounded.Unbounded_String;
      File    : Ada.Strings.Unbounded.Unbounded_String;
      Line    : Positive;
      --  SHA-256 of the line's text, as 64 hexadecimal digits.
      Digest  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Reference_Vectors is new
     Ada.Containers.Vectors (Positive, Reference);

   --  Every line that holds a name or alias of an entity as a whole word, once
   --  per term and line, ordered by term, then entity, then position in the
   --  series. A whole word is not preceded or followed by a letter, a digit or
   --  `_`; punctuation and the quotation marks of any script do not count.
   function Ground
     (Books : Manuscript.Series; Entities : Roster)
      return Reference_Vectors.Vector;

   --  The references as the index file the authoring steps look entities up
   --  in: one reference per line, tab-separated, as term, entity, book,
   --  chapter, file, line and digest.
   function Image (References : Reference_Vectors.Vector) return String;

end Synapse_Bard.Grounding;
