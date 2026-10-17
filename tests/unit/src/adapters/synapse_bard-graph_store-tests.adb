with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;

package body Synapse_Bard.Graph_Store.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   --  Runs Check against a store over a fresh, not yet created directory.
   generic
      with procedure Check (S : in out Graph_Store; Dir : String);
      Label : String;
   procedure With_Store;

   procedure With_Store is
      Dir : constant String := Scratch_Dirs.Make (Label);
      S   : Graph_Store := Create (Dir & "/graph");
   begin
      Check (S, Dir);
      Scratch_Dirs.Remove (Dir);
   exception
      when others =>
         Scratch_Dirs.Remove (Dir);
         raise;
   end With_Store;

   function Text_Of (Item : Port.Maybe_Text) return String is
     (if Item.Found then To_String (Item.Value) else "<none>");

   procedure Ignore (Item : Port.Write_Result) is null;

   ---------------------------------------------------------------------------
   --  Tests
   ---------------------------------------------------------------------------

   procedure Check_Round_Trip (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore
        (S.Write
           ("widget-one.md", L ("---") & L ("name: Widget") & L ("---")));
      Assert
        (Text_Of (S.Read ("widget-one.md")) =
           L ("---") & L ("name: Widget") & L ("---"),
         "what was written is read back");
   end Check_Round_Trip;

   procedure Check_Missing_Node (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Assert (not S.Read ("absent.md").Found, "a missing node is none");
   end Check_Missing_Node;

   procedure Check_Empty_Listing (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Assert (S.List.Is_Empty, "a graph never written to lists as empty");
   end Check_Empty_Listing;

   procedure Check_Rewrite (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore (S.Write ("n.md", "first"));
      Ignore (S.Write ("n.md", "second"));
      Assert (Text_Of (S.Read ("n.md")) = "second", "replaced");
      declare
         Names : constant Synapse.Core.Text_Lists.Vector := S.List;
      begin
         Assert (Natural (Names.Length) = 1, "one node");
         Assert (To_String (Names (1)) = "n.md", "its name");
      end;
   end Check_Rewrite;

   procedure Check_Delete (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore (S.Write ("a.md", "a"));
      Ignore (S.Write ("b.md", "b"));
      S.Delete ("a.md");
      Assert (not S.Read ("a.md").Found, "a is gone");
      declare
         Names : constant Synapse.Core.Text_Lists.Vector := S.List;
      begin
         Assert (Natural (Names.Length) = 1, "one node left");
         Assert (To_String (Names (1)) = "b.md", "b");
      end;
   end Check_Delete;

   procedure Check_Delete_Missing (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      S.Delete ("never-existed.md");
      Assert (True, "no error");
   end Check_Delete_Missing;

   procedure Check_Only_Markdown (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore (S.Write ("a.md", "a"));
      Ignore (S.Write ("notes.txt", "not an entity"));
      declare
         Names : constant Synapse.Core.Text_Lists.Vector := S.List;
      begin
         Assert (Natural (Names.Length) = 1, "one node");
         Assert (To_String (Names (1)) = "a.md", "the .md file");
      end;
   end Check_Only_Markdown;

   procedure Check_Full_Text (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore
        (S.Write
           ("a.md",
            L ("---") & L ("name: A") & L ("---")
            & L ("mentions the Brass Cog")));
      Ignore
        (S.Write
           ("b.md",
            L ("---") & L ("name: B") & L ("---")
            & L ("mentions nothing relevant")));
      declare
         Hits : constant Port.Hit_Vectors.Vector := S.Search ("brass cog");
      begin
         Assert (Natural (Hits.Length) = 1, "one hit");
         Assert (To_String (Hits (1).Node) = "a.md", "the node");
         Assert
           (To_String (Hits (1).Context) = "mentions the Brass Cog",
            "the matching line");
         Assert (Hits (1).Score = 1.0, "one occurrence");
      end;
   end Check_Full_Text;

   procedure Check_Field_Query (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore
        (S.Write
           ("widget.md",
            L ("---") & L ("name: Widget")
            & L ("workshop: ""The Brass Workshop""") & L ("---")));
      Ignore
        (S.Write
           ("gadget.md",
            L ("---") & L ("name: Gadget")
            & L ("workshop: ""The Workshop""") & L ("---")));
      declare
         Hits : constant Port.Hit_Vectors.Vector :=
           S.Search ("workshop:the brass workshop");
      begin
         Assert (Natural (Hits.Length) = 1, "one hit");
         Assert (To_String (Hits (1).Node) = "widget.md", "the node");
      end;
   end Check_Field_Query;

   procedure Check_Key_Case (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Ignore
        (S.Write
           ("widget.md",
            L ("---") & L ("name: Widget")
            & L ("workshop: ""The Brass Workshop""") & L ("---")));
      Assert
        (S.Search ("Workshop:The Brass Workshop").Is_Empty,
         "only the value is case-insensitive");
   end Check_Key_Case;

   procedure Check_Colon_In_Text (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      --  A single-string query cannot tell a title with a colon from a field
      --  filter; the command line uses Field_Line directly in its own modes.
      Ignore
        (S.Write
           ("book.md",
            L ("---") & L ("name: Note") & L ("---")
            & L ("The Manual: Volume One is the favorite.")));
      Assert
        (S.Search ("The Manual: Volume One").Is_Empty,
         "read as a field query, so no hit");
   end Check_Colon_In_Text;

   procedure Check_Atomic_Write (S : in out Graph_Store; Dir : String) is
      Count : Natural := 0;
      Item  : Ada.Directories.Search_Type;
      Found : Ada.Directories.Directory_Entry_Type;
   begin
      Ignore (S.Write ("widget.md", L ("first")));
      Ignore (S.Write ("widget.md", L ("second")));
      Assert (Text_Of (S.Read ("widget.md")) = L ("second"), "replaced");
      Ada.Directories.Start_Search
        (Item, Dir & "/graph", "",
         [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Item) loop
         Ada.Directories.Get_Next_Entry (Item, Found);
         Count := Count + 1;
      end loop;
      Ada.Directories.End_Search (Item);
      Assert (Count = 1, "no temporary file is left beside the node");
   end Check_Atomic_Write;

   procedure Check_Field_Line (S : in out Graph_Store; Dir : String) is
      pragma Unreferenced (S, Dir);
      Note : constant String :=
        L ("---") & L ("name: Widget") & L ("workshop: 'Brass'")
        & L ("  workshop: nested") & L ("---") & L ("workshop: Brass");
   begin
      Assert
        (Field_Line (Note, "workshop", "BRASS").Found, "unquoted, any case");
      Assert (not Field_Line (Note, "workshop", "Tin").Found, "other value");
      Assert (not Field_Line (Note, "Workshop", "Brass").Found, "key case");
      Assert
        (not Field_Line (L ("---") & L ("---") & L ("workshop: Brass"),
                         "workshop", "Brass").Found,
         "not past the closing fence");
   end Check_Field_Line;

   ---------------------------------------------------------------------------
   --  Registration
   ---------------------------------------------------------------------------

   procedure Run_Round_Trip is new With_Store (Check_Round_Trip, "round-trip");
   procedure Run_Missing is new With_Store (Check_Missing_Node, "missing");
   procedure Run_Empty is new With_Store (Check_Empty_Listing, "empty");
   procedure Run_Rewrite is new With_Store (Check_Rewrite, "rewrite");
   procedure Run_Delete is new With_Store (Check_Delete, "delete");
   procedure Run_Delete_Missing is new With_Store
     (Check_Delete_Missing, "delete-missing");
   procedure Run_Markdown is new With_Store (Check_Only_Markdown, "markdown");
   procedure Run_Full_Text is new With_Store (Check_Full_Text, "full-text");
   procedure Run_Field is new With_Store (Check_Field_Query, "field");
   procedure Run_Key_Case is new With_Store (Check_Key_Case, "key-case");
   procedure Run_Colon is new With_Store (Check_Colon_In_Text, "colon");
   procedure Run_Atomic is new With_Store (Check_Atomic_Write, "atomic");
   procedure Run_Field_Line is new With_Store (Check_Field_Line, "field-line");

   procedure Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Round_Trip;
   end Round_Trip;

   procedure Missing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Missing;
   end Missing;

   procedure Empty (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Empty;
   end Empty;

   procedure Rewrite (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Rewrite;
   end Rewrite;

   procedure Delete_Node (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Delete;
   end Delete_Node;

   procedure Delete_Absent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Delete_Missing;
   end Delete_Absent;

   procedure Markdown_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Markdown;
   end Markdown_Only;

   procedure Full_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Full_Text;
   end Full_Text;

   procedure Field_Query_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Field;
   end Field_Query_Test;

   procedure Key_Case_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Key_Case;
   end Key_Case_Test;

   procedure Colon_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Colon;
   end Colon_Test;

   procedure Atomic_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Atomic;
   end Atomic_Test;

   procedure Field_Line_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Field_Line;
   end Field_Line_Test;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Graph_Store");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Round_Trip'Access, "write then read round-trips through the port");
      Register_Routine
        (T, Missing'Access, "a missing node reads as none, not as an error");
      Register_Routine
        (T, Empty'Access, "listing a graph never written to is empty");
      Register_Routine
        (T, Rewrite'Access,
         "rewriting a node replaces it, and list reflects what was written");
      Register_Routine
        (T, Delete_Node'Access,
         "delete removes a node, and it stops showing up in read and list");
      Register_Routine
        (T, Delete_Absent'Access,
         "delete on a node that does not exist is not an error");
      Register_Routine
        (T, Markdown_Only'Access,
         "list only sees .md files, not other files in the directory");
      Register_Routine
        (T, Full_Text'Access,
         "full-text search finds a substring by content, ignoring case");
      Register_Routine
        (T, Field_Query_Test'Access,
         "a key:value query matches the key exactly and the value ignoring "
         & "case");
      Register_Routine
        (T, Key_Case_Test'Access,
         "a key:value query does not match a differently cased key");
      Register_Routine
        (T, Colon_Test'Access,
         "a colon in ordinary text reads as a field query: known");
      Register_Routine
        (T, Atomic_Test'Access,
         "a write is atomic: no temporary file survives an overwrite");
      Register_Routine
        (T, Field_Line_Test'Access,
         "Field_Line matches the key exactly, the value unquoted, in the "
         & "frontmatter only");
   end Register_Tests;

end Synapse_Bard.Graph_Store.Tests;
