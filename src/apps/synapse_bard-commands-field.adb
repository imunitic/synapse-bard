with Ada.Strings.Unbounded;

with Synapse_Bard.Cluster;
with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Frontmatter_Fields;
with Synapse_Bard.Graph_Store;

package body Synapse_Bard.Commands.Field is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Field_Usage);
         return 2;
      end if;
      declare
         Node : constant String := Arg (Args, 1);
      begin
         if Is_Help (Node) then
            Err_Text (Env, Usage.Field_Usage);
            return 0;
         end if;
         if Count (Args) < 2 then
            Err_Text (Env, Usage.Field_Usage);
            return 2;
         end if;
         declare
            Key   : constant String := Arg (Args, 2);
            Found : constant Roots.Roots_Options.Option :=
              Roots.Resolve_Or_Report (Env);
         begin
            if not Found.Found then
               return 1;
            end if;
            declare
               Store    : Synapse_Bard.Graph_Store.Graph_Store :=
                 Synapse_Bard.Graph_Store.Create
                   (To_String (Found.Value.Graph));
               Resolved : constant Cluster.Source_Entry_Options.Option :=
                 Cluster.Resolve_Slug (Store, Node);
            begin
               if not Resolved.Found then
                  Err_Text (Env, Node & ": not found" & LF);
                  return 1;
               end if;
               declare
                  Path : constant String := To_String (Resolved.Value.Path);
                  Src  : constant Maybe_Text :=
                    Read_Source (To_String (Found.Value.Repo) & "/" & Path);
               begin
                  if not Src.Found then
                     Err_Text
                       (Env,
                        Node & ": source file unreadable (" & Path & ")" & LF);
                     return 1;
                  end if;
                  declare
                     Raw : constant Frontmatter_Fields.Maybe_Text :=
                       Frontmatter_Fields.Raw_Field (To_String (Src.Value), Key);
                  begin
                     if not Raw.Found then
                        Err_Text
                          (Env,
                           Node & ": no root-level field '" & Key & "'" & LF);
                        return 1;
                     end if;
                     Out_Text (Env, To_String (Raw.Value));
                     return 0;
                  end;
               end;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Field;
