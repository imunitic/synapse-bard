with Ada.Strings.Unbounded;

with Synapse_Bard.Commands.Roots;
with Synapse_Bard.Commands.Support;
with Synapse_Bard.Commands.Usage;
with Synapse_Bard.Graph_Store;
with Synapse_Bard.Sync_Plan;

package body Synapse_Bard.Commands.Mode is

   use Ada.Strings.Unbounded;
   use Support;

   function Run (Env : Environment; Args : Arguments) return Exit_Code is
   begin
      if not Args.Is_Empty then
         Err_Text (Env, Usage.Mode_Usage);
         return (if Is_Help (Arg (Args, 1)) then 0 else 2);
      end if;
      declare
         Found : constant Roots.Roots_Options.Option :=
           Roots.Resolve_Or_Report (Env);
      begin
         if not Found.Found then
            return 1;
         end if;
         declare
            Store : Synapse_Bard.Graph_Store.Graph_Store :=
              Synapse_Bard.Graph_Store.Create (To_String (Found.Value.Graph));
            Plan  : constant Synapse_Bard.Sync_Plan.Plan :=
              Synapse_Bard.Sync_Plan.Compute_Plan
                (To_String (Found.Value.Repo), Store);
         begin
            Out_Text
              (Env, (if Plan.Ingested = 0 then "generate" else "report") & LF);
            return 0;
         end;
      end;
   end Run;

end Synapse_Bard.Commands.Mode;
