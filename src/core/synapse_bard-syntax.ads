--  The text rules the manuscript and grounding layers share: what a path, a
--  heading, a list item, a title or a whole word looks like. Pure functions on
--  strings, proved free of run-time errors by GNATprove.

package Synapse_Bard.Syntax with SPARK_Mode is

   LF  : constant Character := Character'Val (10);
   CR  : constant Character := Character'Val (13);
   TAB : constant Character := Character'Val (9);

   --  Item without the spaces at either end.
   function Trim (Item : String) return String with
     Pre  => Item'Last < Positive'Last,
     Post => Trim'Result'Length <= Item'Length;

   --  Whether Item names a place under the folder holding the index that lists
   --  it: not empty, not absolute, and with no `.` or `..` part.
   function Stays_Inside (Item : String) return Boolean with
     Pre => Item'Last < Positive'Last;

   --  Whether Line is a heading of exactly Level `#`s followed by a space.
   function Is_Heading (Line : String; Level : Positive) return Boolean with
     Pre  => Level <= 6 and then Line'Last < Positive'Last,
     Post => (if Is_Heading'Result then Line'Length > Level);

   --  The text of a heading Line of Level, without the `#`s and the spaces
   --  around it; empty when Line is not such a heading.
   function Heading_Text (Line : String; Level : Positive) return String with
     Pre  => Level <= 6 and then Line'Last < Positive'Last,
     Post => Heading_Text'Result'Length <= Line'Length
             and then (if not Is_Heading (Line, Level)
                       then Heading_Text'Result'Length = 0);

   --  Where the text of an ordered list item starts in Line, which has no
   --  spaces at either end: after digits, a `.` or `)`, and a space. 0 when
   --  Line is not an ordered list item.
   function Item_Start (Line : String) return Natural with
     Pre  => Line'Last < Positive'Last - 3,
     Post => Item_Start'Result = 0
             or else Item_Start'Result in Line'First + 2 .. Line'Last + 1;

   --  A file or folder name as a title. A trailing `.md` is dropped. A name
   --  written as a slug, with `_` or `-` and no space, has them turned into
   --  spaces and an ASCII first letter capitalized; any other name is already
   --  a title and is left as written.
   function Unslugify (Name : String) return String with
     Pre  => Name'Last < Positive'Last,
     Post => Unslugify'Result'Length <= Name'Length;

   --  Whether a code point is part of a word. Letters of every script are; the
   --  punctuation and symbols of the General Punctuation, Supplemental
   --  Punctuation, CJK Symbols, small form and fullwidth ASCII blocks are not.
   function Is_Word (Code : Natural) return Boolean;

   --  Whether Term occurs in Line as a whole word: not preceded or followed by
   --  a letter, a digit or `_`. An empty Term occurs nowhere.
   function Holds_Word (Line, Term : String) return Boolean with
     Pre => Line'Last < Positive'Last and then Term'Last < Positive'Last;

end Synapse_Bard.Syntax;
