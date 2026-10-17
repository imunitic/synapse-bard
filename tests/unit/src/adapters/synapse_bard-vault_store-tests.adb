with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;

package body Synapse_Bard.Vault_Store.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   --  Runs Check against a store over a fresh, not yet created directory.
   generic
      with procedure Check (S : in out Vault_Store; Dir : String);
      Label : String;
   procedure With_Store;

   procedure With_Store is
      Dir : constant String := Scratch_Dirs.Make (Label);
      S   : Vault_Store := Create (Dir & "/vault");
   begin
      Check (S, Dir);
      Scratch_Dirs.Remove (Dir);
   exception
      when others =>
         Scratch_Dirs.Remove (Dir);
         raise;
   end With_Store;

   procedure Put (S : in out Vault_Store; Node, Content : String) is
      Result : constant Port.Write_Result := S.Write (Node, Content);
   begin
      pragma Assert (Result.Accepted);
   end Put;

   function Text_Of (Item : Port.Maybe_Text) return String is
     (if Item.Found then To_String (Item.Value) else "<none>");

   function Contains
     (List : Synapse.Core.Text_Lists.Vector; Item : String) return Boolean is
     (for some E of List => To_String (E) = Item);

   ---------------------------------------------------------------------------
   --  Checks
   ---------------------------------------------------------------------------

   procedure Check_Nested_Round_Trip (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Put (S, "designs/widgets/Parts-catalog.md", L ("# Parts-catalog"));
      Assert
        (Text_Of (S.Read ("designs/widgets/Parts-catalog.md")) =
           L ("# Parts-catalog"),
         "read back from the subdirectory");
   end Check_Nested_Round_Trip;

   procedure Check_Missing (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Assert (not S.Read ("absent.md").Found, "a missing node is none");
   end Check_Missing;

   procedure Check_List (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Put (S, "Index.md", L ("# Index"));
      Put (S, "designs/a.md", L ("a"));
      Put (S, "tasks/widgets/widgets-001.md", L ("task"));
      declare
         Names : constant Synapse.Core.Text_Lists.Vector := S.List;
      begin
         Assert (Natural (Names.Length) = 2, "two notes");
         Assert (Contains (Names, "designs/a.md"), "the design");
         Assert (Contains (Names, "tasks/widgets/widgets-001.md"), "the task");
      end;
   end Check_List;

   procedure Check_Ranking (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      --  Two notes link to `popular` and none to `lonely`; both mention the
      --  query, so only the ranking separates them.
      Put (S, "popular.md", L ("# Popular") & L ("mentions the brass cog"));
      Put (S, "lonely.md", L ("# Lonely") & L ("also mentions the brass cog"));
      Put (S, "a.md", L ("links to [[popular]]"));
      Put
        (S, "b.md",
         L ("links to [[popular|Popular Note]] and again [[popular]]"));
      declare
         Hits : constant Port.Hit_Vectors.Vector := S.Search ("brass cog");
      begin
         Assert (Natural (Hits.Length) = 2, "two hits");
         Assert
           (To_String (Hits (1).Node) = "popular.md", "most linked first");
         Assert (Hits (1).Score = 2.0, "a and b, b counted once");
         Assert (To_String (Hits (2).Node) = "lonely.md", "then the other");
         Assert (Hits (2).Score = 0.0, "nothing links to it");
         Assert
           (To_String (Hits (1).Context) = "mentions the brass cog",
            "the matching line");
      end;
   end Check_Ranking;

   procedure Check_Linking_By_Stem (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Put (S, "designs/target.md", L ("# Target"));
      Put (S, "a.md", L ("links to [[target]]"));
      Put (S, "b.md", L ("links to [[target|Target Note]]"));
      Put (S, "c.md", L ("no link here"));
      declare
         By_Stem : constant Note_List_Options.Option :=
           S.Linking_Notes ("target");
         By_Path : constant Note_List_Options.Option :=
           S.Linking_Notes ("designs/target.md");
      begin
         Assert (By_Stem.Found, "the stem resolves");
         Assert (Natural (By_Stem.Value.Length) = 2, "two linking notes");
         Assert (To_String (By_Stem.Value (1)) = "a.md", "a first");
         Assert (To_String (By_Stem.Value (2)) = "b.md", "then b");
         Assert (By_Path.Found, "the path resolves");
         Assert (Natural (By_Path.Value.Length) = 2, "to the same note");
      end;
   end Check_Linking_By_Stem;

   procedure Check_No_Backlinks (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Put (S, "lonely.md", L ("# Lonely, nobody links here"));
      declare
         Notes : constant Note_List_Options.Option :=
           S.Linking_Notes ("lonely");
      begin
         Assert (Notes.Found, "a real note");
         Assert (Notes.Value.Is_Empty, "with no backlinks");
      end;
   end Check_No_Backlinks;

   procedure Check_Unknown_Target (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Assert
        (not S.Linking_Notes ("nonexistent").Found,
         "a name that resolves to no note");
   end Check_Unknown_Target;

   procedure Check_Self_Link_Not_Listed (S : in out Vault_Store; Dir : String)
   is
      pragma Unreferenced (Dir);
   begin
      Put (S, "self.md", L ("links to [[self]]"));
      Assert (S.Linking_Notes ("self").Value.Is_Empty, "not its own linker");
   end Check_Self_Link_Not_Listed;

   procedure Check_Self_Link_Not_Counted (S : in out Vault_Store; Dir : String)
   is
      pragma Unreferenced (Dir);
   begin
      Put (S, "self.md", L ("mentions the brass cog and links to [[self]]"));
      declare
         Hits : constant Port.Hit_Vectors.Vector := S.Search ("brass cog");
      begin
         Assert (Natural (Hits.Length) = 1, "one hit");
         Assert (Hits (1).Score = 0.0, "a note is not its own backlink");
      end;
   end Check_Self_Link_Not_Counted;

   procedure Check_Case_Folded_Links (S : in out Vault_Store; Dir : String) is
      pragma Unreferenced (Dir);
   begin
      Put
        (S, "designs/Parts-catalog.md",
         L ("# Parts-catalog") & L ("mentions the brass cog"));
      --  The link spells the title in a different case than the file.
      Put (S, "a.md", L ("links to [[Parts-Catalog]]"));
      declare
         Hits  : constant Port.Hit_Vectors.Vector := S.Search ("brass cog");
         Notes : constant Note_List_Options.Option :=
           S.Linking_Notes ("Parts-catalog");
      begin
         Assert (Natural (Hits.Length) = 1, "one hit");
         Assert
           (To_String (Hits (1).Node) = "designs/Parts-catalog.md",
            "the note");
         Assert (Hits (1).Score = 1.0, "linked despite the case");
         Assert (Notes.Found, "resolved");
         Assert (Natural (Notes.Value.Length) = 1, "one linking note");
         Assert (To_String (Notes.Value (1)) = "a.md", "a");
      end;
   end Check_Case_Folded_Links;

   procedure Check_Atomic_Write (S : in out Vault_Store; Dir : String) is
      Count : Natural := 0;
      Item  : Ada.Directories.Search_Type;
      Found : Ada.Directories.Directory_Entry_Type;
   begin
      Put (S, "designs/a.md", L ("first"));
      Put (S, "designs/a.md", L ("second"));
      Assert (Text_Of (S.Read ("designs/a.md")) = L ("second"), "replaced");
      Ada.Directories.Start_Search
        (Item, Dir & "/vault/designs", "",
         [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Item) loop
         Ada.Directories.Get_Next_Entry (Item, Found);
         Count := Count + 1;
      end loop;
      Ada.Directories.End_Search (Item);
      Assert (Count = 1, "no temporary file is left beside the note");
   end Check_Atomic_Write;

   ---------------------------------------------------------------------------
   --  Registration
   ---------------------------------------------------------------------------

   procedure Run_Nested is new With_Store
     (Check_Nested_Round_Trip, "v-nested");
   procedure Run_Missing is new With_Store (Check_Missing, "v-missing");
   procedure Run_List is new With_Store (Check_List, "v-list");
   procedure Run_Ranking is new With_Store (Check_Ranking, "v-ranking");
   procedure Run_Stem is new With_Store (Check_Linking_By_Stem, "v-stem");
   procedure Run_None is new With_Store (Check_No_Backlinks, "v-none");
   procedure Run_Unknown is new With_Store (Check_Unknown_Target, "v-unknown");
   procedure Run_Self_List is new With_Store
     (Check_Self_Link_Not_Listed, "v-self-list");
   procedure Run_Self_Count is new With_Store
     (Check_Self_Link_Not_Counted, "v-self-count");
   procedure Run_Case is new With_Store (Check_Case_Folded_Links, "v-case");
   procedure Run_Atomic is new With_Store (Check_Atomic_Write, "v-atomic");

   procedure Nested (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Nested;
   end Nested;

   procedure Missing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Missing;
   end Missing;

   procedure Listing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_List;
   end Listing;

   procedure Ranking (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Ranking;
   end Ranking;

   procedure By_Stem (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Stem;
   end By_Stem;

   procedure No_Backlinks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_None;
   end No_Backlinks;

   procedure Unknown (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Unknown;
   end Unknown;

   procedure Self_Listed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Self_List;
   end Self_Listed;

   procedure Self_Counted (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Self_Count;
   end Self_Counted;

   procedure Case_Folded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Case;
   end Case_Folded;

   procedure Atomic (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Atomic;
   end Atomic;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Vault_Store");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Nested'Access,
         "write then read round-trips a note nested under a subdirectory");
      Register_Routine
        (T, Missing'Access, "a missing node reads as none, not as an error");
      Register_Routine
        (T, Listing'Access,
         "list walks subdirectories and excludes the vault's own Index.md");
      Register_Routine
        (T, Ranking'Access,
         "search ranks matching notes by backlink count, most-linked first");
      Register_Routine
        (T, By_Stem'Access,
         "Linking_Notes lists every note that links to the target, by stem");
      Register_Routine
        (T, No_Backlinks'Access,
         "Linking_Notes is empty, not none, for a note with no backlinks");
      Register_Routine
        (T, Unknown'Access,
         "Linking_Notes is none for a name that resolves to no note");
      Register_Routine
        (T, Self_Listed'Access,
         "Linking_Notes excludes a note linking to itself");
      Register_Routine
        (T, Self_Counted'Access, "a note does not count as its own backlink");
      Register_Routine
        (T, Case_Folded'Access,
         "a wikilink resolves to its target despite differing case");
      Register_Routine
        (T, Atomic'Access,
         "a write is atomic: no temporary file survives an overwrite");
   end Register_Tests;

end Synapse_Bard.Vault_Store.Tests;
