with Ada.Directories;
with Ada.Strings.Unbounded;

with AUnit.Assertions;

with Scratch_Dirs;
with Synapse.Adapters.File_Bytes;

package body Synapse_Bard.Sync_Plan.Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   LF : constant String := [Character'Val (10)];

   function L (Text : String) return String is (Text & LF);

   function Entity (Name : String) return String is
     (L ("---") & L ("name: " & Name) & L ("template: widget") & L ("---"));

   --  Writes Content at Root/Rel, creating the directories it needs.
   procedure Put_File (Root, Rel, Content : String) is
      Path : constant String := Root & "/" & Rel;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Synapse.Adapters.File_Bytes.Write (Path, Content);
   end Put_File;

   function Contains (Text, Part : String) return Boolean is
     (for some I in Text'First .. Text'Last - Part'Length + 1 =>
        Text (I .. I + Part'Length - 1) = Part);

   function Has_Line
     (List : Synapse.Core.Text_Lists.Vector; Line : String) return Boolean is
     (for some E of List => To_String (E) = Line);

   --  Runs Check over a fresh repository root with an empty graph store.
   generic
      with procedure Check
        (Root  : String;
         Store : in out Synapse_Bard.Graph_Store.Graph_Store);
      Label : String;
   procedure With_Repo;

   procedure With_Repo is
      Dir   : constant String := Scratch_Dirs.Make (Label);
      Store : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (Dir & "/_bard/graph");
   begin
      Check (Dir, Store);
      Scratch_Dirs.Remove (Dir);
   exception
      when others =>
         Scratch_Dirs.Remove (Dir);
         raise;
   end With_Repo;

   procedure Put
     (S       : in out Synapse_Bard.Graph_Store.Graph_Store;
      Node    : String;
      Content : String)
   is
      Result : constant Synapse_Bard.Graph_Store.Port.Write_Result :=
        S.Write (Node, Content);
   begin
      pragma Assert (Result.Accepted);
   end Put;

   function Node_At (P : Plan; Index : Positive) return String is
     (To_String (P.Clusters (Index).Node));

   ---------------------------------------------------------------------------
   --  Checks
   ---------------------------------------------------------------------------

   procedure Check_One_Cluster
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File (Root, "characters/a.md", Entity ("Alice"));
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert (P.Ingested = 1, "one ingested");
         Assert (P.Skipped = 0, "none skipped");
         Assert (P.Collisions = 0, "no collisions");
         Assert (Natural (P.Clusters.Length) = 1, "one cluster");
         Assert (Node_At (P, 1) = "Characters.md", "its node name");
         Assert
           (Contains (To_String (P.Clusters (1).Body_Text), "[[a]]"),
            "the member is wikilinked");
         Assert
           (Contains (To_String (P.Clusters (1).Body_Text), " Alice"),
            "named by its def tag");
      end;
   end Check_One_Cluster;

   procedure Check_Tail_Preserved
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File (Root, "characters/a.md", Entity ("Alice"));
      --  A node written by a prior `sync` and then edited by a person.
      Put
        (Store, "Characters.md",
         L ("---") & L ("title: ""Characters""") & L ("sources:")
         & L ("  - slug: ""a""") & L ("    path: ""characters/a.md""")
         & L ("---") & LF & L ("<!-- synapse:generated:start -->")
         & L ("## Entities") & L ("- [[a]] - Alice")
         & L ("<!-- synapse:generated:end -->") & LF & L ("## Notes")
         & L ("Keep me."));
      declare
         P    : constant Plan := Compute_Plan (Root, Store);
         Text : constant String := To_String (P.Clusters (1).Body_Text);
         Tail : constant String := LF & L ("## Notes") & L ("Keep me.");
      begin
         Assert (Natural (P.Clusters.Length) = 1, "one cluster");
         Assert
           (Text'Length >= Tail'Length
            and then Text (Text'Last - Tail'Length + 1 .. Text'Last) = Tail,
            "the body already ends with the existing tail");
      end;
   end Check_Tail_Preserved;

   procedure Check_Reconcile
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
      pragma Unreferenced (Root);
      Written : Synapse.Core.Text_Lists.Vector;
   begin
      Put (Store, "Stale.md", "stale");
      Put (Store, "Keep.md", "keep");
      Written.Append (To_Unbounded_String ("Keep.md"));
      Assert (Reconcile (Store, Written) = 1, "one node removed");
      Assert (not Store.Read ("Stale.md").Found, "the stale node is gone");
      Assert (Store.Read ("Keep.md").Found, "the produced node stays");
   end Check_Reconcile;

   procedure Check_Boundaries
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      --  A boundary with content nested below it: one cluster, no sub-cluster.
      Put_File (Root, "world/countries/Dominion/x.md", Entity ("X"));
      Put_File (Root, "world/countries/Dominion/regions/y.md", Entity ("Y"));
      --  A folder whose first content is two levels down.
      Put_File (Root, "places/Region/Town/t.md", Entity ("T"));
      --  A sibling with its own direct content.
      Put_File (Root, "world/magic/m.md", Entity ("M"));
      --  Never candidates: hidden and underscore folders, a loose root file,
      --  and a file that is not a note.
      Put_File (Root, "_planning/p.md", Entity ("P"));
      Put_File (Root, ".hidden/h.md", Entity ("H"));
      Put_File (Root, "README.md", Entity ("Readme"));
      Put_File (Root, "world/magic/notes.txt", "not a note");
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert (Natural (P.Clusters.Length) = 3, "three clusters");
         Assert (Node_At (P, 1) = "Places - Region - Town.md", "first");
         Assert
           (Node_At (P, 2) = "World - Countries - Dominion.md", "second");
         Assert (Node_At (P, 3) = "World - Magic.md", "third");
         Assert (P.Ingested = 4, "x, y, t and m");
         Assert
           (Contains (To_String (P.Clusters (2).Body_Text), "[[y]]"),
            "a note below the boundary belongs to its cluster");
         Assert (P.Skipped = 0, "nothing refused");
      end;
   end Check_Boundaries;

   procedure Check_Refused
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File (Root, "characters/good.md", Entity ("Good"));
      Put_File (Root, "characters/bad.md", L ("no frontmatter at all"));
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert (P.Ingested = 1, "one ingested");
         Assert (P.Skipped = 1, "one skipped");
         Assert
           (Has_Line
              (P.Report_Lines,
               "skipped (no_frontmatter): characters/bad.md" & LF),
            "the report line");
         Assert
           (not Contains (To_String (P.Clusters (1).Body_Text), "[[bad]]"),
            "the refused note is not a member");
      end;
   end Check_Refused;

   procedure Check_Collision
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File (Root, "characters/a.md", Entity ("First"));
      Put_File (Root, "places/a.md", Entity ("Second"));
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert (P.Collisions = 1, "one collision");
         Assert (P.Ingested = 1, "one ingested");
         Assert
           (Has_Line
              (P.Report_Lines,
               "COLLISION: characters/a.md and places/a.md both resolve to "
               & "slug 'a' -- kept characters/a.md, skipped places/a.md"
               & LF),
            "the report line");
         Assert
           (Natural (P.Clusters.Length) = 1, "the second cluster is empty");
         Assert (Node_At (P, 1) = "Characters.md", "the first claimant stays");
      end;
   end Check_Collision;

   procedure Check_All_Refused
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File (Root, "characters/bad.md", L ("prose only"));
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert
           (P.Clusters.Is_Empty, "a cluster with no member is not written");
         Assert (P.Skipped = 1, "counted as skipped");
      end;
   end Check_All_Refused;

   procedure Check_Name_Fallback
     (Root  : String;
      Store : in out Synapse_Bard.Graph_Store.Graph_Store)
   is
   begin
      Put_File
        (Root, "items/b.md", L ("---") & L ("template: item") & L ("---"));
      declare
         P : constant Plan := Compute_Plan (Root, Store);
      begin
         Assert (P.Ingested = 1, "accepted without a name field");
         Assert
           (Contains (To_String (P.Clusters (1).Body_Text), "[[b]] "
            & Character'Val (16#E2#) & Character'Val (16#80#)
            & Character'Val (16#94#) & " b" & LF),
            "the slug is the name");
      end;
   end Check_Name_Fallback;

   ---------------------------------------------------------------------------
   --  Registration
   ---------------------------------------------------------------------------

   procedure Run_One is new With_Repo (Check_One_Cluster, "sp-one");
   procedure Run_Tail is new With_Repo (Check_Tail_Preserved, "sp-tail");
   procedure Run_Reconcile is new With_Repo (Check_Reconcile, "sp-reconcile");
   procedure Run_Boundaries is new With_Repo (Check_Boundaries, "sp-bounds");
   procedure Run_Refused is new With_Repo (Check_Refused, "sp-refused");
   procedure Run_Collision is new With_Repo (Check_Collision, "sp-collision");
   procedure Run_All_Refused is new With_Repo
     (Check_All_Refused, "sp-all-refused");
   procedure Run_Fallback is new With_Repo
     (Check_Name_Fallback, "sp-fallback");

   procedure One_Cluster (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_One;
   end One_Cluster;

   procedure Tail (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Tail;
   end Tail;

   procedure Reconciling (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Reconcile;
   end Reconciling;

   procedure Boundaries (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Boundaries;
   end Boundaries;

   procedure Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Refused;
   end Refused;

   procedure Collision (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Collision;
   end Collision;

   procedure All_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_All_Refused;
   end All_Refused;

   procedure Fallback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Run_Fallback;
   end Fallback;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Synapse_Bard.Sync_Plan");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, One_Cluster'Access,
         "Compute_Plan clusters a tree and plans one cluster with the "
         & "expected body");
      Register_Routine
        (T, Tail'Access,
         "the planned body already carries the existing node's tail");
      Register_Routine
        (T, Reconciling'Access,
         "Reconcile deletes a node the plan did not produce");
      Register_Routine
        (T, Boundaries'Access,
         "the shallowest directory with content is the boundary, hidden "
         & "folders and loose files are not candidates");
      Register_Routine
        (T, Refused'Access,
         "a refused note is skipped with a report line and is not a member");
      Register_Routine
        (T, Collision'Access,
         "a slug claimed twice is a collision: the first is kept");
      Register_Routine
        (T, All_Refused'Access,
         "a cluster whose members are all refused is not written");
      Register_Routine
        (T, Fallback'Access, "a note without a name is named by its slug");
   end Register_Tests;

end Synapse_Bard.Sync_Plan.Tests;
