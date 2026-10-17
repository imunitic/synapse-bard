with Ada.Strings.Unbounded;

with Synapse.Core.Graph_Model;
with Synapse.Core.Text_Lists;
with Synapse.Ports.Extractor;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Frontmatter_Extractor;
with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Graph_Store;

package body Synapse_Bard.Commands.Fields is

   use Ada.Strings.Unbounded;
   use Support;
   use type Synapse.Core.Graph_Model.Role;
   use type Synapse.Ports.Extractor.Outcome_Kind;

   --  The kind of the entity Node names (`entity` without a `def`); the
   --  reason is the command's error message when it cannot be had.
   procedure Template_Of
     (Env     :     Environment; Found : Roots.Roots_Options.Option;
      Node    :     String; Name : out Unbounded_String; Ok : out Boolean)
   is
      Store    : Synapse_Bard.Graph_Store.Graph_Store :=
        Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
      Resolved : constant Cluster.Source_Entry_Options.Option :=
        Cluster.Resolve_Slug (Store, Node);
   begin
      Name := Null_Unbounded_String;
      Ok := False;
      if not Resolved.Found then
         Err_Text (Env, Node & ": not found" & LF);
         return;
      end if;
      declare
         Extractor : Synapse_Bard.Frontmatter_Extractor.Extractor;
         Paths     : Synapse.Core.Text_Lists.Vector;
      begin
         Paths.Append (Resolved.Value.Path);
         declare
            Outcomes : constant Synapse.Ports.Extractor.Outcome_Vectors.Vector :=
              Extractor.Extract (To_String (Found.Value.Repo), Paths);
         begin
            if Outcomes (1).Kind = Synapse.Ports.Extractor.Unsupported then
               declare
                  Why : constant Synapse_Bard.Frontmatter_Extractor
                    .Maybe_Refusal := Extractor.Last_Refusal (1);
               begin
                  Err_Text
                    (Env,
                     Node & ": unsupported ("
                     & (if Why.Refused
                        then Synapse_Bard.Frontmatter_Extractor.Name (Why.Why)
                        else "not_a_note")
                     & ")" & LF);
               end;
               return;
            end if;
            Name := To_Unbounded_String ("entity");
            for Tag of Outcomes (1).Tags loop
               if Tag.Which = Synapse.Core.Graph_Model.Def then
                  Name := Tag.Kind;
                  exit;
               end if;
            end loop;
            Ok := True;
         end;
      end;
   end Template_Of;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Fields_Usage);
         return 2;
      end if;
      declare
         First : constant String := Arg (Args, 1);
      begin
         if Is_Help (First) then
            Err_Text (Env, Usage.Fields_Usage);
            return 0;
         end if;
         declare
            Found : constant Roots.Roots_Options.Option :=
              Roots.Resolve_Or_Report (Env);
            Name  : Unbounded_String;
         begin
            if not Found.Found then
               return 1;
            end if;

            if First = "--template" then
               if Count (Args) < 2 then
                  Err_Text
                    (Env,
                     "synapse-bard fields: --template needs a name" & LF
                     & Usage.Fields_Usage);
                  return 2;
               end if;
               if Count (Args) > 2 then
                  Err_Text
                    (Env,
                     "synapse-bard fields: unexpected argument '"
                     & Arg (Args, 3) & "'" & LF & Usage.Fields_Usage);
                  return 2;
               end if;
               Name := To_Unbounded_String (Arg (Args, 2));
            else
               if Count (Args) > 1 then
                  Err_Text
                    (Env,
                     "synapse-bard fields: unexpected argument '"
                     & Arg (Args, 2) & "'" & LF & Usage.Fields_Usage);
                  return 2;
               end if;
               declare
                  Ok : Boolean;
               begin
                  Template_Of (Env, Found, First, Name, Ok);
                  if not Ok then
                     return 1;
                  end if;
               end;
            end if;

            declare
               Path : constant String :=
                 To_String (Found.Value.Repo) & "/_templates/"
                 & To_String (Name) & "_template.md";
               Src  : constant Maybe_Text := Read_Source (Path);
            begin
               if not Src.Found then
                  Err_Text
                    (Env,
                     "synapse-bard fields: no template file for '"
                     & To_String (Name) & "' (" & Path & ")" & LF);
                  return 1;
               end if;
               if not Frontmatter_Fields.Has_Block (To_String (Src.Value)) then
                  Err_Text
                    (Env,
                     "synapse-bard fields: '" & To_String (Name)
                     & "_template.md' has no frontmatter" & LF);
                  return 1;
               end if;
               declare
                  Output : Unbounded_String;
               begin
                  for Key of Frontmatter_Fields.Root_Keys
                    (To_String (Src.Value))
                  loop
                     Append (Output, Key);
                     Append (Output, LF);
                  end loop;
                  Out_Text (Env, To_String (Output));
                  return 0;
               end;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Fields;
