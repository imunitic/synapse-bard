with Ada.Containers.Indefinite_Ordered_Maps;

with Synapse.Adapters.Disk_Link_Graph;
with Synapse.Core.Text_Search;
with Synapse.Core.Unicode;
with Synapse.Core.Wikilinks;

package body Synapse_Bard.Vault_Store is

   use Ada.Strings.Unbounded;

   --  The vault's own bootstrap file, not a note.
   Index_Node : constant String := "Index.md";

   function Create (Root : String) return Vault_Store is
     (Port.Store with
        Root => To_Unbounded_String (Root),
        Disk => Synapse.Adapters.Disk_Store.Create (Root, ""));

   overriding
   function Read
     (S : in out Vault_Store; Node : String) return Port.Maybe_Text is
     (S.Disk.Read (Node));

   overriding
   function Write
     (S : in out Vault_Store; Node, Content : String) return Port.Write_Result
   is (S.Disk.Write (Node, Content));

   overriding
   function List
     (S : in out Vault_Store) return Synapse.Core.Text_Lists.Vector
   is
      All_Nodes : constant Synapse.Core.Text_Lists.Vector := S.Disk.List;
      Result    : Synapse.Core.Text_Lists.Vector;
   begin
      for Node of All_Nodes loop
         if To_String (Node) /= Index_Node then
            Result.Append (Node);
         end if;
      end loop;
      return Result;
   end List;

   --  The notes that link to Name, other than Name itself.
   function Other_Linkers
     (Graph : in out Synapse.Adapters.Disk_Link_Graph.Disk_Link_Graph;
      Name  : String) return Synapse.Core.Text_Lists.Vector
   is
      Result : Synapse.Core.Text_Lists.Vector;
   begin
      for Link of Graph.Backlinks (Name) loop
         if To_String (Link.Node) /= Name then
            Result.Append (Link.Node);
         end if;
      end loop;
      return Result;
   end Other_Linkers;

   function Ranks_Before (Left, Right : Port.Hit) return Boolean is
     (if Left.Score /= Right.Score then Left.Score > Right.Score
      else To_String (Left.Node) < To_String (Right.Node));

   package Hit_Sorting is new Port.Hit_Vectors.Generic_Sorting (Ranks_Before);

   overriding
   function Search
     (S : in out Vault_Store; Query : String) return Port.Hit_Vectors.Vector
   is
      Names  : constant Synapse.Core.Text_Lists.Vector := S.List;
      Graph  : Synapse.Adapters.Disk_Link_Graph.Disk_Link_Graph :=
        Synapse.Adapters.Disk_Link_Graph.Create (To_String (S.Root));
      Result : Port.Hit_Vectors.Vector;
   begin
      for Name of Names loop
         declare
            Node : constant Port.Maybe_Text := S.Read (To_String (Name));
         begin
            if Node.Found
              and then Synapse.Core.Unicode.Contains_Case_Fold
                         (To_String (Node.Value), Query)
            then
               declare
                  Content : constant String := To_String (Node.Value);
                  Where   : constant Synapse.Core.Text_Search.Maybe_Line :=
                    Synapse.Core.Text_Search.First_Matching_Line
                      (Content, Query);
                  Count   : constant Natural :=
                    Natural (Other_Linkers (Graph, To_String (Name)).Length);
               begin
                  Result.Append
                    (Port.Hit'
                       (Node    => Name, Score => Float (Count),
                        Context =>
                          To_Unbounded_String
                            (if Where.Found
                             then
                               Content
                                 (Where.Value.First .. Where.Value.Last)
                             else "")));
               end;
            end if;
         end;
      end loop;
      Hit_Sorting.Sort (Result);
      return Result;
   end Search;

   package Name_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, String);

   function Linking_Notes
     (S : in out Vault_Store; Target : String) return Note_List_Options.Option
   is
      Names   : constant Synapse.Core.Text_Lists.Vector := S.List;
      By_Stem : Name_Maps.Map;
   begin
      --  Several notes can share a title; the last by path wins.
      for Name of Names loop
         By_Stem.Include
           (Synapse.Core.Wikilinks.Title_Of (To_String (Name)),
            To_String (Name));
      end loop;
      declare
         Stem : constant String := Synapse.Core.Wikilinks.Title_Of (Target);
      begin
         if not By_Stem.Contains (Stem) then
            return Note_List_Options.None;
         end if;
         declare
            Graph  : Synapse.Adapters.Disk_Link_Graph.Disk_Link_Graph :=
              Synapse.Adapters.Disk_Link_Graph.Create (To_String (S.Root));
            Linked : Synapse.Core.Text_Lists.Vector :=
              Other_Linkers (Graph, By_Stem.Element (Stem));
            package Sorting is new Synapse.Core.Text_Lists.Vectors
              .Generic_Sorting;
         begin
            Sorting.Sort (Linked);
            return Note_List_Options.Of_Value (Linked);
         end;
      end;
   end Linking_Notes;

end Synapse_Bard.Vault_Store;
