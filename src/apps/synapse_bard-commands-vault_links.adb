with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Vault_Store;

package body Synapse_Bard.Commands.Vault_Links is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Vault_Links_Usage);
         return 2;
      end if;
      declare
         Note : constant String := Arg (Args, 1);
      begin
         if Is_Help (Note) then
            Err_Text (Env, Usage.Vault_Links_Usage);
            return 0;
         end if;
         if Count (Args) > 1 then
            Err_Text
              (Env,
               "synapse-bard vault-links: unexpected argument '"
               & Arg (Args, 2) & "'" & LF & Usage.Vault_Links_Usage);
            return 2;
         end if;
         declare
            Found : constant Roots.Roots_Options.Option :=
              Roots.Resolve_Or_Report (Env);
         begin
            if not Found.Found then
               return 1;
            end if;
            declare
               Store   : Synapse_Bard.Vault_Store.Vault_Store :=
                 Synapse_Bard.Vault_Store.Create
                   (To_String (Found.Value.Vault));
               Linking : constant Synapse_Bard.Vault_Store.Note_List_Options
                 .Option := Store.Linking_Notes (Note);
               Output  : Unbounded_String;
            begin
               if not Linking.Found then
                  Err_Text
                    (Env,
                     Note & ": no note by this name in _bard/vault/" & LF);
                  return 1;
               end if;
               if Linking.Value.Is_Empty then
                  Append (Output, Note & ": no inbound links found" & LF);
               end if;
               for Name of Linking.Value loop
                  Append (Output, Note & " <- " & To_String (Name) & LF);
               end loop;
               Out_Text (Env, To_String (Output));
               return 0;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Vault_Links;
