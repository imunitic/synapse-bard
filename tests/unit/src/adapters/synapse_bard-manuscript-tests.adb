with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.File_Bytes;

package body Synapse_Bard.Manuscript.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   procedure Put (Root, Name, Content : String) is
      Path : constant String := Root & "/" & Name;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put;

   --  The reason a manuscript is refused, or "<loaded>".
   function Refusal (Root : String) return String is
      Result : constant Loaded.Result := Load (Root);
   begin
      return (if Loaded.Is_Success (Result) then "<loaded>"
              else To_String (Loaded.Error (Result)));
   end Refusal;

   function Has (Text, Part : String) return Boolean is
     (Ada.Strings.Fixed.Index (Text, Part) > 0);

   procedure Unslugify_Makes_A_Title_From_A_Name
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Unslugify ("some_title_of_the_chapter.md")
         = "Some title of the chapter", "underscores and extension");
      Assert (Unslugify ("the_star-forge") = "The star forge", "folder name");
      Assert
        (Unslugify ("01_the_beginning.md") = "01 the beginning",
         "a numeric prefix stays");
      Assert
        (Unslugify ("Keep_McGregor") = "Keep McGregor",
         "no other character changes");
      Assert (Unslugify ("notes.txt") = "notes.txt", "only .md is dropped");
      Assert
        (Unslugify ("The Star Forge") = "The Star Forge",
         "a name with spaces is already a title");
      Assert
        (Unslugify ("The Star Forge.md") = "The Star Forge",
         "the extension still goes");
      Assert
        (Unslugify ("the star_forge") = "the star_forge",
         "a space means it is not a slug");
      Assert (Unslugify ("Prologue.md") = "Prologue", "no separator");
      Assert (Unslugify ("") = "", "empty stays empty");
   end Unslugify_Makes_A_Title_From_A_Name;

   procedure A_Series_Lists_Folder_And_File_Books_In_Index_Order
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : constant String := Scratch_Dirs.Make ("manuscript-series");
   begin
      Put (Root, "index.md", "1. the_first_book/" & LF & "2. second.md" & LF);
      Put (Root, "the_first_book/index.md",
           "1. opening.md" & LF & "2. the_storm.md" & LF);
      Put (Root, "the_first_book/opening.md", "One" & LF & "two" & LF);
      Put (Root, "the_first_book/the_storm.md", "# Not a title" & LF & "x");
      Put (Root, "the_first_book/unlisted.md", "never read" & LF);
      Put (Root, "second.md",
           "# Second Book" & LF & LF & "## Dawn" & LF & "a" & LF & "b" & LF
           & "## Dusk" & LF & "c" & LF);
      declare
         Result : constant Loaded.Result := Load (Root);
      begin
         Assert (Loaded.Is_Success (Result), Refusal (Root));
         declare
            Books : constant Series := Loaded.Value (Result);
         begin
            Assert (Natural (Books.Length) = 2, "two books");
            Assert
              (To_String (Books (1).Title) = "The first book",
               "folder name is the title");
            Assert
              (Natural (Books (1).Chapters.Length) = 2,
               "only listed files are chapters");
            Assert
              (To_String (Books (1).Chapters (2).Name) = "The storm",
               "file name is the chapter");
            Assert
              (Books (1).Chapters (1).First = 1
               and then Books (1).Chapters (1).Last = 2,
               "a folder chapter is its whole file");
            Assert
              (Chapter_Text (Books (1).Chapters (2)) = "# Not a title" & LF
               & "x" & LF,
               "headings inside a chapter file are content");
            Assert
              (To_String (Books (2).Title) = "Second Book", "H1 is the title");
            Assert
              (To_String (Books (2).Chapters (1).Name) = "Dawn"
               and then Books (2).Chapters (1).First = 4
               and then Books (2).Chapters (1).Last = 5,
               "H2 chapter spans the lines below it");
            Assert
              (Books (2).Chapters (2).First = 7
               and then Books (2).Chapters (2).Last = 7,
               "the last chapter runs to the end");
            Assert
              (Chapter_Text (Books (2).Chapters (1)) = "a" & LF & "b" & LF,
               "chapter text is its own lines");
         end;
      end;
      Scratch_Dirs.Remove (Root);
   end A_Series_Lists_Folder_And_File_Books_In_Index_Order;

   procedure A_Single_File_Book_Must_Be_One_H1_Then_H2_Chapters
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : constant String := Scratch_Dirs.Make ("manuscript-single");

      function Refusal_Of (Book_Text : String) return String is
      begin
         Put (Root, "index.md", "1. book.md" & LF);
         Put (Root, "book.md", Book_Text);
         return Refusal (Root);
      end Refusal_Of;
   begin
      Assert
        (Has (Refusal_Of ("Chapter 1" & LF & "text" & LF), "must be its H1"),
         "plain text first");
      Assert
        (Has (Refusal_Of ("# A" & LF & "## B" & LF & "# C" & LF), "second H1"),
         "two titles");
      Assert
        (Has (Refusal_Of ("# A" & LF & "an epigraph" & LF & "## B" & LF),
              "between the title and the first chapter"),
         "text before the first chapter");
      Assert (Has (Refusal_Of ("# A" & LF & LF), "no H2 chapters"),
              "no chapters");
      Assert (Has (Refusal_Of (""), "has no H1"), "empty file");
      Assert (Has (Refusal_Of ("# A" & LF & "## " & LF), "no chapter name"),
              "empty chapter name");
      Assert
        (Refusal_Of ("# A" & LF & "## B" & LF & "### scene" & LF & "x" & LF)
         = "<loaded>", "H3 is chapter content");
      Scratch_Dirs.Remove (Root);
   end A_Single_File_Book_Must_Be_One_H1_Then_H2_Chapters;

   procedure A_Bad_Index_Is_Refused
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : constant String := Scratch_Dirs.Make ("manuscript-index");

      function Refusal_Of (Index : String) return String is
      begin
         Put (Root, "index.md", Index);
         return Refusal (Root);
      end Refusal_Of;
   begin
      Put (Root, "ok.md", "# T" & LF & "## C" & LF);
      Assert (Refusal_Of ("1. ok.md" & LF) = "<loaded>", "a good index");
      Assert (Has (Refusal_Of ("- ok.md" & LF), "not an ordered list item"),
              "a bullet is not numbered");
      Assert (Has (Refusal_Of ("ok.md" & LF), "not an ordered list item"),
              "a bare path");
      Assert (Has (Refusal_Of ("1. missing.md" & LF), "does not exist"),
              "missing path");
      Assert (Has (Refusal_Of ("1. ../ok.md" & LF), "not a path inside"),
              "leaves the folder");
      Assert (Has (Refusal_Of ("1. /etc/passwd" & LF), "not a path inside"),
              "absolute path");
      Assert (Has (Refusal_Of (LF), "lists no paths"), "empty index");
      Ada.Directories.Delete_File (Root & "/index.md");
      Assert (Has (Refusal (Root), "needs an index.md"), "no index");
      Assert (Has (Refusal (Root & "/nowhere"), "not a folder"),
              "no such root");
      Scratch_Dirs.Remove (Root);
   end A_Bad_Index_Is_Refused;

   procedure A_Book_Folder_Needs_Its_Own_Index
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : constant String := Scratch_Dirs.Make ("manuscript-folder");
   begin
      Put (Root, "index.md", "1. book/" & LF);
      Put (Root, "book/one.md", "text" & LF);
      Assert (Has (Refusal (Root), "needs an index.md"), "no folder index");
      Put (Root, "book/index.md", "1. two.md" & LF);
      Assert (Has (Refusal (Root), "'two.md' is not a file"),
              "a listed chapter that is missing");
      Scratch_Dirs.Remove (Root);
   end A_Book_Folder_Needs_Its_Own_Index;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Manuscript");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Unslugify_Makes_A_Title_From_A_Name'Access,
         "Unslugify turns a file or folder name into a title");
      Register_Routine
        (T, A_Series_Lists_Folder_And_File_Books_In_Index_Order'Access,
         "a series lists folder and single-file books in index order");
      Register_Routine
        (T, A_Single_File_Book_Must_Be_One_H1_Then_H2_Chapters'Access,
         "a single-file book must be one H1 followed by H2 chapters");
      Register_Routine
        (T, A_Bad_Index_Is_Refused'Access,
         "a missing, malformed or escaping index is refused");
      Register_Routine
        (T, A_Book_Folder_Needs_Its_Own_Index'Access,
         "a book folder needs its own index listing real files");
   end Register_Tests;

end Synapse_Bard.Manuscript.Tests;
