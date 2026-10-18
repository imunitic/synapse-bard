with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Synapse.Core.Results;
with Synapse.Core.Text_Lists;

--  A series manuscript read from a root folder through index files. The root
--  holds an `index.md`, a markdown ordered list of relative paths, one per
--  book, in series order. A book is a single `.md` file, or a folder whose own
--  `index.md` lists its chapter files in reading order. Only listed paths are
--  read.
--
--  A folder book takes its title from the folder's name and has one chapter
--  per listed file, named from the file's name; headings inside a chapter
--  file are content. A single-file book has one H1, its title, and one H2 per
--  chapter, its name; anything below an H2 is that chapter's content.
--
--  Every position handed out is a line of a file, numbered from 1.

package Synapse_Bard.Manuscript is

   --  A folder or file name as a title. A trailing `.md` is dropped. A name
   --  written as a slug, with `_` or `-` and no space, has them turned into
   --  spaces and an ASCII first letter capitalized; a name with a space, or
   --  with neither separator, is already a title and is left as written.
   function Unslugify (Name : String) return String;

   --  Lines First .. Last of File, which is an absolute path. Last < First for
   --  a chapter with no lines.
   type Chapter is record
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      File  : Ada.Strings.Unbounded.Unbounded_String;
      First : Positive;
      Last  : Natural;
   end record;

   package Chapter_Vectors is new
     Ada.Containers.Vectors (Positive, Chapter);

   type Book is record
      Title    : Ada.Strings.Unbounded.Unbounded_String;
      Chapters : Chapter_Vectors.Vector;
   end record;

   package Book_Vectors is new Ada.Containers.Vectors (Positive, Book);

   subtype Series is Book_Vectors.Vector;

   package Loaded is new
     Synapse.Core.Results (Series, Ada.Strings.Unbounded.Unbounded_String);

   --  The books of the series under Root, in index order, or why the
   --  manuscript is refused: a missing or malformed index, a listed path that
   --  does not exist or leaves the folder, a single-file book that is not one
   --  H1 followed by H2 chapters.
   function Load (Root : String) return Loaded.Result;

   --  Lines First .. Last of a chapter's file, each without its line feed or
   --  carriage return. Empty when the file cannot be read or the range is
   --  empty.
   function Chapter_Lines
     (Item : Chapter) return Synapse.Core.Text_Lists.Vector;

   --  The same lines, each ended by a line feed.
   function Chapter_Text (Item : Chapter) return String;

   --  Whether Quote, which is not empty, sits within line Line of a chapter
   --  named Chapter_Name in a book titled Book_Title, Line being inside that
   --  chapter. It is how a citation is checked against the manuscript.
   function Holds_Quote
     (Books : Series; Book_Title, Chapter_Name : String; Line : Positive;
      Quote : String) return Boolean;

end Synapse_Bard.Manuscript;
