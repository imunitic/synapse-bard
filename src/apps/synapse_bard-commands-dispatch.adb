with Synapse_Bard.Commands.Field;
with Synapse_Bard.Commands.Fields;
with Synapse_Bard.Commands.Query;
with Synapse_Bard.Commands.Search;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Sync;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Commands.Vault_Links;
with Synapse_Bard.Commands.Vault_Search;
with Synapse_Bard.Commands.Verify;

package body Synapse_Bard.Commands.Dispatch is

   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if Args.Is_Empty then
         Err_Text (Env, Usage.Main_Usage);
         return 2;
      end if;

      declare
         Which : constant String := Arg (Args, 1);
         Rest  : Arguments := Args;
      begin
         if Is_Help (Which) then
            Err_Text (Env, Usage.Main_Usage);
            return 0;
         end if;
         Rest.Delete_First;
         if Which = "sync" then
            return Sync.Run (Env, Rest);
         elsif Which = "query" then
            return Query.Run (Env, Rest);
         elsif Which = "field" then
            return Field.Run (Env, Rest);
         elsif Which = "fields" then
            return Fields.Run (Env, Rest);
         elsif Which = "search" then
            return Search.Run (Env, Rest);
         elsif Which = "vault-search" then
            return Vault_Search.Run (Env, Rest);
         elsif Which = "vault-links" then
            return Vault_Links.Run (Env, Rest);
         elsif Which = "verify" then
            return Verify.Run (Env, Rest);
         end if;
         Err_Text
           (Env,
            "synapse-bard: unknown command '" & Which & "'" & LF
            & Usage.Main_Usage);
         return 2;
      end;
   end Run;

end Synapse_Bard.Commands.Dispatch;
