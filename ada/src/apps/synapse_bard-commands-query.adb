with Ada.Strings.Unbounded;

with Synapse.Core.Graph_Model;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Extractor;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Frontmatter_Extractor;
with Synapse_Bard.Graph_Store;

package body Synapse_Bard.Commands.Query is

   use Ada.Strings.Unbounded;
   use Support;
   use type Synapse.Core.Graph_Model.Role;
   use type Synapse.Ports.Extractor.Outcome_Kind;

   function Refusal_Name
     (Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor; Index : Positive)
      return String
   is
      Why : constant Synapse_Bard.Frontmatter_Extractor.Maybe_Refusal :=
        Extractor.Last_Refusal (Index);
   begin
      return
        (if Why.Refused then Synapse_Bard.Frontmatter_Extractor.Name (Why.Why)
         else "not_a_note");
   end Refusal_Name;

   function Run_Outbound
     (Env : Environment; Found : Roots.Roots_Options.Option; Node : String)
      return Exit_Code
   is
      Store    : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
      Resolved : constant Cluster.Source_Entry_Options.Option :=
        Cluster.Resolve_Slug (Store, Node);
      Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor;
      Paths     : Synapse.Core.Text_Lists.Vector;
   begin
      if not Resolved.Found then
         Err_Text (Env, Node & ": not found" & LF);
         return 1;
      end if;
      Paths.Append (Resolved.Value.Path);
      declare
         Outcomes : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
           Extractor.Extract (To_String (Found.Value.Repo), Paths);
         Output   : Unbounded_String;
      begin
         if Outcomes (1).Kind = Synapse.Ports.Extractor.Unsupported then
            Err_Text
              (Env,
               Node & ": unsupported (" & Refusal_Name (Extractor, 1) & ")"
               & LF);
            return 1;
         end if;
         for Tag of Outcomes (1).Tags loop
            if Tag.Which = Synapse.Core.Graph_Model.Def then
               Append (Output, Tag.Name & " (" & Tag.Kind & ")" & LF);
            end if;
         end loop;
         for Tag of Outcomes (1).Tags loop
            if Tag.Which = Synapse.Core.Graph_Model.Ref then
               Append (Output, "  " & Tag.Kind & " -> " & Tag.Name & LF);
            end if;
         end loop;
         Out_Text (Env, To_String (Output));
         return 0;
      end;
   end Run_Outbound;

   function Run_Inbound
     (Env : Environment; Found : Roots.Roots_Options.Option; Node : String)
      return Exit_Code
   is
      Store   : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
      --  Backlinks need every entity's outbound refs, so this resolves the
      --  whole graph rather than one slug.
      Entries : constant Cluster.Source_Entry_Vectors.Vector :=
        Cluster.All_Entities (Store);
      Present : constant Boolean :=
        (for some E of Entries => To_String (E.Slug) = Node);
      Paths   : Synapse.Core.Text_Lists.Vector;
      Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor;
   begin
      if not Present then
         Err_Text (Env, Node & ": not found" & LF);
         return 1;
      end if;
      for E of Entries loop
         Paths.Append (E.Path);
      end loop;
      declare
         Outcomes : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
           Extractor.Extract (To_String (Found.Value.Repo), Paths);
         Output   : Unbounded_String;
         Any      : Boolean := False;
      begin
         for I in 1 .. Natural (Entries.Length) loop
            --  No self-backlink, and unsupported entities have no refs.
            if To_String (Entries (I).Slug) /= Node
              and then Outcomes (I).Kind = Synapse.Ports.Extractor.With_Tags
            then
               for Tag of Outcomes (I).Tags loop
                  if Tag.Which = Synapse.Core.Graph_Model.Ref
                    and then Strip_Md_Suffix (To_String (Tag.Name)) = Node
                  then
                     Append
                       (Output,
                        Node & " <- " & To_String (Entries (I).Slug) & " ("
                        & Tag.Kind & ")" & LF);
                     Any := True;
                  end if;
               end loop;
            end if;
         end loop;
         if not Any then
            Append (Output, Node & ": no inbound references found" & LF);
         end if;
         Out_Text (Env, To_String (Output));
         return 0;
      end;
   end Run_Inbound;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Query_Usage);
         return 2;
      end if;
      declare
         Node    : constant String := Arg (Args, 1);
         Inbound : Boolean := False;
      begin
         if Is_Help (Node) then
            Err_Text (Env, Usage.Query_Usage);
            return 0;
         end if;
         for I in 2 .. Count (Args) loop
            if Arg (Args, I) = "--inbound" then
               Inbound := True;
            else
               Err_Text
                 (Env,
                  "synapse-bard query: unknown option '" & Arg (Args, I)
                  & "'" & LF & Usage.Query_Usage);
               return 2;
            end if;
         end loop;
         declare
            Found : constant Roots.Roots_Options.Option :=
              Roots.Resolve_Or_Report (Env);
         begin
            if not Found.Found then
               return 1;
            end if;
            return
              (if Inbound then Run_Inbound (Env, Found, Node)
               else Run_Outbound (Env, Found, Node));
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Query;
