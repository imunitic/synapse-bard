with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.File_Bytes;
with Synapse.Core.Hashing;

package body Synapse_Bard.Grounding.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF  : constant String := [Character'Val (10)];
   TAB : constant String := [Character'Val (9)];

   function Has (Text, Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Part) > 0);

   --  A one-book series holding Text under the chapter "Dawn".
   function Series_Of (Root, Text : String) return Manuscript.Series is
   begin
      Ada.Directories.Create_Path (Root & "/Book");
      Synapse.Adapters.File_Bytes.Write (Root & "/index.md", "1. Book/" & LF);
      Synapse.Adapters.File_Bytes.Write
        (Root & "/Book/index.md", "1. Dawn.md" & LF);
      Synapse.Adapters.File_Bytes.Write (Root & "/Book/Dawn.md", Text);
      return Manuscript.Loaded.Value (Manuscript.Load (Root));
   end Series_Of;

   function Roster_Of (Text : String) return Roster is
   begin
      return Parsed.Value (Parse_Roster (Text));
   end Roster_Of;

   function Lines_Of (Refs : Reference_Vectors.Vector) return String is
      Result : Unbounded_String;
   begin
      for R of Refs loop
         Append (Result, To_String (R.Term) & "@" & R.Line'Image);
      end loop;
      return To_String (Result);
   end Lines_Of;

   procedure A_Roster_Has_A_Name_A_Kind_And_Aliases
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Found : constant Roster :=
        Roster_Of
          ("Aidan Dayne" & TAB & "character" & TAB & "Aidan" & TAB & "Dayne"
           & LF & LF & "Ashfall" & TAB & "place" & LF);
   begin
      Assert (Natural (Found.Length) = 2, "two entities, blank line skipped");
      Assert
        (To_String (Found (1).Kind) = "character"
         and then Natural (Found (1).Aliases.Length) = 2
         and then Natural (Found (2).Aliases.Length) = 0,
         "kind and aliases");
   end A_Roster_Has_A_Name_A_Kind_And_Aliases;

   procedure A_Bad_Roster_Line_Is_Refused
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      function Why (Text : String) return String is
         Result : constant Parsed.Result := Parse_Roster (Text);
      begin
         return (if Parsed.Is_Success (Result) then "<parsed>"
                 else To_String (Parsed.Error (Result)));
      end Why;
   begin
      Assert (Has (Why ("Aidan"), "line 1: needs a name and a kind"),
              "name only");
      Assert (Has (Why ("A" & TAB & "x" & LF & "B" & TAB & TAB & "y"),
                   "line 2: has an empty column"), "empty alias");
      Assert (Has (Why ("A" & TAB & "x" & LF & "A" & TAB & "y"),
                   "repeats the name 'A'"), "repeated name");
      Assert (Why ("A" & TAB & "x" & TAB & "B" & LF) = "<parsed>",
              "a good roster");
   end A_Bad_Roster_Line_Is_Refused;

   procedure A_Name_Grounds_Only_As_A_Whole_Word
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root  : constant String := Scratch_Dirs.Make ("grounding-words");
      Books : constant Manuscript.Series :=
        Series_Of
          (Root,
           "Aidan walked." & LF & "Aidans did not." & LF
           & "He met Aidan's sister." & LF & "ReAidan, said no one." & LF
           & """Aidan,"" she said." & LF
           & Character'Val (16#E2#) & Character'Val (16#80#)
           & Character'Val (16#9C#) & "Aidan"
           & Character'Val (16#E2#) & Character'Val (16#80#)
           & Character'Val (16#9D#) & LF & "Aidan_2 is a code." & LF
           & "aidan in lower case." & LF);
      Refs  : constant Reference_Vectors.Vector :=
        Ground (Books, Roster_Of ("Aidan" & TAB & "character" & LF));
   begin
      Assert
        (Lines_Of (Refs) = "Aidan@ 1Aidan@ 3Aidan@ 5Aidan@ 6",
         "whole words only, punctuation and curly quotes are boundaries: "
         & Lines_Of (Refs));
      Scratch_Dirs.Remove (Root);
   end A_Name_Grounds_Only_As_A_Whole_Word;

   procedure Aliases_Ground_Under_Their_Entity_And_Order_Is_Fixed
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root  : constant String := Scratch_Dirs.Make ("grounding-order");
      Books : constant Manuscript.Series :=
        Series_Of
          (Root,
           "The Captain left." & LF & "Aidan Dayne stayed." & LF
           & "Aidan spoke to the Captain." & LF & "Nothing here." & LF);
      Found : constant Roster :=
        Roster_Of
          ("Aidan Dayne" & TAB & "character" & TAB & "Aidan" & TAB
           & "the Captain" & TAB & "Captain" & TAB & "Aidan" & LF);
      First : constant Reference_Vectors.Vector := Ground (Books, Found);
      Again : constant Reference_Vectors.Vector := Ground (Books, Found);
   begin
      Assert
        (Lines_Of (First) =
           "Aidan@ 2Aidan@ 3Aidan Dayne@ 2Captain@ 1Captain@ 3the Captain@ 3",
         "ordered by term then position, a repeated alias once, case kept: "
         & Lines_Of (First));
      Assert
        (Image (First) = Image (Again), "the same input gives the same index");
      Assert
        (To_String (First (1).Entity) = "Aidan Dayne"
         and then To_String (First (1).Book) = "Book"
         and then To_String (First (1).Chapter) = "Dawn",
         "an alias grounds its entity, with book and chapter");
      Assert
        (To_String (First (1).Digest) =
           Synapse.Core.Hashing.Sha256_Hex ("Aidan Dayne stayed."),
         "the digest is of the line text");
      Scratch_Dirs.Remove (Root);
   end Aliases_Ground_Under_Their_Entity_And_Order_Is_Fixed;

   procedure The_Index_Is_One_Tab_Separated_Row_Per_Reference
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root  : constant String := Scratch_Dirs.Make ("grounding-image");
      Books : constant Manuscript.Series :=
        Series_Of (Root, "Ashfall burned." & LF);
      Rows  : constant String :=
        Image (Ground (Books, Roster_Of ("Ashfall" & TAB & "place" & LF)));
   begin
      Assert
        (Rows =
           "Ashfall" & TAB & "Ashfall" & TAB & "Book" & TAB & "Dawn" & TAB
           & Ada.Directories.Full_Name (Root) & "/Book/Dawn.md" & TAB & "1"
           & TAB & Synapse.Core.Hashing.Sha256_Hex ("Ashfall burned.") & LF,
         "term, entity, book, chapter, file, line, digest");
      Assert
        (Image (Ground (Books, Roster_Of ("Nobody" & TAB & "x" & LF))) = "",
         "no reference, no row");
      Scratch_Dirs.Remove (Root);
   end The_Index_Is_One_Tab_Separated_Row_Per_Reference;

   procedure A_Citation_Is_Checked_Against_The_Manuscript
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root  : constant String := Scratch_Dirs.Make ("grounding-quote");
      Books : constant Manuscript.Series :=
        Series_Of (Root, "First line." & LF & "Eyes of brown." & LF);
      use Manuscript;
   begin
      Assert (Holds_Quote (Books, "Book", "Dawn", 2, "Eyes of brown"),
              "a quote on the cited line");
      Assert (not Holds_Quote (Books, "Book", "Dawn", 1, "Eyes of brown"),
              "the quote is on another line");
      Assert (not Holds_Quote (Books, "Book", "Dawn", 2, "Eyes of blue"),
              "an invented quote");
      Assert (not Holds_Quote (Books, "Book", "Dusk", 2, "Eyes of brown"),
              "the wrong chapter");
      Assert (not Holds_Quote (Books, "Other", "Dawn", 2, "Eyes of brown"),
              "the wrong book");
      Assert (not Holds_Quote (Books, "Book", "Dawn", 9, "Eyes"),
              "a line past the chapter");
      Assert (not Holds_Quote (Books, "Book", "Dawn", 2, ""),
              "an empty quote");
      Scratch_Dirs.Remove (Root);
   end A_Citation_Is_Checked_Against_The_Manuscript;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Grounding");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, A_Roster_Has_A_Name_A_Kind_And_Aliases'Access,
         "a roster line is a name, a kind and aliases");
      Register_Routine
        (T, A_Bad_Roster_Line_Is_Refused'Access,
         "a short, empty-column or repeated roster line is refused");
      Register_Routine
        (T, A_Name_Grounds_Only_As_A_Whole_Word'Access,
         "a name grounds only as a whole word");
      Register_Routine
        (T, Aliases_Ground_Under_Their_Entity_And_Order_Is_Fixed'Access,
         "aliases ground their entity in a fixed order");
      Register_Routine
        (T, The_Index_Is_One_Tab_Separated_Row_Per_Reference'Access,
         "the index is one tab-separated row per reference");
      Register_Routine
        (T, A_Citation_Is_Checked_Against_The_Manuscript'Access,
         "a citation is checked against the manuscript");
   end Register_Tests;

end Synapse_Bard.Grounding.Tests;
