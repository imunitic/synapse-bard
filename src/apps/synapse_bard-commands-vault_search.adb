with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Vault_Store;

package body Synapse_Bard.Commands.Vault_Search is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Vault_Search_Usage);
         return 2;
      end if;
      declare
         Query : constant String := Arg (Args, 1);
      begin
         if Is_Help (Query) then
            Err_Text (Env, Usage.Vault_Search_Usage);
            return 0;
         end if;
         if Count (Args) > 1 then
            Err_Text
              (Env,
               "synapse-bard vault-search: unexpected argument '"
               & Arg (Args, 2) & "'" & LF & Usage.Vault_Search_Usage);
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
               Store  : Synapse_Bard.Vault_Store.Vault_Store :=
                 Synapse_Bard.Vault_Store.Create
                   (To_String (Found.Value.Vault));
               Hits   : constant Synapse_Bard.Vault_Store.Port.Hit_Vectors
                 .Vector := Store.Search (Query);
               Output : Unbounded_String;
            begin
               if Hits.Is_Empty then
                  Append (Output, "no matches for '" & Query & "'" & LF);
               end if;
               for Hit of Hits loop
                  Append
                    (Output,
                     To_String (Hit.Node) & " ("
                     & Ada.Strings.Fixed.Trim
                         (Natural'Image (Natural (Hit.Score)), Ada.Strings.Left)
                     & ")  " & To_String (Hit.Context) & LF);
               end loop;
               Out_Text (Env, To_String (Output));
               return 0;
            end;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Vault_Search;
