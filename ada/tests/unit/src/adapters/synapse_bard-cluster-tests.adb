with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse_Bard.Graph_Store;

package body Synapse_Bard.Cluster.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   function Entry_Of (Slug, Path, Name : String) return Write_Entry is
     (Slug => To_Unbounded_String (Slug), Path => To_Unbounded_String (Path),
      Name => To_Unbounded_String (Name));

   function One (Item : Write_Entry) return Write_Entry_Vectors.Vector is
      Result : Write_Entry_Vectors.Vector;
   begin
      Result.Append (Item);
      return Result;
   end One;

   function Contains (Text, Part : String) return Boolean is
     (for some I in Text'First .. Text'Last - Part'Length + 1 =>
        Text (I .. I + Part'Length - 1) = Part);

   Noted : constant String :=
     L ("---") & L ("title: ""X""") & L ("sources:") & L ("---") & LF
     & L ("<!-- synapse:generated:start -->") & L ("## Entities")
     & L ("<!-- synapse:generated:end -->") & LF & L ("## Notes")
     & L ("Hand-written.");

   procedure Put
     (S : in out Synapse_Bard.Graph_Store.Graph_Store; Node, Content : String)
   is
      Result : constant Synapse_Bard.Graph_Store.Port.Write_Result :=
        S.Write (Node, Content);
   begin
      pragma Assert (Result.Accepted);
   end Put;

   function Maybe (Text : String) return Maybe_Text is
     (Synapse.Core.Optional_Text.Of_Value (To_Unbounded_String (Text)));

   procedure Round_Trip_Through_Parse_Sources
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Entries : Write_Entry_Vectors.Vector;
   begin
      Entries.Append
        (Entry_Of ("gadget", "parts/spares/Gadget/gadget.md", "Gadget"));
      Entries.Append
        (Entry_Of ("widget-two", "parts/spares/Widget Two/widget-two.md",
                   "Widget Two"));
      declare
         Parsed : constant Source_Entry_Vectors.Vector :=
           Parse_Sources
             (Render_Cluster_Body ("Parts - Spares", Entries, ""));
      begin
         Assert (Natural (Parsed.Length) = 2, "two entries");
         Assert (To_String (Parsed (1).Slug) = "gadget", "first slug");
         Assert
           (To_String (Parsed (1).Path) = "parts/spares/Gadget/gadget.md",
            "first path");
         Assert (To_String (Parsed (2).Slug) = "widget-two", "second slug");
         Assert
           (To_String (Parsed (2).Path) =
              "parts/spares/Widget Two/widget-two.md",
            "second path, spaces kept");
      end;
   end Round_Trip_Through_Parse_Sources;

   procedure Generated_Region_Names_Members_Wikilinked
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String :=
        Render_Cluster_Body
          ("Parts - Main",
           One (Entry_Of ("widget-one", "parts/main/widget-one.md",
                          "Widget One")),
           "");
   begin
      Assert (Contains (Text, "## Entities"), "heading");
      Assert (Contains (Text, "[[widget-one]]"), "wikilink");
      Assert (Contains (Text, "Widget One"), "name");
      Assert
        (Contains
           (Text,
            "- [[widget-one]] " & Character'Val (16#E2#)
            & Character'Val (16#80#) & Character'Val (16#94#)
            & " Widget One"),
         "the bullet has an em dash between link and name");
   end Generated_Region_Names_Members_Wikilinked;

   procedure Preserved_Tail_Is_After_The_End_Marker
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Preserved_Tail (Noted) = LF & L ("## Notes") & L ("Hand-written."),
         "everything after the marker");
   end Preserved_Tail_Is_After_The_End_Marker;

   procedure Preserved_Tail_Is_Empty_Without_A_Marker
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Preserved_Tail (L ("---") & L ("title: ""X""") & L ("---")) = "",
         "no marker, no tail");
   end Preserved_Tail_Is_Empty_Without_A_Marker;

   procedure Generated_Region_Complements_The_Tail
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Generated : constant String := Generated_Region (Noted);
   begin
      Assert
        (Generated =
           L ("---") & L ("title: ""X""") & L ("sources:") & L ("---") & LF
           & L ("<!-- synapse:generated:start -->") & L ("## Entities")
           & L ("<!-- synapse:generated:end -->"),
         "up to and including the marker");
      Assert
        (Generated'Length + Preserved_Tail (Noted)'Length = Noted'Length,
         "the two reassemble the whole body");
   end Generated_Region_Complements_The_Tail;

   procedure Generated_Region_Is_The_Whole_Body_Without_A_Marker
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Text : constant String := L ("---") & L ("title: ""X""") & L ("---");
   begin
      Assert (Generated_Region (Text) = Text, "nothing to segregate");
   end Generated_Region_Is_The_Whole_Body_Without_A_Marker;

   procedure Is_Dirty_When_There_Is_No_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Computed : constant String :=
        Render_Cluster_Body ("A", One (Entry_Of ("a", "a.md", "A")), "");
   begin
      Assert
        (Is_Dirty (Synapse.Core.Optional_Text.None, Computed),
         "a cluster that would be newly created");
   end Is_Dirty_When_There_Is_No_File;

   procedure Is_Not_Dirty_When_The_Region_Matches
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Computed : constant String :=
        Render_Cluster_Body ("A", One (Entry_Of ("a", "a.md", "A")), "");
   begin
      Assert (not Is_Dirty (Maybe (Computed), Computed), "identical");
   end Is_Not_Dirty_When_The_Region_Matches;

   procedure Is_Dirty_When_The_Region_Differs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Old_Body : constant String :=
        Render_Cluster_Body ("A", One (Entry_Of ("a", "a.md", "A")), "");
      New_Body : constant String :=
        Render_Cluster_Body
          ("A", One (Entry_Of ("a", "a-renamed.md", "A")), "");
   begin
      Assert (Is_Dirty (Maybe (Old_Body), New_Body), "a path changed");
   end Is_Dirty_When_The_Region_Differs;

   procedure Is_Not_Dirty_When_Only_The_Tail_Differs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Entries   : constant Write_Entry_Vectors.Vector :=
        One (Entry_Of ("a", "a.md", "A"));
      No_Tail   : constant String := Render_Cluster_Body ("A", Entries, "");
      With_Tail : constant String :=
        Render_Cluster_Body
          ("A", Entries, LF & L ("## Notes") & L ("Hand-written."));
   begin
      Assert (No_Tail /= With_Tail, "the files differ");
      Assert (not Is_Dirty (Maybe (With_Tail), No_Tail), "but not as drift");
   end Is_Not_Dirty_When_Only_The_Tail_Differs;

   function Names (A, B, C : String) return Synapse.Core.Text_Lists.Vector is
      Items  : constant array (1 .. 3) of Unbounded_String :=
        [To_Unbounded_String (A), To_Unbounded_String (B),
         To_Unbounded_String (C)];
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for Item of Items loop
         if Item /= "" then
            Result.Append (Item);
         end if;
      end loop;
      return Result;
   end Names;

   procedure Would_Remove_Lists_Only_Absent_Nodes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Removed : constant Synapse.Core.Text_Lists.Vector :=
        Would_Remove
          (Names ("A.md", "B.md", "C.md"), Names ("A.md", "C.md", ""));
   begin
      Assert (Natural (Removed.Length) = 1, "one node");
      Assert (To_String (Removed (1)) = "B.md", "B");
   end Would_Remove_Lists_Only_Absent_Nodes;

   procedure Would_Remove_Is_Empty_When_All_Are_Planned
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Would_Remove
           (Names ("A.md", "", ""), Names ("A.md", "", "")).Is_Empty,
         "nothing to remove");
   end Would_Remove_Is_Empty_When_All_Are_Planned;

   procedure A_Tail_Is_Kept_Verbatim_After_The_Marker
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Tail : constant String := LF & L ("## Notes") & L ("Keep me.");
      Text : constant String :=
        Render_Cluster_Body ("A", One (Entry_Of ("a", "a.md", "A")), Tail);
   begin
      Assert
        (Text'Length >= Tail'Length
         and then Text (Text'Last - Tail'Length + 1 .. Text'Last) = Tail,
         "ends with the tail");
   end A_Tail_Is_Kept_Verbatim_After_The_Marker;

   procedure Resolve_Slug_Scans_Every_Node
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("cluster-resolve");
      S   : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (Dir & "/graph");
   begin
      Put (S, "Places.md",
         Render_Cluster_Body
           ("Places", One (Entry_Of ("a", "places/a.md", "A")), ""));
      Put (S, "Items.md",
         Render_Cluster_Body
           ("Items", One (Entry_Of ("b", "items/b.md", "B")), ""));
      declare
         Found : constant Source_Entry_Options.Option :=
           Resolve_Slug (S, "b");
      begin
         Assert (Found.Found, "b is claimed by a cluster");
         Assert (To_String (Found.Value.Path) = "items/b.md", "its path");
      end;
      Assert
        (not Resolve_Slug (S, "nonexistent").Found, "no cluster claims it");
      Scratch_Dirs.Remove (Dir);
   end Resolve_Slug_Scans_Every_Node;

   procedure All_Entities_Aggregates_Every_Node
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir : constant String := Scratch_Dirs.Make ("cluster-all");
      S   : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (Dir & "/graph");
      Places  : Write_Entry_Vectors.Vector;
   begin
      Places.Append (Entry_Of ("a1", "places/a1.md", "A1"));
      Places.Append (Entry_Of ("a2", "places/a2.md", "A2"));
      Put (S, "Places.md", Render_Cluster_Body ("Places", Places, ""));
      Put (S, "Items.md",
         Render_Cluster_Body
           ("Items", One (Entry_Of ("b1", "items/b1.md", "B1")), ""));
      Assert (Natural (All_Entities (S).Length) = 3, "three entities");
      Scratch_Dirs.Remove (Dir);
   end All_Entities_Aggregates_Every_Node;

   procedure Cluster_Title_Joins_Segments
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Cluster_Title ("parts/spares") = "Parts - Spares", "two segments");
      Assert
        (Cluster_Title ("world/countries/Dominion") =
           "World - Countries - Dominion",
         "a capitalised segment passes through");
      Assert
        (Cluster_Title ("places/Dominion/Held - Borderlands") =
           "Places - Dominion - Held - Borderlands",
         "internal punctuation passes through");
      Assert (Cluster_Title ("items") = "Items", "one segment");
      Assert (Cluster_Title ("a/b:c") = "A - B_c", "illegal characters");
   end Cluster_Title_Joins_Segments;

   procedure A_Node_Without_Sources_Has_No_Entries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Parse_Sources
           (L ("---") & L ("title: ""Empty""") & L ("---")).Is_Empty,
         "zero entries, not an error");
   end A_Node_Without_Sources_Has_No_Entries;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Cluster");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Round_Trip_Through_Parse_Sources'Access,
         "Render_Cluster_Body round-trips through Parse_Sources");
      Register_Routine
        (T, Generated_Region_Names_Members_Wikilinked'Access,
         "the generated region names each member, wikilinked");
      Register_Routine
        (T, Preserved_Tail_Is_After_The_End_Marker'Access,
         "Preserved_Tail returns everything after the end marker");
      Register_Routine
        (T, Preserved_Tail_Is_Empty_Without_A_Marker'Access,
         "Preserved_Tail is empty without an end marker");
      Register_Routine
        (T, Generated_Region_Complements_The_Tail'Access,
         "Generated_Region is the tail's complement");
      Register_Routine
        (T, Generated_Region_Is_The_Whole_Body_Without_A_Marker'Access,
         "Generated_Region is the whole body without an end marker");
      Register_Routine
        (T, Is_Dirty_When_There_Is_No_File'Access,
         "Is_Dirty is true when there is no existing file");
      Register_Routine
        (T, Is_Not_Dirty_When_The_Region_Matches'Access,
         "Is_Dirty is false when the generated region matches");
      Register_Routine
        (T, Is_Dirty_When_The_Region_Differs'Access,
         "Is_Dirty is true when the generated region differs");
      Register_Routine
        (T, Is_Not_Dirty_When_Only_The_Tail_Differs'Access,
         "Is_Dirty is false when only the human-owned tail differs");
      Register_Routine
        (T, Would_Remove_Lists_Only_Absent_Nodes'Access,
         "Would_Remove lists only existing nodes absent from the plan");
      Register_Routine
        (T, Would_Remove_Is_Empty_When_All_Are_Planned'Access,
         "Would_Remove is empty when the plan covers everything");
      Register_Routine
        (T, A_Tail_Is_Kept_Verbatim_After_The_Marker'Access,
         "a re-render with a tail keeps it verbatim after the marker");
      Register_Routine
        (T, Resolve_Slug_Scans_Every_Node'Access,
         "Resolve_Slug scans every node and finds the first match");
      Register_Routine
        (T, All_Entities_Aggregates_Every_Node'Access,
         "All_Entities aggregates every node's sources");
      Register_Routine
        (T, Cluster_Title_Joins_Segments'Access,
         "Cluster_Title joins segments with ' - ', capitalising a lowercase "
         & "first letter");
      Register_Routine
        (T, A_Node_Without_Sources_Has_No_Entries'Access,
         "a node with no sources field parses as zero entries");
   end Register_Tests;

end Synapse_Bard.Cluster.Tests;
