with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Directories;
with Ada.IO_Exceptions;

with Synapse.Core.Graph_Model;
with Synapse.Core.Wikilinks;
with Synapse.Ports.Extractor;

with Synapse_Bard.Cluster;
with Synapse_Bard.Frontmatter_Extractor;
with Synapse_Bard.Syntax;

package body Synapse_Bard.Sync_Plan is

   use Ada.Strings.Unbounded;
   use type Synapse.Core.Graph_Model.Role;

   package Text_Sorting is new Synapse.Core.Text_Lists.Vectors.Generic_Sorting;

   LF : constant Character := Synapse_Bard.Syntax.LF;

   ---------------------------------------------------------------------------
   --  Finding the clusters
   ---------------------------------------------------------------------------

   type Cluster is record
      Boundary   : Unbounded_String;
      Candidates : Synapse.Core.Text_Lists.Vector;
   end record;

   package Cluster_Vectors is new Ada.Containers.Vectors (Positive, Cluster);

   function Before (Left, Right : Cluster) return Boolean is
     (Left.Boundary < Right.Boundary);

   package Cluster_Sorting is new Cluster_Vectors.Generic_Sorting (Before);

   function Ends_With_Md (Name : String) return Boolean is
     (Name'Length >= 3 and then Name (Name'Last - 2 .. Name'Last) = ".md");

   --  The entries of directory Path that are not hidden (`_` or `.` first):
   --  its `.md` files and its subdirectories. A directory that cannot be read
   --  has none.
   procedure List_Directory
     (Path        : String;
      Files, Dirs : out Synapse.Core.Text_Lists.Vector)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Files.Clear;
      Dirs.Clear;
      Ada.Directories.Start_Search
        (Search, Path, "",
         [Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          others                        => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length > 0 and then Name (Name'First) not in '_' | '.' then
               case Ada.Directories.Kind (Item) is
                  when Ada.Directories.Ordinary_File =>
                     if Ends_With_Md (Name) then
                        Files.Append (To_Unbounded_String (Name));
                     end if;

                  when Ada.Directories.Directory =>
                     Dirs.Append (To_Unbounded_String (Name));

                  when others =>
                     null;
               end case;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Files.Clear;
         Dirs.Clear;
   end List_Directory;

   --  Every `.md` file under Rel (relative to Root), recursively, hidden
   --  directories excluded. No further boundary is drawn once one is chosen.
   procedure Collect_All_Md
     (Root, Rel : String; Into : in out Synapse.Core.Text_Lists.Vector)
   is
      Files, Dirs : Synapse.Core.Text_Lists.Vector;
   begin
      List_Directory (Root & "/" & Rel, Files, Dirs);
      for Name of Files loop
         Into.Append (To_Unbounded_String (Rel & "/" & To_String (Name)));
      end loop;
      for Name of Dirs loop
         Collect_All_Md (Root, Rel & "/" & To_String (Name), Into);
      end loop;
   end Collect_All_Md;

   --  The shallowest-content-wins rule: a directory with a `.md` file of its
   --  own is the boundary, and owns everything below it; one without is
   --  searched a level deeper.
   procedure Find_Boundary
     (Root, Rel : String; Into : in out Cluster_Vectors.Vector)
   is
      Files, Dirs : Synapse.Core.Text_Lists.Vector;
   begin
      List_Directory (Root & "/" & Rel, Files, Dirs);
      if Files.Is_Empty then
         for Name of Dirs loop
            Find_Boundary (Root, Rel & "/" & To_String (Name), Into);
         end loop;
         return;
      end if;
      declare
         Found : Cluster;
      begin
         Found.Boundary := To_Unbounded_String (Rel);
         for Name of Files loop
            Found.Candidates.Append
              (To_Unbounded_String (Rel & "/" & To_String (Name)));
         end loop;
         for Name of Dirs loop
            Collect_All_Md
              (Root, Rel & "/" & To_String (Name), Found.Candidates);
         end loop;
         Into.Append (Found);
      end;
   end Find_Boundary;

   --  Only folders are searched: a loose file in the repository root is never
   --  a candidate.
   function Find_Clusters (Root : String) return Cluster_Vectors.Vector is
      Files, Dirs : Synapse.Core.Text_Lists.Vector;
      Result      : Cluster_Vectors.Vector;
   begin
      List_Directory (Root, Files, Dirs);
      for Name of Dirs loop
         Find_Boundary (Root, To_String (Name), Result);
      end loop;
      Cluster_Sorting.Sort (Result);
      for C of Result loop
         Text_Sorting.Sort (C.Candidates);
      end loop;
      return Result;
   end Find_Clusters;

   ---------------------------------------------------------------------------
   --  The plan
   ---------------------------------------------------------------------------

   package Slug_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, String);

   function Compute_Plan
     (Repo_Root : String; Store : in out Synapse.Ports.Store.Store'Class)
      return Plan
   is
      package Write_Entries renames Synapse_Bard.Cluster.Write_Entry_Vectors;
      package Natural_Vectors is new Ada.Containers.Vectors
        (Positive, Natural);

      Clusters : constant Cluster_Vectors.Vector := Find_Clusters (Repo_Root);
      Result   : Plan;

      --  Every candidate of every cluster, for one batch Extract, and the
      --  index of the cluster each belongs to.
      Flat  : Synapse.Core.Text_Lists.Vector;
      Owner : Natural_Vectors.Vector;
   begin
      for Index in Clusters.First_Index .. Clusters.Last_Index loop
         for Path of Clusters (Index).Candidates loop
            Flat.Append (Path);
            Owner.Append (Index);
         end loop;
      end loop;

      declare
         Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor;
         Outcomes  : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
           Extractor.Extract (Repo_Root, Flat);
         Claimed   : Slug_Maps.Map;
         Accepted  : array (1 .. Natural (Clusters.Length)) of
           Write_Entries.Vector;
      begin
         for I in 1 .. Natural (Flat.Length) loop
            declare
               Candidate : constant String := To_String (Flat (I));
               Slug      : constant String :=
                 Synapse.Core.Wikilinks.Title_Of (Candidate);
               Outcome   : constant Synapse.Ports.Extractor.Outcome :=
                 Outcomes (I);
            begin
               case Outcome.Kind is
                  when Synapse.Ports.Extractor.Unsupported =>
                     declare
                        Why    : constant
                          Synapse_Bard.Frontmatter_Extractor.Maybe_Refusal :=
                            Extractor.Last_Refusal (I);
                        Reason : constant String :=
                          (if Why.Refused
                           then Synapse_Bard.Frontmatter_Extractor.Name
                                  (Why.Why)
                           else "not_a_note");
                     begin
                        Result.Skipped := Result.Skipped + 1;
                        Result.Report_Lines.Append
                          (To_Unbounded_String
                             ("skipped (" & Reason & "): " & Candidate & LF));
                     end;

                  when Synapse.Ports.Extractor.With_Tags =>
                     if Claimed.Contains (Slug) then
                        declare
                           First : constant String := Claimed.Element (Slug);
                        begin
                           Result.Collisions := Result.Collisions + 1;
                           Result.Report_Lines.Append
                             (To_Unbounded_String
                                ("COLLISION: " & First & " and " & Candidate
                                 & " both resolve to slug '" & Slug
                                 & "' -- kept " & First & ", skipped "
                                 & Candidate & LF));
                        end;
                     else
                        declare
                           Name : Unbounded_String :=
                             To_Unbounded_String (Slug);
                        begin
                           for Tag of Outcome.Tags loop
                              if Tag.Which = Synapse.Core.Graph_Model.Def then
                                 Name := Tag.Name;
                                 exit;
                              end if;
                           end loop;
                           Accepted (Owner (I)).Append
                             (Synapse_Bard.Cluster.Write_Entry'
                                (Slug => To_Unbounded_String (Slug),
                                 Path => To_Unbounded_String (Candidate),
                                 Name => Name));
                           Claimed.Insert (Slug, Candidate);
                           Result.Ingested := Result.Ingested + 1;
                        end;
                     end if;
               end case;
            end;
         end loop;

         for Index in Clusters.First_Index .. Clusters.Last_Index loop
            --  Every candidate here was refused or collided away.
            if not Accepted (Index).Is_Empty then
               declare
                  Title    : constant String :=
                    Synapse_Bard.Cluster.Cluster_Title
                      (To_String (Clusters (Index).Boundary));
                  Node     : constant String := Title & ".md";
                  Existing : constant Synapse.Ports.Store.Maybe_Text :=
                    Store.Read (Node);
                  Tail     : constant String :=
                    (if Existing.Found
                     then Synapse_Bard.Cluster.Preserved_Tail
                            (To_String (Existing.Value))
                     else "");
               begin
                  Result.Clusters.Append
                    (Planned_Cluster'
                       (Node      => To_Unbounded_String (Node),
                        Body_Text =>
                          To_Unbounded_String
                            (Synapse_Bard.Cluster.Render_Cluster_Body
                               (Title, Accepted (Index), Tail))));
               end;
            end if;
         end loop;
      end;
      return Result;
   end Compute_Plan;

   function Reconcile
     (Store   : in out Synapse_Bard.Graph_Store.Graph_Store;
      Written : Synapse.Core.Text_Lists.Vector) return Natural
   is
      Existing : constant Synapse.Core.Text_Lists.Vector := Store.List;
      Removed  : Natural := 0;
   begin
      for Node of Existing loop
         if not Written.Contains (Node) then
            Store.Delete (To_String (Node));
            Removed := Removed + 1;
         end if;
      end loop;
      return Removed;
   end Reconcile;

end Synapse_Bard.Sync_Plan;
